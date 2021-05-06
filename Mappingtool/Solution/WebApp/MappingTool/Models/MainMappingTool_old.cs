using Azure.Storage.Queues;
using Azure.Storage.Queues.Models;
using Microsoft.Ajax.Utilities;
using Microsoft.Azure;
using Microsoft.Azure.Cosmos.Table;
using Microsoft.Azure.Management.Automation;
using Microsoft.Azure.Management.Automation.Models;
using Microsoft.Azure.Management.ResourceManager.Fluent;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Microsoft.WindowsAzure.Storage.Queue;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Web.Mvc;

namespace MappingTool.Modelsold
{
    
    public class mappingtoolrgconfig : TableEntity
    {
        public string AzureRG { get; set; }
        public string AADPermissions { get; set; }
    }



    public class AzureRGDefConfigs
    {
        public string RGPrefix { get; set; }
    }




    public class configuration
    {





        public static IEnumerable<mappingtoolrgconfig> GetRGConfig(string connectionstr, string RBACPermissionTableName)
        {
            CloudStorageAccount storageAccount = CloudStorageAccount.Parse(connectionstr);

            CloudTableClient tableClient = storageAccount.CreateCloudTableClient();

            CloudTable table = tableClient.GetTableReference(RBACPermissionTableName);

            var continuationToken = new TableContinuationToken();

            List<mappingtoolrgconfig> rbacitemslist = new List<mappingtoolrgconfig>();
            do
            {
                var queryResult = table.ExecuteQuerySegmented(new TableQuery<mappingtoolrgconfig>(), continuationToken);

                rbacitemslist.AddRange(queryResult.Results);
                continuationToken = queryResult.ContinuationToken;

            } while (continuationToken != null);

            return rbacitemslist;
        }









    }
}