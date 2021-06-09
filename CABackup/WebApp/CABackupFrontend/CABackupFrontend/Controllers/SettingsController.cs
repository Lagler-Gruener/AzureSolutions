using CABackupFrontend.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace CABackupFrontend.Controllers
{
    public class SettingsController : Controller
    {
        // GET: Settings
        public ActionResult Setting()
        {
            CA_Backup_Model modelclass = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);
            listrestorevalidation settings = modelclass.GetValidationSettings();

            return View(settings);
        }

        public ActionResult NewTranslation()
        {

            return View();
        }

        [HttpPost]
        public ActionResult SaveNewTranslation(listcabackuptranslation NewTranslationSettings)
        {
            if(ModelState.IsValid)
            {
                CA_Backup_Model modelclass = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);
                NewTranslationSettings.PartitionKey = NewTranslationSettings.Function + ":" + NewTranslationSettings.Setting;
                modelclass.AddNewTranslationSetting(NewTranslationSettings);

                return View("Setting");
            }

            return View("NewTranslation");
        }

        public ActionResult TranslationDelete(string partitionkey, string rowkey)
        {
            CA_Backup_Model modelclass = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);

            listcabackuptranslation removeentrylist = new listcabackuptranslation();

            removeentrylist.RowKey = rowkey;
            removeentrylist.PartitionKey = partitionkey;
            removeentrylist.ETag = "*";

            modelclass.RemoveTranslationSetting(removeentrylist);

            return View("Setting");
        }

        public ActionResult SaveOverrideValidation(listrestorevalidation inputdata)
        {
            CA_Backup_Model modelclass = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);
            modelclass.UpdateValidationSettings(inputdata);

            return View("Setting");            
        }
    }
}