using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using CABackupFrontend.Models;
using Newtonsoft.Json.Linq;
using Newtonsoft.Json;
using System.Net.Http;
using System.Threading.Tasks;
using System.Configuration;

namespace CABackupFrontend.Controllers
{
    public class BackupsController : Controller
    {
        // GET: Backups
        public ActionResult Index()
        {
            return View();
        }

        public ActionResult Backups()
        {            

            return View();
        }

        public ActionResult BackupDetails(string rowkey, string partitionkey)
        {
            CA_Backup_Model model = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);
            List<listcabackupdetails> backupdetail = model.GetBackupDetails(partitionkey, rowkey);

            if(backupdetail.Count > 0)
            {
                string backupdate = backupdetail[0].BackupDate;
                string backuptype = backupdetail[0].PartitionKey;

                JObject backupdetails = new JObject();
                JObject backupdetailsnewcaversion;

                if (partitionkey == "CABackupChanges")
                {
                    backupdetails = JObject.Parse(backupdetail[0].CAOldValue);
                    backupdetailsnewcaversion = JObject.Parse(backupdetail[0].CANewValue);

                    ViewBag.NewPolicyID = (string)backupdetailsnewcaversion["id"];
                    ViewBag.NewPolicyname = (string)backupdetailsnewcaversion["displayName"];
                    ViewBag.NewPolicystate = (string)backupdetailsnewcaversion["state"];

                    try
                    {
                        ViewBag.NewJSONConditions = (JValue.Parse(backupdetailsnewcaversion["conditions"].ToString()).ToString(Formatting.Indented)).ToString();
                    }
                    catch (Exception)
                    {
                        ViewBag.NewJSONConditions = "nothing defined";
                    }

                    try
                    {
                        ViewBag.NewJSONGrantControls = (JValue.Parse(backupdetailsnewcaversion["grantControls"].ToString()).ToString(Formatting.Indented)).ToString();
                    }
                    catch (Exception)
                    {
                        ViewBag.NewJSONGrantControls = "nothing defined";
                    }

                    try
                    {
                        ViewBag.NewJSONSessionControls = (JValue.Parse(backupdetailsnewcaversion["sessionControls"].ToString()).ToString(Formatting.Indented)).ToString();
                    }
                    catch (Exception)
                    {
                        ViewBag.NewJSONSessionControls = "nothing defined";
                    }
                    
                }
                else if (partitionkey == "CABackupDaily")
                {
                    backupdetails = JObject.Parse(backupdetail[0].CABackup);
                }

                ViewBag.RestorePolicyID = (string)backupdetails["id"];
                ViewBag.RestorePolicyname = (string)backupdetails["displayName"];
                ViewBag.RestorePolicystate = (string)backupdetails["state"];
                if (backupdetail[0].modifiedby == "")
                {
                    ViewBag.ModifiedBy = "Unknown";
                }
                else
                {
                    ViewBag.ModifiedBy = backupdetail[0].modifiedby;
                }

                try
                {
                    ViewBag.RestoreJSONConditions = (JValue.Parse(backupdetails["conditions"].ToString()).ToString(Formatting.Indented)).ToString();
                }
                catch (Exception)
                {
                    ViewBag.RestoreJSONConditions = "nothing defined";
                }

                try
                {
                    ViewBag.RestoreJSONGrantControls = (JValue.Parse(backupdetails["grantControls"].ToString()).ToString(Formatting.Indented)).ToString();
                }
                catch (Exception)
                {
                    ViewBag.RestoreJSONGrantControls = "nothing defined";
                }

                try
                {
                    ViewBag.RestoreJSONSessionControls = (JValue.Parse(backupdetails["sessionControls"].ToString()).ToString(Formatting.Indented)).ToString();
                }
                catch (Exception)
                {
                    ViewBag.RestoreJSONSessionControls = "nothing defined";
                }
                
            }

            return View();
        }

        public ActionResult BackupRestore(string rowkey, string partitionkey)
        {
            CA_Backup_Model model = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);
            List<listcabackupdetails> backupdetail = model.GetBackupDetails(partitionkey, rowkey);

            if (backupdetail.Count > 0)
            {
                string backupdate = backupdetail[0].BackupDate;
                string backuptype = backupdetail[0].PartitionKey;

                JObject backupdetails = new JObject();

                if (partitionkey == "CABackupChanges")
                {
                    backupdetails = JObject.Parse(backupdetail[0].CAOldValue);
                }
                else if (partitionkey == "CABackupDaily")
                {
                    backupdetails = JObject.Parse(backupdetail[0].CABackup);
                }

                ViewBag.PartitionKey = partitionkey;
                ViewBag.RowKey = backupdetail[0].RowKey;
                ViewBag.RestorePolicyID = (string)backupdetails["id"];
                ViewBag.RestorePolicyname = (string)backupdetails["displayName"];
                ViewBag.RestorePolicystate = (string)backupdetails["state"];

                try
                {
                    ViewBag.RestoreJSONConditions = (JValue.Parse(backupdetails["conditions"].ToString()).ToString(Formatting.Indented)).ToString();
                }
                catch (Exception)
                {
                    ViewBag.RestoreJSONConditions = "nothing defined";
                }

                try
                {
                    ViewBag.RestoreJSONGrantControls = (JValue.Parse(backupdetails["grantControls"].ToString()).ToString(Formatting.Indented)).ToString();
                }
                catch (Exception)
                {
                    ViewBag.RestoreJSONGrantControls = "nothing defined";
                }

                try
                {
                    ViewBag.RestoreJSONSessionControls = (JValue.Parse(backupdetails["sessionControls"].ToString()).ToString(Formatting.Indented)).ToString();
                }
                catch (Exception)
                {
                    ViewBag.RestoreJSONSessionControls = "nothing defined";
                }

            }

            return View();
        }

        public async Task<ActionResult> RestoreNewPolicy(string partitionkey, string rowkey)
        {
            CA_Backup_Model modelclass = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);
            await modelclass.Restoretonewpolicy(partitionkey, rowkey);

            return View("Backups");
        }

        public async Task<ActionResult> RestorePolicy(string partitionkey, string rowkey)
        {
            CA_Backup_Model modelclass = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);
            await modelclass.Restoretoexistingpolicy(partitionkey, rowkey);

            return View("Backups");
        }
    }
}