using Microsoft.Azure.Cosmos.Table;
using Newtonsoft.Json.Linq;
using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Claims;
using System.Threading.Tasks;
using System.Web;

namespace CABackupFrontend.Models
{
    public class listcabackupconfig : TableEntity
    {
        public string BackupDate { get; set; }
        public string CAOldValue { get; set; }        
        public string CABackup { get; set; }
        public string Policy { get; set; }
        public string BackupRestoreing { get; set; }
    }

    public class listcabackupdetails : TableEntity
    {
        public string BackupDate { get; set; }
        public string CAOldValue { get; set; }
        public string CANewValue { get; set; }
        public string CABackup { get; set; }
        public string BackupRestoreing { get; set; }
        public string modifiedby { get; set; }
    }

    public class listcabackuptranslation : TableEntity
    {
        [Required(ErrorMessage = "Please define a section (Case sensetive!)")]
        public string Section { get; set; }
        [Required(ErrorMessage = "Please define a function (Case sensetive!)")]
        public string Function { get; set; }            
        [Required(ErrorMessage = "Please define a setting (Case sensetive!)")]
        public string Setting { get; set; }
        [Required(ErrorMessage = "Please define a translation (Case sensetive!)")]
        public string Translation { get; set; }

    }

    public class listsettingsrestorevalidation :TableEntity
    {
        public Boolean state { get; set; }
        [DataType(DataType.MultilineText)]
        public string email { get; set; }
    }

    public class listsettingsimportconfigurations :TableEntity
    {
        public bool updateavailable { get; set; }
        public string version { get; set; }

        public string newversion { get; set; }
    }

    public class CA_Backup_Model
    {
        CloudStorageAccount storageAccount;
        CloudTableClient tableClient;
        CloudTable table;
        CloudTable tabletranslation;
        CloudTable tableconfiguration;

        public CA_Backup_Model(string connectionstr)
        {
            storageAccount = CloudStorageAccount.Parse(connectionstr);
            tableClient = storageAccount.CreateCloudTableClient();
            table = tableClient.GetTableReference("cabackup");
            tabletranslation = tableClient.GetTableReference("catranslation");
            tableconfiguration = tableClient.GetTableReference("cabackupconfiguration");
            
        }

        public List<listcabackupconfig> GetBackups()
        {
            var continuationToken = new TableContinuationToken();
            List<listcabackupconfig> config = new List<listcabackupconfig>();

            do
            {
                var queryResult = table.ExecuteQuerySegmented(new TableQuery<listcabackupconfig>(), continuationToken);

                foreach (var backupconfig in queryResult.Results)
                {                    
                    string policy = "";

                    if (backupconfig.PartitionKey == "CABackupDaily")
                    {
                        policy = JObject.Parse(backupconfig.CABackup)["displayName"].ToString();
                    }
                    else if (backupconfig.PartitionKey == "CABackupChanges")
                    {
                        policy = JObject.Parse(backupconfig.CAOldValue)["displayName"].ToString();
                    }                     

                    config.Add(new listcabackupconfig
                    {
                        PartitionKey = backupconfig.PartitionKey,
                        RowKey = backupconfig.RowKey,
                        BackupDate = backupconfig.BackupDate,
                        Policy = policy,
                        BackupRestoreing = backupconfig.BackupRestoreing
                    });
                }

                continuationToken = queryResult.ContinuationToken;

            } while (continuationToken != null);


            return config;            
        }

        public List<listcabackupdetails> GetBackupDetails(string partitionkey, string rowkey)
        {
            List<listcabackupdetails> backupconfig = new List<listcabackupdetails>();

            TableQuery<listcabackupdetails> query;
   
            query = new TableQuery<listcabackupdetails>().Where(
                                                        TableQuery.CombineFilters(
                                                        TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, partitionkey),
                                                        TableOperators.And,
                                                        TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, rowkey)));
            

            var continuationToken = new TableContinuationToken();
            var queryresult = table.ExecuteQuery(query);

