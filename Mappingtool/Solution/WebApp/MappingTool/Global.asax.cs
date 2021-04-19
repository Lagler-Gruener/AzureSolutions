using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using MappingTool.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Configuration;
using System.Web.Mvc;
using System.Web.Optimization;
using System.Web.Routing;

namespace MappingTool
{
    public class MvcApplication : System.Web.HttpApplication
    {
        public static string MappingToolAppID { get; set; }
        public static string MappingToolAppSecret { get; set; }
        public static string MappingToolTenantID { get; set; }
        public static string MappingToolSubscriptionID { get; set; }

        public static List<listmappingtoolconfig> MappingtoolConfiguration { get; set; }
        public static string Connectionstring { get; set; }
        public static string RBACSubscriptionId { get; set; }
        public static string RoleMappingTable { get; set; }
        public static string RBACPermissionTable { get; set; }
        public static string RBACArchivTable { get; set; }        

        protected void Application_Start()
        {
            var task = Task.Run(async () => await GetConfiguration());
            var result = task.Result;

            AreaRegistration.RegisterAllAreas();
            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
            RouteConfig.RegisterRoutes(RouteTable.Routes);
            BundleConfig.RegisterBundles(BundleTable.Bundles);
            MappingTool.MVCGridConfig.RegisterGrids();
        }


        public static async Task<Boolean> GetConfiguration()
        {
            var defaultAzureCredentialOptions = new DefaultAzureCredentialOptions();
            defaultAzureCredentialOptions.ExcludeAzureCliCredential = true;
            defaultAzureCredentialOptions.ExcludeEnvironmentCredential = true;
            defaultAzureCredentialOptions.ExcludeInteractiveBrowserCredential = true;

            if (WebConfigurationManager.AppSettings["EnableMI"].ToString() == "false")
            {
                defaultAzureCredentialOptions.ExcludeManagedIdentityCredential = true;
            }            

            defaultAzureCredentialOptions.ExcludeSharedTokenCacheCredential = true;
            defaultAzureCredentialOptions.ExcludeVisualStudioCodeCredential = true;
            defaultAzureCredentialOptions.ExcludeVisualStudioCredential = false;

            var credential = new DefaultAzureCredential(defaultAzureCredentialOptions);

            var client = new SecretClient(new Uri(WebConfigurationManager.AppSettings["KeyVault"].ToString()), credential);

            KeyVaultSecret secred = client.GetSecret("MappingTool-LogA-SharedKey");
            string a = secred.Value;

            //AzureServiceTokenProvider azureServiceTokenProvider = new AzureServiceTokenProvider();
            //var keyVaultClient = new KeyVaultClient(
            //    new KeyVaultClient.AuthenticationCallback(azureServiceTokenProvider.KeyVaultTokenCallback));

            //var appid = await keyVaultClient.GetSecretAsync(WebConfigurationManager.AppSettings["MappingToolAppID"].ToString());
            KeyVaultSecret appid = client.GetSecret(WebConfigurationManager.AppSettings["MappingToolAppID"].ToString());
            MappingToolAppID = appid.Value;

            //var appsecret = await keyVaultClient.GetSecretAsync(WebConfigurationManager.AppSettings["MappingToolAppSecret"].ToString());
            KeyVaultSecret appsecret = client.GetSecret(WebConfigurationManager.AppSettings["MappingToolAppSecret"].ToString());
            MappingToolAppSecret = appsecret.Value;

            //var tenantid = await keyVaultClient.GetSecretAsync(WebConfigurationManager.AppSettings["MappingToolTenantID"].ToString());
            KeyVaultSecret tenantid = client.GetSecret(WebConfigurationManager.AppSettings["MappingToolTenantID"].ToString());
            MappingToolTenantID = tenantid.Value;

            //var appsubscriptionid = await keyVaultClient.GetSecretAsync(WebConfigurationManager.AppSettings["MappingToolSubscriptionID"].ToString());
            KeyVaultSecret appsubscriptionid = client.GetSecret(WebConfigurationManager.AppSettings["MappingToolSubscriptionID"].ToString());
            MappingToolSubscriptionID = appsubscriptionid.Value;

            //var connectionstring = await keyVaultClient.GetSecretAsync(WebConfigurationManager.AppSettings["KeyVaultStorageKey"].ToString());
            KeyVaultSecret connectionstring = client.GetSecret(WebConfigurationManager.AppSettings["KeyVaultStorageKey"].ToString());
            Connectionstring = connectionstring.Value;

            #region Get configuration settings from storage table

            MappingToolConfig mappingtoolconfigclass = new MappingToolConfig(connectionstring.Value);

            List<MappingTool.Models.listmappingtoolconfig> configlist = mappingtoolconfigclass.GetMappingToolConfig();
            MappingtoolConfiguration = configlist;
            RBACSubscriptionId = configlist.Where(s => s.Name == "App-Conf-SubscriptionId").FirstOrDefault().Value.ToString();
            RoleMappingTable = configlist.Where(s => s.Name == "Conf-App-Mapping-Table").FirstOrDefault().Value.ToString();
            RBACPermissionTable = configlist.Where(s => s.Name == "Conf-App-Configuration-Table").FirstOrDefault().Value.ToString();
            RBACArchivTable = configlist.Where(s => s.Name == "Conf-App-Configuration-TableBak").FirstOrDefault().Value.ToString();

            #endregion

            return true;

        }
    }
}
