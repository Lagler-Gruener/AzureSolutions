using Microsoft.Azure.Management.Graph.RBAC.Fluent;
using Microsoft.Azure.Management.ResourceManager.Fluent;
using Microsoft.Azure.Management.ResourceManager.Fluent.Core;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;


namespace MappingTool.Models
{
    public class ResourceGroup
    {

        private Microsoft.Azure.Management.Fluent.IAzure LogintoAzure(string subscriptionid)
        {
            string ClientId = MappingTool.MvcApplication.MappingToolAppID;
            string ClientSecret = MappingTool.MvcApplication.MappingToolAppSecret;
            string AzureTenantId = MappingTool.MvcApplication.MappingToolTenantID;

            var credentials = SdkContext.AzureCredentialsFactory.FromServicePrincipal(ClientId, ClientSecret, AzureTenantId, AzureEnvironment.AzureGlobalCloud);

            var azure = Microsoft.Azure.Management.Fluent.Azure
                .Configure()
                .Authenticate(credentials)
                .WithSubscription(subscriptionid);

            return azure;
        }

        public listsrgnew GetNewRGConfig()
        {
            Subscriptions subscriptionclass = new Subscriptions(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);
            RBAC rbacclass = new RBAC(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);

            List<listsubscriptions> subscriptions = subscriptionclass.GetSubscriptionList();
            List<listrbacmapping> rbacconfig = rbacclass.GetRBACList();

            List<listazurergreqconfigs> rgdefconfig = new List<listazurergreqconfigs>();
            rgdefconfig.Add(
                new listazurergreqconfigs
                {
                    RGPrefix = MappingTool.MvcApplication.MappingtoolConfiguration.Where(o => o.RowKey == "Conf-App-RG-to-Monitor").FirstOrDefault().Value
                }
            );

            List<listazuretags> addtags = new List<listazuretags>();
            string[] additionalTags = MappingTool.MvcApplication.MappingtoolConfiguration.Where(o => o.RowKey == "App-Conf-ReqAdditionalTags").FirstOrDefault().Value.ToString().Split(new string[] { "," }, StringSplitOptions.RemoveEmptyEntries);

            foreach (var item in additionalTags)
            {
                addtags.Add(
                    new listazuretags { TagName = item }
                    );
            }

            listsrgnew mymodel = new listsrgnew();
            mymodel.RbacConfig = rbacconfig;
            mymodel.Subscriptions = subscriptions;
            mymodel.Tags = addtags;
            mymodel.RGDefConfigs = rgdefconfig;

            return mymodel;
        }

        public listsrgnew GetExistRGConfig(string partitionkey, string resourcegroup, string subscriptionid, string assignpermissions)
        {
            Subscriptions subscriptionclass = new Subscriptions(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);
            RBAC rbacclass = new RBAC(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);

            List<listsubscriptions> subscriptions = subscriptionclass.GetSubscriptionList(subscriptionid);
            List<listrbacmapping> rbacconfig = rbacclass.GetRBACList(assignpermissions);

            List<listazurergreqconfigs> rgdefconfig = new List<listazurergreqconfigs>();
            rgdefconfig.Add(
                new listazurergreqconfigs
                {
                    RGPrefix = MappingTool.MvcApplication.MappingtoolConfiguration.Where(o => o.RowKey == "Conf-App-RG-to-Monitor").FirstOrDefault().Value
                }
            );

            listsrgnew mymodel = new listsrgnew();
            mymodel.RbacConfig = rbacconfig;
            mymodel.Subscriptions = subscriptions;
            mymodel.RGDefConfigs = rgdefconfig;

            return mymodel;
        }

        public bool AddNewRG(string subscriptionid, string rgname, Region region, Dictionary<string, string> TagList, ref string errormessage)
        {
            try
            {
                Microsoft.Azure.Management.Fluent.IAzure azure = LogintoAzure(subscriptionid);
                var resourcegroup = azure.ResourceGroups
                                            .Define(rgname)
                                            .WithRegion(Region.EuropeWest)
                                            .WithTags(TagList)
                                            .Create();
                return true;
            }
            catch (Exception ex)
            {
                errormessage = ex.Message;
                return false;
            }            
        }

        public bool UpdateRG(string subscriptionid, string rgname, string permissions, ref string errormessage)
        {
            try
            {
                Microsoft.Azure.Management.Fluent.IAzure azure = LogintoAzure(subscriptionid);
                var resourcegroup = azure.ResourceGroups.GetByName(rgname);

                var updatedrg = resourcegroup.Update()
                                                .WithTag("SolMappingPerm", permissions)
                                                .Apply();
                return true;
            }
            catch (Exception ex)
            {
                errormessage = ex.Message;
                return false;
            }
        }
    }
}