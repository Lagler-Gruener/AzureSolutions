using Microsoft.Azure.Cosmos.Table;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Web;

namespace MappingTool.Models
{

    public class Subscriptions
    {
        CloudStorageAccount storageAccount;
        CloudTableClient tableClient;
        CloudTable table;

        public Subscriptions(string connectionstr, string TableName)
        {
            storageAccount = CloudStorageAccount.Parse(connectionstr);
            tableClient = storageAccount.CreateCloudTableClient();
            table = tableClient.GetTableReference(TableName);
        }

        public List<listsubscriptions> GetSubscriptionList([Optional,
                                                            DefaultParameterValue("none")] string subscriptionid)
        {
            TableQuery<listsubscriptions> query;
            if (subscriptionid == "none")
            {
                query = new TableQuery<listsubscriptions>()
                            .Where(TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "SUB"));
            }
            else
            {
                query = new TableQuery<listsubscriptions>().Where(
                                                            TableQuery.CombineFilters(
                                                            TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "SUB"),
                                                            TableOperators.And,
                                                            TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, subscriptionid)));
            }

            var continuationToken = new TableContinuationToken();
            var message = table.ExecuteQuery(query);


            List<listsubscriptions> subitemslist = new List<listsubscriptions>();
            foreach (var item in message)
            {
                subitemslist.Add(new listsubscriptions { PartitionKey = item.PartitionKey, RowKey = item.RowKey, SubMapping = item.SubMapping });
            }

            return subitemslist;
        }

        public bool NewSubList(string SubID, string mapping, ref string errormsg)
        {
            try
            {            
                TableQuery<listsubscriptions> rangeQuerycheckifexist = new TableQuery<listsubscriptions>().Where(
                                                                        TableQuery.CombineFilters(
                                                                            TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "SUB"),
                                                                            TableOperators.And,
                                                                            TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, SubID)));
                if (table.ExecuteQuery(rangeQuerycheckifexist).Count() == 0)
                {
                    var newsubitemslist = new listsubscriptions()
                    {
                        PartitionKey = "SUB",
                        RowKey = SubID,
                        SubMapping = mapping
                    };

                    TableOperation insert = TableOperation.Insert(newsubitemslist);

                    try
                    {
                        table.Execute(insert);
                        return true;
                    }
                    catch (Exception ex)
                    {
                        errormsg = ex.Message;
                        return false;
                    }
                }
                else
                {
                    errormsg = "The configuration already exist.";
                    return false;
                }
            }
            catch (Exception ex)
            {
                errormsg = ex.Message;
                return false;
                    
            }
        }

        public bool RemoveSubList(string SubID, ref string errormsg)
        {
            TableQuery<listsubscriptions> rangeQuery = new TableQuery<listsubscriptions>().Where(
                                                            TableQuery.CombineFilters(
                                                                TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "SUB"),
                                                                TableOperators.And,
                                                                TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, SubID)));

            try
            {
                foreach (listsubscriptions entity in table.ExecuteQuery(rangeQuery))
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

        public bool UpdateSubList(string SubID, string newmapping, ref string errormsg)
        {
            try
            {            
                TableQuery<listsubscriptions> rangeQuerycheckifexist = new TableQuery<listsubscriptions>().Where(
                                                                        TableQuery.CombineFilters(
                                                                            TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "SUB"),
                                                                            TableOperators.And,
                                                                            TableQuery.GenerateFilterCondition("SubMapping", QueryComparisons.Equal, newmapping)));
                if (table.ExecuteQuery(rangeQuerycheckifexist).Count() == 0)
                {
                    TableQuery<listsubscriptions> rangeQuery = new TableQuery<listsubscriptions>().Where(
                                                            TableQuery.CombineFilters(
                                                                TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "SUB"),
                                                                TableOperators.And,
                                                                TableQuery.GenerateFilterCondition("RowKey", QueryComparisons.Equal, SubID)));

                    foreach (listsubscriptions entity in table.ExecuteQuery(rangeQuery))
                    {
                        entity.SubMapping = newmapping;
                        TableOperation update = TableOperation.Replace(entity);
                        table.Execute(update);
                    }

                    return true;
                }
                else
                {
                    errormsg = "Cannot update configuration. Mappingvalue is in use!";
                    return false;
                }
            }
            catch (Exception ex)
            {
                errormsg = ex.Message;
                return false;
            }
        }
    }
}