using Microsoft.Azure.Cosmos.Table;
using Microsoft.Azure.Documents;
using Microsoft.Azure.Management.ResourceManager.Fluent;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Web;

namespace MappingTool.Models
{
    public class RBAC
    {
        CloudStorageAccount storageAccount;
        CloudTableClient tableClient;
        CloudTable table;

        //Constructor including StorageAccount mapping
        public RBAC(string connectionstr, string TableName)
        {
            storageAccount = CloudStorageAccount.Parse(connectionstr);
            tableClient = storageAccount.CreateCloudTableClient();
            table = tableClient.GetTableReference(TableName);
        }

        public List<listrbacmapping> GetRBACList([Optional,
                                                  DefaultParameterValue(",")] string permissions)
        {
            string[] permissionlist = permissions.ToLower().Split(new string[] { "," }, StringSplitOptions.RemoveEmptyEntries);
            TableQuery<listrbacmapping> query = new TableQuery<listrbacmapping>()
                    .Where(TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "RBAC"));

            var continuationToken = new TableContinuationToken();
            var message = table.ExecuteQuery(query);


            List<listrbacmapping> rbacitemslist = new List<listrbacmapping>();
            foreach (var item in message)
            {
                if(permissionlist.Contains(item.RBACPerm.ToLower()))
                {
                    rbacitemslist.Add(new listrbacmapping { PartitionKey = item.PartitionKey, RowKey = item.RowKey, Mapping = item.Mapping, RBACID = item.RBACID, RBACPerm = item.RBACPerm, PermAssign = "true" });
                }
                else
                {
                    rbacitemslist.Add(new listrbacmapping { PartitionKey = item.PartitionKey, RowKey = item.RowKey, Mapping = item.Mapping, RBACID = item.RBACID, RBACPerm = item.RBACPerm, PermAssign = "false" });
                }
                
            }

            return rbacitemslist;
        }

        public List<listrbacpermconfig> GetRBACConfig()
        {
            var continuationToken = new TableContinuationToken();

            List<listrbacpermconfig> rbacitemslist = new List<listrbacpermconfig>();
            do
            {
                var queryResult = table.ExecuteQuerySegmented(new TableQuery<listrbacpermconfig>(), continuationToken);

                rbacitemslist.AddRange(queryResult.Results);
                continuationToken = queryResult.ContinuationToken;

            } while (continuationToken != null);

            return rbacitemslist;
        }

        public List<listazurerbacroles> GetAzureRBACPermList(string clientId, string clientSecret, string tenantId, string subscriptionid)
        {
            var credentials = SdkContext.AzureCredentialsFactory
                .FromServicePrincipal(clientId, clientSecret, tenantId, AzureEnvironment.AzureGlobalCloud);

            // authenticate to Azure AD
            var authenticated = Microsoft.Azure.Management.Fluent.Azure
                        .Configure()
                        .Authenticate(credentials);

            var sub = authenticated.Subscriptions.List();

            var roles = authenticated.RoleDefinitions.ListByScope($"/subscriptions/" + subscriptionid);

            List<listazurerbacroles> perm = new List<listazurerbacroles>();
            foreach (var role in roles)
            {
                perm.Add(new listazurerbacroles
                {
                    RBACID = role.Name,
                    RBACValue = role.RoleName
                });
            }

            return perm;
        }

        public bool NewRBACList(string Permission, string RBACID, string mapping, ref string errormsg)
        {
            try
            {            
                string filtercheckrbacid = TableQuery.CombineFilters(
                                                        TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "RBAC"),
                                                        TableOperators.And,
                                                        TableQuery.GenerateFilterCondition("RBACID", QueryComparisons.Equal, RBACID));

                string filtercheckmapping = TableQuery.CombineFilters(
                                                        TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "RBAC"),
                                                        TableOperators.And,
                                                        TableQuery.GenerateFilterCondition("Mapping", QueryComparisons.Equal, mapping));

                TableQuery<listrbacmapping> rangeQuerycheckifexist = new TableQuery<listrbacmapping>().Where(
                                                                        TableQuery.CombineFilters(
                                                                            filtercheckrbacid,
                                                                            TableOperators.Or,
                                                                            filtercheckmapping));

                if (table.ExecuteQuery(rangeQuerycheckifexist).Count() == 0)
                {
                    var newrbacitemslist = new listrbacmapping()
                    {
                        PartitionKey = "RBAC",
                        RowKey = "RBAC" + Permission,
                        Mapping = mapping,
                        RBACID = RBACID,
                        RBACPerm = Permission
                    };

                    TableOperation insert = TableOperation.Insert(newrbacitemslist);

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

        public bool UpdateRBACList(string RBACID, string newmapping, ref string errormsg)
        {
            try
            {            
                TableQuery<listrbacmapping> rangeQuerycheckifexist = new TableQuery<listrbacmapping>().Where(
                                                                        TableQuery.CombineFilters(
                                                                            TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "RBAC"),
                                                                            TableOperators.And,
                                                                            TableQuery.GenerateFilterCondition("Mapping", QueryComparisons.Equal, newmapping)));
                if (table.ExecuteQuery(rangeQuerycheckifexist).Count() == 0)
                {
                    TableQuery<listrbacmapping> rangeQuery = new TableQuery<listrbacmapping>().Where(
                                                            TableQuery.CombineFilters(
                                                                TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "RBAC"),
                                                                TableOperators.And,
                                                                TableQuery.GenerateFilterCondition("RBACID", QueryComparisons.Equal, RBACID)));

                    foreach (listrbacmapping entity in table.ExecuteQuery(rangeQuery))
                    {
                        entity.Mapping = newmapping;
                        TableOperation update = TableOperation.Replace(entity);
                        table.Execute(update);
                        return true;
                    }

                    errormsg = "RBAC mapping not found";
                    return false;
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

        public bool RemoveRBACMapping(string RBACID, ref string errormsg)
        {
            try
            {            
                TableQuery<listrbacmapping> rangeQuery = new TableQuery<listrbacmapping>().Where(
                                                                TableQuery.CombineFilters(
                                                                    TableQuery.GenerateFilterCondition("PartitionKey", QueryComparisons.Equal, "RBAC"),
                                                                    TableOperators.And,
                                                                    TableQuery.GenerateFilterCondition("RBACID", QueryComparisons.Equal, RBACID)));

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
            catch (Exception ex)
            {
                errormsg = ex.Message;
                return false;
            }
        }
       
    }
}