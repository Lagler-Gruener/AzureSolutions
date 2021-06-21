using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Web;
using System.Web.Mvc;

namespace CABackupFrontend.Controllers
{
    public class HomeController : Controller
    {
        public ActionResult Index()
        {
            string a = Request.Headers["X-MS-CLIENT-PRINCIPAL-NAME"];

            return View();
        }
        

        public ActionResult About()
        {
            return View();
        }

        public ActionResult Contact()
        {
            return View();
        }

        public ActionResult HeaderInformations()
        {
            return View();
        }
    }
}