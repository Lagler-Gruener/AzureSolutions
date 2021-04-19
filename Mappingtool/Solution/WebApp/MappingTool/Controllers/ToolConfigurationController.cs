using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Web.Mvc;
using MappingTool.Models;
using Microsoft.Azure.Documents;

namespace MappingTool.Controllers
{
    public class ToolConfigurationController : Controller
    {
        #region Function for RBACMapping

        RBAC rbacmappingclass;
        public ActionResult RBACMapping()
        {
            return View();
        }

        public ActionResult RBACMappingNew()
        {
            rbacmappingclass = new RBAC(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);
            List<listazurerbacroles> perm = rbacmappingclass.GetAzureRBACPermList(MappingTool.MvcApplication.MappingToolAppID,
                                                                             MappingTool.MvcApplication.MappingToolAppSecret,
                                                                             MappingTool.MvcApplication.MappingToolTenantID,
                                                                             MappingTool.MvcApplication.RBACSubscriptionId);
            return View(perm);
        }

        public ActionResult RBACMappingEdit(string id)
        {
            rbacmappingclass = new RBAC(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);
            List<listrbacmapping> rbacperm = rbacmappingclass.GetRBACList();
            listrbacmapping uid = rbacperm.Where(s => s.RBACID == id).FirstOrDefault();

            return View(uid);            
        }

        public ActionResult RBACMappingDelete(string id)
        {
            rbacmappingclass = new RBAC(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);

            string returnerrormsg = "";            
            if (rbacmappingclass.RemoveRBACMapping(id, ref returnerrormsg))
            {
                return View("RBACMapping");
            }
            else
            {
                ModelState.AddModelError("DeleteMapping", returnerrormsg);
                return View("RBACMapping");
            }

        }        

        public ActionResult RBACMappingSaveExistConfig(FormCollection RBAC)
        {
            rbacmappingclass = new RBAC(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);

            string tbmappingvalue = RBAC["Mapping"].ToUpper();
            string hrbacid = RBAC["RBACID"];
            string errormessage = "";

            if (rbacmappingclass.UpdateRBACList(hrbacid, tbmappingvalue, ref errormessage))
            {
                return View("RBACMapping");
            }
            else
            {
                ModelState.AddModelError("UpdateMapping", errormessage);
                return View("RBACMapping");
            }           
        }

        public ActionResult RBACMappingSaveNewConfig(FormCollection RBAC)
        {
            rbacmappingclass = new RBAC(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);

            string ddltext = RBAC["RBACName"].ToLower();
            string ddlvalue = RBAC["RBACID"];
            string tbmappingvalue = RBAC["TextBoxMapping"].ToUpper();
            string returnerrormsg = "";

            
            if (rbacmappingclass.NewRBACList(ddltext, ddlvalue, tbmappingvalue, ref returnerrormsg))
            {
                return RedirectToAction("RBACMapping", "ToolConfiguration");
            }
            else
            {
                ModelState.AddModelError("SaveNewMapping", returnerrormsg);
                return View("RBACMapping");
            }            
        }

        #endregion

        #region Function for RBACArchiv

        RBACArchiv rbacarchivclass;

        public ActionResult RBACArchiv()
        {
            return View();
        }

        public ActionResult RBACArchivDelete(string partitionkey, string rowkey)
        {
            rbacarchivclass = new RBACArchiv(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RBACArchivTable);

            string returnerrormsg = "";
            
            if (rbacarchivclass.RemoveRBACArchiv(partitionkey, rowkey, ref returnerrormsg))
            {
                return View("RBACArchiv");
            }
            else
            {
                ModelState.AddModelError("RemoveArchive", returnerrormsg);
                return View("RBACArchiv");
            }
        }

        public ActionResult RBACArchivRestore(string partitionkey, string rowkey)
        {
            // Open Task
            //string returnerrormsg = "";
            return View("RBACArchiv");
        }

        #endregion

        #region Functions for Subscriptions

        public ActionResult Subscriptions()
        {
            return View();
        }

        public ActionResult SubMappingNew()
        {
            return View();
        }

        public ActionResult SubMappingSaveNewConfig(FormCollection Sub)
        {
            Subscriptions subscriptionclass = new Subscriptions(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);

            string tbsubidvalue = Sub["TextBoxSubscriptionID"];
            string tbmappingvalue = Sub["TextBoxMapping"];
            string returnerrormsg = "";

            if (subscriptionclass.NewSubList(tbsubidvalue, tbmappingvalue, ref returnerrormsg))
            {
                return RedirectToAction("Subscriptions", "ToolConfiguration");
            }
            else
            {
                ModelState.AddModelError("NewSubscriptionMapping", returnerrormsg);
                return View("Subscriptions");
            }


        }

        public ActionResult SubMappingEdit(string Id)
        {
            Subscriptions subscriptionclass = new Subscriptions(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);

            List<listsubscriptions> submappinglist = subscriptionclass.GetSubscriptionList();
            var subscription = submappinglist.Where(s => s.RowKey == Id).FirstOrDefault();

            return View(subscription);
        }

        public ActionResult SubMappingSaveExistConfig(FormCollection Sub)
        {
            Subscriptions subscriptionclass = new Subscriptions(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);

            string tbmappingvalue = Sub["SubMapping"];
            string hrbacid = Sub["RowKey"];
            string errormessage = "";

            if (subscriptionclass.UpdateSubList(hrbacid, tbmappingvalue, ref errormessage))
            {
                return View("Subscriptions");
            }
            else
            {
                ModelState.AddModelError("SaveExistSubscriptionMapping", errormessage);
                return View("Subscriptions");
            }
        }

        public ActionResult SubMappingDelete(string Id)
        {
            Subscriptions subscriptionclass = new Subscriptions(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);

            string returnerrormsg = "";

            if (subscriptionclass.RemoveSubList(Id, ref returnerrormsg))
            {
                return View("Subscriptions");
            }
            else
            {
                ModelState.AddModelError("DeleteSubscriptionMapping", returnerrormsg);
                return View("Subscriptions");
            }
        }                               

        #endregion

        #region FunctionScope for MappingToolConfig

        public ActionResult MappingToolConfig()
        {
            return View();
        }

        public ActionResult MappingToolConfigEdit(string RowKey)
        {
            var config = MappingTool.MvcApplication.MappingtoolConfiguration.Where(s => s.RowKey == RowKey).FirstOrDefault();
            
            return View(config);
        }

        public ActionResult MappingConfigSave(FormCollection Config)
        {
            MappingToolConfig mappingtoolconfigclass = new MappingToolConfig(MappingTool.MvcApplication.Connectionstring);

            string HFRowKey = Config["RowKey"];
            string tbnewconfig = Config["Value"];
            string returnerrormsg = "";

            if (mappingtoolconfigclass.UpdateConfig(HFRowKey, tbnewconfig, ref returnerrormsg))
            {
                var task = Task.Run(async () => 
                MappingTool.MvcApplication.GetConfiguration());

                return View("MappingToolConfig");
            }
            else
            {
                ModelState.AddModelError("SaveMappingToolConfig", returnerrormsg);
                return View("MappingToolConfig");
            }            
        }

        #endregion            
    }
}