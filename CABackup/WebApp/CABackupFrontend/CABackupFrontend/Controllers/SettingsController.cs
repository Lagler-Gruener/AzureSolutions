using CABackupFrontend.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace CABackupFrontend.Controllers
{
    public class SettingsViewModel
    {
        public listsettingsrestorevalidation validationsettings { get; set; }
        public listsettingsimportconfigurations importconfigurationsettings { get; set; }
    }

    public class SettingsController : Controller
    {
        // GET: Settings
        public ActionResult Setting()
        {
            CA_Backup_Model modelclass = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);

            SettingsViewModel viewmodel = new SettingsViewModel();
            viewmodel.validationsettings = modelclass.GetValidationSettings();
            viewmodel.importconfigurationsettings = modelclass.GetConfigurationVersion();

            return View(viewmodel);
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

                return RedirectToAction("Setting", "Settings");
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

            return RedirectToAction("Setting", "Settings");
        }

        public ActionResult SaveOverrideValidation(CABackupFrontend.Controllers.SettingsViewModel inputdata)
        {
            CA_Backup_Model modelclass = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);
            modelclass.UpdateValidationSettings(inputdata.validationsettings);

            return RedirectToAction("Setting", "Settings");
        }

        public ActionResult ImportConfiguration()
        {
            CA_Backup_Model modelclass = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);
            modelclass.UpdateConfigSettings();
            return RedirectToAction("Setting", "Settings");
        }
    }
}