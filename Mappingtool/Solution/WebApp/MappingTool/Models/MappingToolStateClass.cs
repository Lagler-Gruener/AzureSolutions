using Azure.Storage.Queues;
using Microsoft.Ajax.Utilities;
using Microsoft.Azure;
using Microsoft.Azure.Cosmos.Table;
using Microsoft.Azure.Management.Automation;
using Microsoft.Azure.Management.Automation.Models;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace MappingTool.Models
{
    public class MappingToolState
    {
        public MappingToolState()
        {

        }

        public List<listmessagequeue> GetAzureQueueMessages(string connectionstr)
        {
            List<listmessagequeue> queuemessages = new List<listmessagequeue>();

            var filtered = MappingTool.MvcApplication.MappingtoolConfiguration.Where(o => o.RowKey.EndsWith("Queue"));

            foreach (var msqueue in filtered)
            {
                QueueClient queue = new QueueClient(connectionstr, msqueue.Value);

                TimeSpan span = new TimeSpan(0, 0, 1);
                var messages = queue.PeekMessages(32);

                queuemessages.Add(new listmessagequeue
                {
                    Queue = msqueue.Value,
                    MsgCount = messages.Value.Length.ToString()
                }
                );
            }

            return queuemessages;
        }

        public List<listrunnbookstate> GetAutomationRunningRunbooks(string connectionstr)
        {
            List<listrunnbookstate> runnbookstate = new List<listrunnbookstate>();
            try
            {            
                var resourcegroup = MappingTool.MvcApplication.MappingtoolConfiguration.Where(o => o.RowKey == "Conf-App-ResourceGroup").FirstOrDefault();
                var automationaccount = MappingTool.MvcApplication.MappingtoolConfiguration.Where(o => o.RowKey == "Conf-App-Automation-Account").FirstOrDefault();

                AuthenticationContext authContext = new AuthenticationContext(string.Format("https://login.windows.net/{0}", MappingTool.MvcApplication.MappingToolTenantID));

                AuthenticationResult tokenAuthResult = authContext.AcquireTokenAsync("https://management.azure.com",
                                            new ClientCredential(MappingTool.MvcApplication.MappingToolAppID, MappingTool.MvcApplication.MappingToolAppSecret)).Result;

                TokenCloudCredentials cred = new TokenCloudCredentials(
                                MappingTool.MvcApplication.MappingToolSubscriptionID, tokenAuthResult.AccessToken);

                AutomationManagementClient client =
                                new AutomationManagementClient(cred);

                var runbooks = client.Runbooks.List(resourcegroup.Value, automationaccount.Value);
                
                foreach (var runbook in runbooks.Runbooks)
                {
                    JobListParameters param = new JobListParameters();
                    param.RunbookName = runbook.Name;

                    var stateall = client.Jobs.List(resourcegroup.Value, automationaccount.Value, param);

                    int completed = 0;
                    int failed = 0;
                    string currentstate = "None";
                    string laststate = "None";
                    if (stateall.Jobs.Count == 1)
                    {
                        currentstate = stateall.Jobs[0].Properties.Status;

                        foreach (var job in stateall.Jobs)
                        {
                            if (job.Properties.Status == JobStatus.Completed)
                            {
                                completed++;
                            }
                            else if (job.Properties.Status == JobStatus.Failed)
                            {
                                failed++;
                            }
                        }
                    }
                    else if (stateall.Jobs.Count > 1)
                    {
                        currentstate = stateall.Jobs[0].Properties.Status;
                        laststate = stateall.Jobs[1].Properties.Status;

                        foreach (var job in stateall.Jobs)
                        {
                            if (job.Properties.Status == JobStatus.Completed)
                            {
                                completed++;
                            }
                            else if (job.Properties.Status == JobStatus.Failed)
                            {
                                failed++;
                            }
                        }
                    }

                    runnbookstate.Add(new listrunnbookstate
                    {
                        RunnbookName = runbook.Name,
                        CurrentState = currentstate,
                        LastState = laststate,
                        SuccessCount = completed.ToString(),
                        FaildCount = failed.ToString()
                    });

                }

                return runnbookstate;
            }
            catch (Exception ex)
            {
                string a = ex.Message;
                throw;
            }
        }        
    }
}