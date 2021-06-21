using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Security.Principal;
using System.Threading.Tasks;
using System.Web;
using System.Web.Configuration;
using System.Web.Mvc;
using System.Web.Optimization;
using System.Web.Routing;

namespace CABackupFrontend
{
    public class MvcApplication : System.Web.HttpApplication
    {
        public static string Connectionstring { get; set; }

        protected void Application_Start()
        {            
            var task = Task.Run(async () => await GetConfiguration());
            var result = task.Result;

            AreaRegistration.RegisterAllAreas();
            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
            RouteConfig.RegisterRoutes(RouteTable.Routes);
            BundleConfig.RegisterBundles(BundleTable.Bundles);            
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

            KeyVaultSecret connectionstring = client.GetSecret("StrAccConnectionString");
            Connectionstring = connectionstring.Value;

            return true;
        }
    }
}
