using Microsoft.Azure.Cosmos.Table;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace MappingTool.Models
{
    public class RBACArchiv
    {
        CloudStorageAccount storageAccount;
        CloudTableClient tableClient;
        CloudTable table;

        public RBACArchiv(string connectionstr, string TableName)
        {
            storageAccount = CloudStorageAccount.Parse(connectionstr);
            tableClient = storageAccount.CreateCloudTableClient();
            table = tableClient.GetTableReference(TableName);
        }

        public List<listrbacpermconfig> GetAzureRBACArchiv()
        {
            var continuationToken = new TableContinuationToken();

            List<listrbacpermconfig> archiveperm = new List<listrbacpermconfig>();

            do
            {
                var queryResult = table.ExecuteQuerySegmented(new TableQuery<listarchivconfig>(), continuationToken);

                foreach (var backupconfig in queryResult.Results)
                {
                    JObject json = JObject.Parse(backupconfig.BackupData);

                    var PartitionKey = backupconfig.PartitionKey;
                    var RowKey = backupconfig.RowKey;
                    var AADGroupID = (string)json["AADGroupID"];
                    var AADGroupName = (string)json["AADGroupName"];
                    var ADGroupDN = (string)json["ADGroupDN"];
                    var ADGroupName = (string)json["ADGroupName"];
                    var ADGroupSID = (string)json["ADGroupSID"];
                    var ADGroupuSNChanged = (string)json["ADGroupuSNChanged"];
                    var AzureRG = (string)json["AzureRG"];
                    var MarkedasDelete = (string)json["MarkedasDelete"];
                    var RBACPermID = (string)json["RBACPermID"];
                    var RBACPermName = (string)json["RBACPermName"];
                    var SubscriptionID = (string)json["SubscriptionID"];
                    var Validatet = (string)json["Validatet"];
                    var RBACPerm = (string)json["RBACPerm"];

                    archiveperm.Add(new listrbacpermconfig
                    {
                        PartitionKey = PartitionKey,
                        RowKey = RowKey,
                        AADGroupID = AADGroupID,
                        AADGroupName = AADGroupName,
                        ADGroupDN = ADGroupDN,
                        ADGroupName = ADGroupName,
                        ADGroupSID = ADGroupSID,
                        ADGroupuSNChanged = ADGroupuSNChanged,
                        AzureRG = AzureRG,
                        MarkedasDelete = MarkedasDelete,
                        RBACPermID = RBACPermID,
                        RBACPermName = RBACPermName,
                        SubscriptionID = SubscriptionID,
                        Validatet = Validatet
                    });
                }

                continuationToken = queryResult.ContinuationToken;

            } while (continuationToken != null);


            return archiveperm;
        }

        public bool RemoveRBACArchiv(string PartitionKey, string RowKey, ref string errormsg)
        {
            TableQuery<listrbacmapping> rangeQuery = new TableQuery<listrbacmapping>().Where(
                                                            TableQuery.CombineFilters(
                                                                TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, PartitionKey),
                                                                TableOperators.And,
                                                                TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, RowKey)));

            try
            {
                foreach (listrbacmapping entity in table.ExecuteQuery(rangeQuery))
                {
                    TableOperation remove = TableOperation.Delete(entity);
                    table.Execute(remove);
                    return true;

                }

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