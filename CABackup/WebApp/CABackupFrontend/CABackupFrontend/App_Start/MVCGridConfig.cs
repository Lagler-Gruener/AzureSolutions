[assembly: WebActivatorEx.PreApplicationStartMethod(typeof(CABackupFrontend.MVCGridConfig), "RegisterGrids")]

namespace CABackupFrontend
{
    using System;
    using System.Web;
    using System.Web.Mvc;
    using System.Linq;
    using System.Collections.Generic;
    using MVCGrid.Models;
    using MVCGrid.Web;
    using CABackupFrontend.Models;

    public static class MVCGridConfig 
    {
        public static void RegisterGrids()
        {
            // #################################################################################################################
            // #
            // #    GridView for Conditional Access backups
            // #
            // #################################################################################################################

            MVCGridDefinitionTable.Add("CABackups", new MVCGridBuilder<listcabackupconfig>()
                .WithAuthorizationType(AuthorizationType.AllowAnonymous)
                .AddColumns(cols =>
                {
                    cols.Add("Id").WithValueExpression(p => p.RowKey.ToString()).WithVisibility(false);
                    cols.Add("BackupType").WithHeaderText("Type")
                        .WithFiltering(true)
                        .WithValueExpression(p => p.PartitionKey);
                    cols.Add("Policy").WithHeaderText("Policy")
                        .WithFiltering(true)
                        .WithValueExpression(p => p.Policy);
                    cols.Add("BackupDate").WithHeaderText("Date")
                        .WithValueExpression(p => p.BackupDate);
                    cols.Add("Details").WithHtmlEncoding(false)
                        .WithSorting(false)
                        .WithHeaderText(" ")
                        .WithValueExpression((p, c) => c.UrlHelper.Action("BackupDetails", "Backups", new { rowkey = p.RowKey, partitionkey = p.PartitionKey }))
                        .WithValueTemplate("<a href='{Value}' class='btn btn-info' role='button'>Details</a>");
                    cols.Add("Restore").WithHtmlEncoding(false)
                        .WithSorting(false)
                        .WithFiltering(true)
                        .WithHeaderText(" ")
                        .WithValueExpression((p, c) => Convert.ToBoolean(p.BackupRestoreing) ? "btn-light disabled" : "btn-warning")
                        .WithValueTemplate("<a href='BackupRestore?rowkey={Model.RowKey}&partitionkey={Model.PartitionKey}' class='btn {Value}' role='button'>Restore</a>");
                })
                .WithFiltering(true)
                .WithPaging(true, 7)
                .WithRetrieveDataMethod((context) =>
                {                    
                    var result = new QueryResult<listcabackupconfig>();
                    CA_Backup_Model backuplist = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);

                    var options = context.QueryOptions;
                    var deffilterbackuptype = options.GetFilterString("BackupType");
                    var deffilterpolicy = options.GetFilterString("Policy");

                    IEnumerable<listcabackupconfig> filteredbackup;
                    if (deffilterbackuptype != null && deffilterpolicy != null)
                    {
                        filteredbackup = backuplist.GetBackups()
                                                    .Where(o => (o.PartitionKey == deffilterbackuptype) &&
                                                                (o.Policy.ToLower().Contains(deffilterpolicy.ToLower()))).AsQueryable();
                    }
                    else if (deffilterbackuptype != null)
                    {
                        filteredbackup = backuplist.GetBackups()
                                                    .Where(o => (o.PartitionKey == deffilterbackuptype)).AsQueryable();
                    }
                    else if(deffilterpolicy != null)
                    {
                        filteredbackup = backuplist.GetBackups()
                                                    .Where(o => (o.Policy.ToLower().Contains(deffilterpolicy.ToLower()))).AsQueryable();
                    }
                    else
                    {
                        filteredbackup = backuplist.GetBackups().AsQueryable();
                    }

                    result.TotalRecords = filteredbackup.Count();

                    if (options.GetLimitOffset().HasValue)
                    {
                        filteredbackup = filteredbackup.Skip(options.GetLimitOffset().Value).Take(options.GetLimitRowcount().Value);
                    }

                    result.Items = filteredbackup.ToList();

                    return result;
                })
            );

            // #################################################################################################################
            // #
            // #    GridView for backup translation settings
            // #
            // #################################################################################################################

            MVCGridDefinitionTable.Add("CABackupsTranslation", new MVCGridBuilder<listcabackuptranslation>()
                .WithAuthorizationType(AuthorizationType.AllowAnonymous)
                .AddColumns(cols =>
                {
                    cols.Add("PartitionKey").WithValueExpression(p => p.PartitionKey.ToString()).WithVisibility(false);
                    cols.Add("Section").WithHeaderText("Section")
                        .WithValueExpression(p => p.Section);
                    cols.Add("Function").WithHeaderText("Function")
                        .WithValueExpression(p => p.Function);
                    cols.Add("Setting").WithHeaderText("Setting")
                        .WithValueExpression(p => p.Setting);
                    cols.Add("Value").WithHeaderText("Value")
                        .WithValueExpression(p => p.RowKey);
                    cols.Add("Translation").WithHeaderText("Translation")
                        .WithValueExpression(p => p.Translation);
                    cols.Add("Delete").WithHtmlEncoding(false)
                        .WithSorting(false)
                        .WithHeaderText(" ")
                        .WithValueExpression((p, c) => c.UrlHelper.Action("TranslationDelete", "Settings", new { rowkey = p.RowKey, partitionkey = p.PartitionKey }))
                        .WithValueTemplate("<a href='{Value}' class='btn btn-warning' role='button'>Delete</a>");
                })
                .WithFiltering(true)
                .WithPaging(true, 5)
                .WithRetrieveDataMethod((context) =>
                {
                    var result = new QueryResult<listcabackuptranslation>();
                    CA_Backup_Model backuptranslationlist = new CA_Backup_Model(CABackupFrontend.MvcApplication.Connectionstring);

                    var options = context.QueryOptions;

                    IEnumerable<listcabackuptranslation> filteredbackup;

                        filteredbackup = backuptranslationlist.GetBackupTranslations().AsQueryable();
                   
                    result.TotalRecords = filteredbackup.Count();

                    if (options.GetLimitOffset().HasValue)
                    {
                        filteredbackup = filteredbackup.Skip(options.GetLimitOffset().Value).Take(options.GetLimitRowcount().Value);
                    }

                    result.Items = filteredbackup.ToList();

                    return result;
                })
            );
        }
    }
}