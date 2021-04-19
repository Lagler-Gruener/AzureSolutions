using MappingTool.Models;
using Microsoft.Azure.Management.ResourceManager.Fluent.Core;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace MappingTool.Controllers
{
    public class AdminToolsController : Controller
    {
        #region Functions for Azure RG

        public ActionResult AzureRG()
        {            
            return View();
        }
        
        public ActionResult CreateAzureRG()
        {
            ResourceGroup resourcegroupclass = new ResourceGroup();
            listsrgnew mymodel = resourcegroupclass.GetNewRGConfig();

            IEnumerable<listazurergreqconfigs> config = mymodel.RGDefConfigs;
            ViewBag.RequiredPrefix = config.FirstOrDefault().RGPrefix;

            return View(mymodel);
        }

        public ActionResult AzureRGSaveConfig(FormCollection Collection)
        {    
            //Get input values from FormCollection
            string hinput = Collection["HInPPrefix"];
            string tbrgname = Collection["TextBoxRGName"];
            string ddlsubid = Collection["SubID"];

            //Validate the ResourceGroup input first
            if (ddlsubid != "")
            {
                if (tbrgname.Length == 0)
                {
                    //Error
                    ResourceGroup resourcegroupclass = new ResourceGroup();
                    listsrgnew listrgmodel = resourcegroupclass.GetNewRGConfig();

                    //Error in rgname input
                    ModelState.AddModelError(Collection["TextBoxRGName"], "Please define the ResourceGroup name!");

                    return View("CreateAzureRG", listrgmodel);
                }
                else
                {
                    //Define full ResourceGroup name including prefix
                    string rgname = hinput + tbrgname;

                    //Validate if there are all required tag values are set.
                    Dictionary<string, string> TagList = new Dictionary<string, string>();
                    foreach (var item in Collection.AllKeys.Where(c => c.StartsWith("labelreqtagval-")))
                    {
                        string additionaltagname = (item.ToString().Split(new string[] { "labelreqtagval-" }, StringSplitOptions.RemoveEmptyEntries)[0]).ToString();
                        string additionalrtagvalue = Collection[item.ToString()];

                        TagList.Add(additionaltagname, additionalrtagvalue);

                        if (additionalrtagvalue.Length == 0)
                        {
                            ModelState.AddModelError(Collection["TextBoxRGName"], "Please enter a value to the " + additionaltagname + " field");
                        }
                    }

                    if (ModelState.IsValid)
                    {
                        ResourceGroup resourcegroupclass = new ResourceGroup();

                        var permtagname = MappingTool.MvcApplication.MappingtoolConfiguration.Where(o => o.RowKey == "Conf-App-RG-MainTag").FirstOrDefault().Value;
                        string permtagvalue = "";

                        foreach (var item in Collection.AllKeys.Where(c => c.StartsWith("chkbperm-")))
                        {
                            permtagvalue += Collection[item.ToString()] + ",";
                        }

                        TagList.Add(permtagname, permtagvalue);

                        string error = "";
                        if (resourcegroupclass.AddNewRG(ddlsubid, rgname, Region.EuropeWest, TagList, ref error))
                        {
                            return View("AzureRG");
                        }
                        else
                        {
                            ModelState.AddModelError("CreateRG", error);
                            return View();
                        }
                    }
                    else
                    {
                        //Error
                        ResourceGroup resourcegroupclass = new ResourceGroup();
                        listsrgnew listrgmodel = resourcegroupclass.GetNewRGConfig();

                        return View("CreateAzureRG", listrgmodel);
                    }
                }
            }
            else
            {
                //Error
                ResourceGroup resourcegroupclass = new ResourceGroup();
                listsrgnew listrgmodel = resourcegroupclass.GetNewRGConfig();

                //Error in rgname input
                ModelState.AddModelError(Collection["TextBoxRGName"], "Please select a subscription for the ResourceGroup!");

                return View("CreateAzureRG", listrgmodel);
            }
        }

        public ActionResult UpdateAzureRG(string partitionkey, string resourcegroup, string subscriptionid, string permissions)
        {
            ResourceGroup resourcegroupclass = new ResourceGroup();
            listsrgnew mymodel = resourcegroupclass.GetExistRGConfig(partitionkey, resourcegroup, subscriptionid, permissions);

            IEnumerable<listazurergreqconfigs> config = mymodel.RGDefConfigs;
            ViewBag.RGName = resourcegroup;

            return View(mymodel);
        }

        public ActionResult AzureRGUpdateexistConfig(FormCollection Collection)
        {
            string hinput = Collection["lbsubscription"];
            string tbrgname = Collection["TextBoxRGName"];
            string ddlsubid = Collection["SubID"];

            ResourceGroup resourcegroupclass = new ResourceGroup();



            //resourcegroupclass.UpdateRG();

            //Error

            listsrgnew listrgmodel = resourcegroupclass.GetNewRGConfig();

            return View("AzureRG", listrgmodel);
        }

        #endregion

        #region Function for MappintToolIssues

        public ActionResult MappingToolIssues()
        {
            return View();
        }

        #endregion         

        #region Function for RBACMarkedasDelete

        public ActionResult RBACMarkedasDelete()
        {
            return View();
        }

        public ActionResult RBACMarkedasDelete_Restore(string partitionkey, string rowkey)
        {
            return View("RBACMarkedasDelete");
        }

        public ActionResult RBACMarkedasDelete_Delete(string AADGroupName, string AADGroupID, string AzureRG, string SubscriptionID, string ADGroupName,
                                                      string ADGroupSID, string ADOUPath, string PartitionKey)
        {
            MarkedasDelete mappingtoolmadclass = new MarkedasDelete();
            string errormessage = "";
            bool result = mappingtoolmadclass.StartRemoveWorkflow(MappingTool.MvcApplication.Connectionstring, AADGroupName, AADGroupID, AzureRG, SubscriptionID, ADGroupName,
                                                                  ADGroupSID, ADOUPath, "Marked as delete approved", PartitionKey, ref errormessage);

            ModelState.AddModelError("MADDelete", errormessage);
            return View("RBACMarkedasDelete");
        }

        #endregion
    }

}