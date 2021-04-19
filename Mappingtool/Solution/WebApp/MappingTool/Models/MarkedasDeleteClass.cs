using Azure.Storage.Queues;
using Microsoft.Azure.Cosmos.Table;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace MappingTool.Models
{
    public class MarkedasDelete
    {
        public MarkedasDelete()
        {

        }

        public bool StartRemoveWorkflow(string connectionstr, string AADGroupName, string AADGroupID, string AzureRG, string SubscriptionID, string ADGroupName,
                                        string ADGroupSID, string ADOUPath, string ADGroupDesc, string PartitionKey, ref string errormsg)
        {
            try
            {
                #region Add Message to Azure AD Queue

                var azureadqueuename = MappingTool.MvcApplication.MappingtoolConfiguration.Where(o => o.RowKey == "Conf-App-CL-MonConfig-Msg-Queue").FirstOrDefault();
                QueueClient azureadqueueclient = new QueueClient(connectionstr, azureadqueuename.Value);
                var admsg = new
                {
                    WorkflowID = "null",
                    Type = "AD-Rem",
                    AADGroupName = AADGroupName.ToLower(),
                    AADGroupID = AADGroupID,
                    AzureRG = AzureRG,
                    SubscriptionID = SubscriptionID,
                    ADGroupName = ADGroupName.ToLower(),
                    ADSID = ADGroupSID,
                    ADOUPath = ADOUPath,
                    ADGroupDesc = ADGroupDesc,
                    State = "1",
                    PartitionKey = PartitionKey,
                };

                string jsonmsg = JsonConvert.SerializeObject(admsg);
                var plainTextBytes = System.Text.Encoding.UTF8.GetBytes(jsonmsg);
                azureadqueueclient.SendMessage(Convert.ToBase64String(plainTextBytes));

                #endregion

                #region Add Message to Active Directory Queue

                var opadqueue = MappingTool.MvcApplication.MappingtoolConfiguration.Where(o => o.RowKey == "Conf-App-OP-MonConfig-Msg-Queue").FirstOrDefault();
                QueueClient opqueueclient = new QueueClient(connectionstr, opadqueue.Value);
                var opmsg = new
                {
                    WorkflowID = "null",
                    Type = "RG-Rem",
                    AADGroupName = AADGroupName.ToLower(),
                    AADGroupID = AADGroupID,
                    AzureRG = AzureRG,
                    SubscriptionID = SubscriptionID,
                    ADGroupName = ADGroupName.ToLower(),
                    ADSID = ADGroupSID,
                    ADOUPath = ADOUPath,
                    ADGroupDesc = ADGroupDesc,
                    State = "1",
                    PartitionKey = PartitionKey,
                };

                string opjsonmsg = JsonConvert.SerializeObject(opmsg);
                var opplainTextBytes = System.Text.Encoding.UTF8.GetBytes(opjsonmsg);
                opqueueclient.SendMessage(Convert.ToBase64String(opplainTextBytes));

                #endregion

                #region Update MarkedAsDelete to 2

                var configtable = MappingTool.MvcApplication.MappingtoolConfiguration.Where(o => o.RowKey == "Conf-App-Configuration-Table").FirstOrDefault();

                CloudStorageAccount storageAccount = CloudStorageAccount.Parse(connectionstr);

                CloudTableClient tableClient = storageAccount.CreateCloudTableClient();

                CloudTable table = tableClient.GetTableReference(configtable.Value);

                TableQuery<listrbacpermconfig> queryupdatemad = new TableQuery<listrbacpermconfig>().Where(
                                                                        TableQuery.CombineFilters(
                                                                            TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, PartitionKey),
                                                                            TableOperators.And,
                                                                            TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, AADGroupName)));

                foreach (listrbacpermconfig entity in table.ExecuteQuery(queryupdatemad))
                {
                    entity.MarkedasDelete = "2";
                    TableOperation update = TableOperation.Replace(entity);
                    table.Execute(update);
                }

                #endregion

                return true;
            }
            catch (Exception ex)
            {
                errormsg = ex.Message;
                return false;
            }
        }
    }
}