            foreach (var item in queryresult)
            {
                backupconfig.Add(new listcabackupdetails
                { 
                    PartitionKey = item.PartitionKey, 
                    RowKey = item.RowKey, 
                    BackupDate = item.BackupDate,
                    CABackup = item.CABackup,
                    CAOldValue = translatechanges(item.CAOldValue),
                    CANewValue = translatechanges(item.CANewValue),
                    modifiedby = item.modifiedby
                });
            }

            return backupconfig;
        }

        public List<listcabackuptranslation> GetBackupTranslations()
        {
            List<listcabackuptranslation> translationsettings = new List<listcabackuptranslation>();

            TableContinuationToken token = null;
            do
            {
                var queryResult = tabletranslation.ExecuteQuerySegmented(new TableQuery<listcabackuptranslation>(), token);
                translationsettings.AddRange(queryResult.Results);
                token = queryResult.ContinuationToken;
            } while (token != null);

            return translationsettings;
        }

        public listsettingsrestorevalidation GetValidationSettings()
        {
            listsettingsrestorevalidation validationsetting = new listsettingsrestorevalidation();

            TableQuery<listsettingsrestorevalidation> query;

            query = new TableQuery<listsettingsrestorevalidation>().Where(
                                                        TableQuery.CombineFilters(
                                                        TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "config"),
                                                        TableOperators.And,
                                                        TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, "overridepolicyvalidate")));


            var continuationToken = new TableContinuationToken();
            var queryresult = tableconfiguration.ExecuteQuery(query);

            foreach (var item in queryresult)
            {
                validationsetting.email = item.email;
                validationsetting.state = item.state;
            }

            return validationsetting;
        }

        public listsettingsimportconfigurations GetConfigurationVersion()
        {
            listsettingsimportconfigurations validationsetting = new listsettingsimportconfigurations();
            validationsetting.updateavailable = false;


            TableQuery<listsettingsimportconfigurations> query;

            query = new TableQuery<listsettingsimportconfigurations>().Where(
                                                        TableQuery.CombineFilters(
                                                        TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "config"),
                                                        TableOperators.And,
                                                        TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, "configversion")));


            var queryresult = tableconfiguration.ExecuteQuery(query);

            string availableversion = "";
            string currentversion = "";
            foreach (var item in queryresult)
            {
                currentversion = item.version;
                validationsetting.version = item.version;
            }

            WebClient client = new WebClient();
            Stream stream = client.OpenRead("https://raw.githubusercontent.com/Lagler-Gruener/Sol-CABackupDeploy/main/StorageAccount/configuration/version");
            using (var reader = new StreamReader(stream))
            {
                while (!reader.EndOfStream)
                {
                    availableversion = reader.ReadLine();
                    validationsetting.newversion = reader.ReadLine();
                }
            }

            if (availableversion != currentversion)
            {
                validationsetting.updateavailable = true;
            }

            return validationsetting;
        }

        public void UpdateValidationSettings(listsettingsrestorevalidation settings)
        {
            TableQuery<listsettingsrestorevalidation> query;

            query = new TableQuery<listsettingsrestorevalidation>().Where(
                                                        TableQuery.CombineFilters(
                                                        TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "config"),
                                                        TableOperators.And,
                                                        TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, "overridepolicyvalidate")));

            foreach (listsettingsrestorevalidation entity in tableconfiguration.ExecuteQuery(query))
            {
                entity.state = settings.state;
                entity.email = settings.email;
                TableOperation update = TableOperation.InsertOrReplace(entity);
                tableconfiguration.Execute(update);
            }
        }        

        public void UpdateBackupDetails(string partitionkey, string rowkey)
        {
            List<listcabackupdetails> backupconfig = new List<listcabackupdetails>();

            TableQuery<listcabackupdetails> query;

            query = new TableQuery<listcabackupdetails>().Where(
                                                        TableQuery.CombineFilters(
                                                        TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, partitionkey),
                                                        TableOperators.And,
                                                        TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, rowkey)));


            foreach (listcabackupdetails entity in table.ExecuteQuery(query))
            {
                entity.BackupRestoreing = "true";
                TableOperation update = TableOperation.InsertOrReplace(entity);
                table.Execute(update);
            }
        }

        public void UpdateConfigSettings()
        {
            WebClient client = new WebClient();

            #region Update translation settings
            Stream streamsettings = client.OpenRead("https://raw.githubusercontent.com/Lagler-Gruener/Sol-CABackupDeploy/main/StorageAccount/configuration/catranslation.csv");
            int i = 0;
            using (var reader = new StreamReader(streamsettings))
            {
                try
                {
                    while (!reader.EndOfStream)
                    {
                        var line = reader.ReadLine();
                        if (i > 0)
                        {
                            var values = line.Split(',');

                            listcabackuptranslation translation = new listcabackuptranslation();
                            translation.PartitionKey = values[3] + ":" + values[7];
                            translation.RowKey = values[1];
                            translation.Function = values[3];
                            translation.Section = values[5];
                            translation.Setting = values[7];
                            translation.Translation = values[9];

                            TableOperation querytranslation = TableOperation.InsertOrReplace(translation);
                            tabletranslation.Execute(querytranslation);
                        }
                        i++;
                    }
                }
                catch (Exception ex)
                {

                    throw new Exception(ex.Message);
                }
            }            

            #endregion

            #region Update validation settingsto default if not set
            TableQuery<listsettingsrestorevalidation> query;

            query = new TableQuery<listsettingsrestorevalidation>().Where(
                                                        TableQuery.CombineFilters(
                                                        TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "config"),
                                                        TableOperators.And,
                                                        TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, "overridepolicyvalidate")));


            var queryresult = tableconfiguration.ExecuteQuery(query);

            if (queryresult.Count< listsettingsrestorevalidation>() == 0)
            {
                listsettingsrestorevalidation validationsetting = new listsettingsrestorevalidation();
                validationsetting.PartitionKey = "config";
                validationsetting.RowKey = "overridepolicyvalidate";
                validationsetting.email = "";
                validationsetting.state = false;

                TableOperation insertvalidationsetting = TableOperation.InsertOrReplace(validationsetting);
                tableconfiguration.Execute(insertvalidationsetting);
            }

            #endregion

            #region Update version number
            string newversion = "0.0";
            Stream streamversion = client.OpenRead("https://raw.githubusercontent.com/Lagler-Gruener/Sol-CABackupDeploy/main/StorageAccount/configuration/version");
            using (var reader = new StreamReader(streamversion))
            {
                while (!reader.EndOfStream)
                {
                    newversion = reader.ReadLine();
                }
            }

            listsettingsimportconfigurations entity = new listsettingsimportconfigurations();
            entity.PartitionKey = "config";
            entity.RowKey = "configversion";
            entity.version = newversion;
            
            TableOperation update = TableOperation.InsertOrReplace(entity);
            tableconfiguration.Execute(update);            
            #endregion
        }

        private string translatechanges(string policysettings)
        {
            if (policysettings != null)
            {
                List<listcabackuptranslation> translationsettings = new List<listcabackuptranslation>();

                TableContinuationToken token = null;
                do
                {
                    var queryResult = tabletranslation.ExecuteQuerySegmented(new TableQuery<listcabackuptranslation>(), token);
                    translationsettings.AddRange(queryResult.Results);
                    token = queryResult.ContinuationToken;
                } while (token != null);

                JObject backupdetails = new JObject();
                backupdetails = JObject.Parse(policysettings);

                foreach (listcabackuptranslation item in translationsettings)
                {
                    try
                    {
                        if (null != backupdetails[item.Section.ToString()][item.Function.ToString()][item.Setting.ToString()])
                        {
                            if ((string)backupdetails[item.Section.ToString()][item.Function.ToString()][item.Setting.ToString()] == (string)item.RowKey)
                            {
                                if (item.Translation == "-removekey-")
                                {
                                    JObject selectedfunction = (JObject)backupdetails[item.Section.ToString()][item.Function.ToString()];
                                    selectedfunction.Property(item.Setting.ToString()).Remove();
                                }
                                else
                                {
                                    backupdetails[item.Section.ToString()][item.Function.ToString()][item.Setting.ToString()] = item.Translation;
                                }
                            }
                        }
                    }
                    catch (Exception)
                    {                       
                    }
                }

                return backupdetails.ToString();
            }

            return "";
        }

        public async Task<bool> Restoretonewpolicy(string partitionkey, string rowkey, string upn)
        {
            CA_Backup_Model model = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);
            List<listcabackupdetails> backupdetail = model.GetBackupDetails(partitionkey, rowkey);

            JObject backupdetails = new JObject();

            if (partitionkey == "CABackupChanges")
            {
                backupdetails = JObject.Parse(translatechanges(backupdetail[0].CAOldValue));
                backupdetails["displayName"] = backupdetails["displayName"].ToString() + ".restore(" + DateTime.Now.ToShortDateString().ToString() + ")";
                backupdetails["state"] = "enabledForReportingButNotEnforced";
            }
            else if (partitionkey == "CABackupDaily")
            {
                backupdetails = JObject.Parse(backupdetail[0].CABackup);
                backupdetails["displayName"] = backupdetails["displayName"].ToString() + ".restore(" + DateTime.Now.ToShortDateString().ToString() + ")";
                backupdetails["state"] = "enabledForReportingButNotEnforced";
            }            

            var jsonData = System.Text.Json.JsonSerializer.Serialize(new
            {

                type = "New",
                data = backupdetails.ToString(),
                policyrowkey = rowkey,
                policypartitionkey = partitionkey,
                requestor = upn
            });

            using (var client = new HttpClient())
            {
                var content = new StringContent(jsonData);
                content.Headers.ContentType.CharSet = string.Empty;
                content.Headers.ContentType.MediaType = "application/json";
                string logicappurl = ConfigurationManager.AppSettings["LACARestore"];
                var response = await client.PostAsync(logicappurl, content);
            }

            model.UpdateBackupDetails(partitionkey, rowkey);

            return true;
        }

        public async Task<bool> Restoretoexistingpolicy(string partitionkey, string rowkey, string upn)
        {
            CA_Backup_Model model = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);
            List<listcabackupdetails> backupdetail = model.GetBackupDetails(partitionkey, rowkey);

            JObject backupdetails = new JObject();

            if (partitionkey == "CABackupChanges")
            {
                backupdetails = JObject.Parse(translatechanges(backupdetail[0].CAOldValue));
                backupdetails["displayName"] = backupdetails["displayName"].ToString() + ".restore(" + DateTime.Now.ToShortDateString().ToString() + ")";
            }
            else if (partitionkey == "CABackupDaily")
            {
                backupdetails = JObject.Parse(backupdetail[0].CABackup);
                backupdetails["displayName"] = backupdetails["displayName"].ToString() + ".restore(" + DateTime.Now.ToShortDateString().ToString() + ")";
            }

            var jsonData = System.Text.Json.JsonSerializer.Serialize(new
            {

                type = "Restore",
                data = backupdetails.ToString(),
                policyrowkey = rowkey,
                policypartitionkey = partitionkey,
                requestor = upn
            });

            using (var client = new HttpClient())
            {
                var content = new StringContent(jsonData);
                content.Headers.ContentType.CharSet = string.Empty;
                content.Headers.ContentType.MediaType = "application/json";
                string logicappurl = ConfigurationManager.AppSettings["LACARestore"];
                var response = await client.PostAsync(logicappurl, content);
            }

            model.UpdateBackupDetails(partitionkey, rowkey);

            return true;
        }

        public void AddNewTranslationSetting(listcabackuptranslation settings)
        {
            TableOperation insertOperation = TableOperation.Insert(settings);
            tabletranslation.Execute(insertOperation);
        }

        public void RemoveTranslationSetting(listcabackuptranslation settings)
        {
            TableOperation deleteOperation = TableOperation.Delete(settings);
            tabletranslation.Execute(deleteOperation);
        }
    }
}