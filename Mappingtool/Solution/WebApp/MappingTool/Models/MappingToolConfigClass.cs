using Microsoft.Azure.Cosmos.Table;
using Microsoft.Azure.Documents;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace MappingTool.Models
{
    public class MappingToolConfig
    {
        CloudStorageAccount storageAccount;
        CloudTableClient tableClient;
        CloudTable table;

        public MappingToolConfig(string connectionstr)
        {
            storageAccount = CloudStorageAccount.Parse(connectionstr);
            tableClient = storageAccount.CreateCloudTableClient();
            table = tableClient.GetTableReference("cfmappingtool");
        }

        public List<listmappingtoolconfig> GetMappingToolConfig()
        {
            var continuationToken = new TableContinuationToken();

            List<listmappingtoolconfig> rbacitemslist = new List<listmappingtoolconfig>();
            do
            {
                var queryResult = table.ExecuteQuerySegmented(new TableQuery<listmappingtoolconfig>(), continuationToken);

                rbacitemslist.AddRange(queryResult.Results);
                continuationToken = queryResult.ContinuationToken;

            } while (continuationToken != null);

            return rbacitemslist;
        }

        public bool UpdateConfig(string RowKey, string newconfig, ref string errormsg)
        {
            try
            {            
                TableQuery<listmappingtoolconfig> rangeQuery = new TableQuery<listmappingtoolconfig>().Where(
                                                                TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, RowKey));

                foreach (listmappingtoolconfig entity in table.ExecuteQuery(rangeQuery))
                {
                    entity.Value = newconfig;
                    TableOperation update = TableOperation.Replace(entity);
                    table.Execute(update);
                    return true;
                }

                errormsg = "Error: configuration not found";
                return false;
            }
            catch (Exception ex)
            {
                errormsg = ex.Message;
                return false;
            }
        }
    }
}