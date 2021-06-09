using Microsoft.Azure.Cosmos.Table;
using Newtonsoft.Json.Linq;
using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Configuration;
using System.Linq;
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

    public class listrestorevalidation :TableEntity
    {
        public Boolean state { get; set; }
        [DataType(DataType.MultilineText)]
        public string email { get; set; }
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

        public listrestorevalidation GetValidationSettings()
        {
            listrestorevalidation validationsetting = new listrestorevalidation();

            TableQuery<listrestorevalidation> query;

            query = new TableQuery<listrestorevalidation>().Where(
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

        public void UpdateValidationSettings(listrestorevalidation settings)
        {
            TableQuery<listrestorevalidation> query;

            query = new TableQuery<listrestorevalidation>().Where(
                                                        TableQuery.CombineFilters(
                                                        TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "config"),
                                                        TableOperators.And,
                                                        TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, "overridepolicyvalidate")));

            foreach (listrestorevalidation entity in tableconfiguration.ExecuteQuery(query))
            {
                entity.state = settings.state;
                entity.email = settings.email;
                TableOperation update = TableOperation.Replace(entity);
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
                TableOperation update = TableOperation.Replace(entity);
                table.Execute(update);
            }
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

                return backupdetails.ToString();
            }

            return "";
        }

        public async Task<bool> Restoretonewpolicy(string partitionkey, string rowkey)
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

            Claim upn = ClaimsPrincipal.Current.FindFirst(ClaimsPrincipal.Current.Identities.First().NameClaimType);

            var jsonData = System.Text.Json.JsonSerializer.Serialize(new
            {

                type = "New",
                data = backupdetails.ToString(),
                policyrowkey = rowkey,
                policypartitionkey = partitionkey,
                requestor = upn.Value.ToString()
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

        public async Task<bool> Restoretoexistingpolicy(string partitionkey, string rowkey)
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

            Claim upn = ClaimsPrincipal.Current.FindFirst(ClaimsPrincipal.Current.Identities.First().NameClaimType);

            var jsonData = System.Text.Json.JsonSerializer.Serialize(new
            {

                type = "Restore",
                data = backupdetails.ToString(),
                policyrowkey = rowkey,
                policypartitionkey = partitionkey,
                requestor = upn.Value.ToString()
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