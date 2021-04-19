//[assembly: WebActivatorEx.PreApplicationStartMethod(typeof(MappingTool.MVCGridConfig), "RegisterGrids")]

namespace MappingTool
{
    using System;
    using System.Web;
    using System.Web.Mvc;
    using System.Linq;
    using System.Collections.Generic;
    using MVCGrid.Models;
    using MVCGrid.Web;
    using MappingTool.Models;
    using Microsoft.Ajax.Utilities;
    using Microsoft.Azure.Management.AppService.Fluent.DomainContact.Definition;

    public static class MVCGridConfig 
    {
        public static void RegisterGrids()
        {
            ColumnDefaults colDefaults = new ColumnDefaults()
            {
                EnableSorting = true
            };

            List<listrbacpermconfig> rbacconfiguration = new List<listrbacpermconfig>();
            RBAC rbacclass = new RBAC(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RBACPermissionTable);
            rbacconfiguration = rbacclass.GetRBACConfig().OrderBy(o => o.AzureRG).ToList();

            // #################################################################################################################
            // #
            // #    GridView for RBAC Mapping
            // #
            // #################################################################################################################

            MVCGridDefinitionTable.Add("RBACMappingConfig", new MVCGridBuilder<listrbacmapping>()
                .WithAuthorizationType(AuthorizationType.AllowAnonymous)
                .AddColumns(cols =>
                {
                    cols.Add("Id").WithValueExpression(p => p.RBACID.ToString()).WithVisibility(false);
                    cols.Add("Permission").WithHeaderText("Permission")
                        .WithFiltering(true)
                        .WithValueExpression(p => p.RBACPerm);
                    cols.Add("Mapping").WithHeaderText("Mapping")
                        .WithValueExpression(p => p.Mapping);
                    cols.Add("Edit").WithHtmlEncoding(false)
                        .WithSorting(false)
                        .WithHeaderText(" ")
                        .WithValueExpression((p, c) => c.UrlHelper.Action("RBACMappingEdit", "ToolConfiguration", new { id = p.RBACID }))
                        .WithValueTemplate("<a href='{Value}' class='btn btn-warning' role='button'>Edit</a>");
                    cols.Add("Delete").WithHtmlEncoding(false)
                        .WithSorting(false)
                        .WithHeaderText(" ")
                        .WithValueExpression((p, c) => c.UrlHelper.Action("RBACMappingDelete", "ToolConfiguration", new { id = p.RBACID }))
                        .WithValueTemplate("<a href='{Value}' class='btn btn-danger' width='20px' role='button'>Delete</a>");
                })
                .WithFiltering(true)
                .WithRetrieveDataMethod((context) =>
                {
                    var option = context.QueryOptions;
                    var deffilter = option.GetFilterString("Permission");

                    var result = new QueryResult<listrbacmapping>();
                    RBAC rbaclist = new RBAC(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);

                    if (deffilter != null)
                    {
                        result.Items = rbaclist.GetRBACList()
                                                    .Where(o => o.RBACPerm.ToLower() == deffilter.ToLower());
                    }
                    else
                    {
                        result.Items = rbaclist.GetRBACList();
                    }
                                        

                    return result;
                })
            );

            // #################################################################################################################
            // #
            // #    GridView for RBAC Archiv
            // #
            // #################################################################################################################

            MVCGridDefinitionTable.Add("RBACConfigArchiv", new MVCGridBuilder<listrbacpermconfig>(colDefaults)
                .WithAuthorizationType(AuthorizationType.AllowAnonymous)
                .AddColumns(cols =>
                {
                    cols.Add("AADGroupID").WithValueExpression(p => p.AADGroupID.ToString()).WithVisibility(false);
                    cols.Add("ADGroupSID").WithValueExpression(p => p.ADGroupSID.ToString()).WithVisibility(false);
                    cols.Add("ADGroupuSNChanged").WithValueExpression(p => p.ADGroupuSNChanged.ToString()).WithVisibility(false);
                    cols.Add("MarkedasDelete").WithValueExpression(p => p.MarkedasDelete.ToString()).WithVisibility(false);
                    cols.Add("RBACPermID").WithValueExpression(p => p.RBACPermID.ToString()).WithVisibility(false);
                    cols.Add("SubscriptionID").WithValueExpression(p => p.SubscriptionID.ToString()).WithVisibility(false);
                    cols.Add("RBACPermName").WithValueExpression(p => p.RBACPermName.ToString()).WithVisibility(false);
                    cols.Add("ADGroupDN").WithValueExpression(p => p.RBACPermName.ToString()).WithVisibility(false);
                    cols.Add("PartitionKey").WithHeaderText("Archivtype")
                        .WithValueExpression(p => p.PartitionKey);
                    cols.Add("AADGroupName").WithHeaderText("AAD Group Name")
                        .WithValueExpression(p => p.AADGroupName);
                    cols.Add("ADGroupName").WithHeaderText("AD Group Name")
                        .WithValueExpression(p => p.ADGroupName);
                    cols.Add("AzureRG").WithHeaderText("Azure RG")
                        .WithValueExpression(p => p.AzureRG);
                    cols.Add("Restore").WithHtmlEncoding(false)
                        .WithSorting(false)
                        .WithHeaderText(" ")
                        .WithVisibility(false)
                        .WithValueExpression((p, c) => c.UrlHelper.Action("RBACArchivRestore", "ToolConfiguration", new { partitionkey = p.PartitionKey, rowkey = p.RowKey }))
                        .WithValueTemplate("<a href='{Value}' class='btn btn-warning' role='button'>Restore</a>");
                    cols.Add("Delete").WithHtmlEncoding(false)
                        .WithSorting(false)
                        .WithHeaderText(" ")
                        .WithValueExpression((p, c) => c.UrlHelper.Action("RBACArchivDelete", "ToolConfiguration", new { partitionkey = p.PartitionKey, rowkey = p.RowKey }))
                        .WithValueTemplate("<a href='{Value}' class='btn btn-danger' role='button'>Delete</a>");
                })
                .WithPaging(true, 10)
                .WithRetrieveDataMethod((context) =>
                {
                    RBACArchiv rbacarchivclass = new RBACArchiv(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RBACArchivTable);

                    var options = context.QueryOptions;
                    var result = new QueryResult<listrbacpermconfig>();

                    var filteredarchiv = new List<listrbacpermconfig>();
                    filteredarchiv = rbacarchivclass.GetAzureRBACArchiv();

                    var query = filteredarchiv.AsQueryable();
                    result.TotalRecords = query.Count();

                    if (options.GetLimitOffset().HasValue)
                    {
                        query = query.Skip(options.GetLimitOffset().Value).Take(options.GetLimitRowcount().Value);
                    }

                    result.Items = query.ToList();


                    return result;
                })
            );


            // #################################################################################################################
            // #
            // #    GridView for Mappingtool Subscriptions
            // #
            // #################################################################################################################

            MVCGridDefinitionTable.Add("SubMappingConfig", new MVCGridBuilder<listsubscriptions>()
                                .WithAuthorizationType(AuthorizationType.AllowAnonymous)
            .AddColumns(cols =>
            {
                cols.Add("Id").WithValueExpression(p => p.RowKey.ToString()).WithVisibility(false);
                cols.Add("SubscriptionID").WithHeaderText("SubscriptionID")
                    .WithFiltering(true)
                    .WithValueExpression(p => p.RowKey);
                cols.Add("Mapping").WithHeaderText("Mapping")
                    .WithValueExpression(p => p.SubMapping);
                cols.Add("Edit").WithHtmlEncoding(false)
                    .WithSorting(false)
                    .WithHeaderText(" ")
                    .WithValueExpression((p, c) => c.UrlHelper.Action("SubMappingEdit", "ToolConfiguration", new { Id = p.RowKey }))
                    .WithValueTemplate("<a href='{Value}' class='btn btn-warning' role='button'>Edit</a>");
                cols.Add("Delete").WithHtmlEncoding(false)
                    .WithSorting(false)
                    .WithHeaderText(" ")
                    .WithValueExpression((p, c) => c.UrlHelper.Action("SubMappingDelete", "ToolConfiguration", new { Id = p.RowKey }))
                    .WithValueTemplate("<a href='{Value}' class='btn btn-danger' width='20px' role='button'>Delete</a>");
            })
            .WithFiltering(true)
            .WithRetrieveDataMethod((context) =>
            {
                var options = context.QueryOptions;
                var deffilter = options.GetFilterString("SubscriptionID");

                Subscriptions subscriptionclass = new Subscriptions(MappingTool.MvcApplication.Connectionstring, MappingTool.MvcApplication.RoleMappingTable);
                var result = new QueryResult<listsubscriptions>();

                if (deffilter !=null)
                {
                    result.Items = subscriptionclass.GetSubscriptionList(deffilter);
                }
                else
                {
                    result.Items = subscriptionclass.GetSubscriptionList();
                }                               

                return result;
            })
            );


            // #################################################################################################################
            // #
            // #    GridView for Mappingtool Configuration
            // #
            // #################################################################################################################

            QueryResult<listmappingtoolconfig> mappingtoolconfig = new QueryResult<listmappingtoolconfig>();
            MVCGridDefinitionTable.Add("MappingToolConfig", new MVCGridBuilder<listmappingtoolconfig>(colDefaults)
                .WithAuthorizationType(AuthorizationType.AllowAnonymous)
                .AddColumns(cols =>
                {
                    cols.Add("ConfigPartitionKey").WithValueExpression(p => p.PartitionKey).WithVisibility(false);
                    cols.Add("ConfigRowKey").WithValueExpression(p => p.RowKey).WithVisibility(false);
                    cols.Add("ConfigName").WithHeaderText("Name")
                        .WithValueExpression(p => p.Name)
                        .WithFiltering(true);
                    cols.Add("Value").WithHeaderText("Value")
                        .WithValueExpression(p => p.Value);
                    cols.Add("Description").WithHeaderText("Description")
                        .WithValueExpression(p => p.Description);
                    cols.Add("Edit").WithHtmlEncoding(false)
                        .WithSorting(false)
                        .WithFiltering(true)
                        .WithHeaderText(" ")
                        .WithValueExpression((p, c) => Convert.ToBoolean(p.AllowtoChange) ? "btn-warning" : "btn-light disabled")
                        .WithValueTemplate("<a href='MappingToolConfigEdit?rowkey={Model.RowKey}' class='btn {Value}' role='button'>Edit</a>");
                })
                .WithPaging(true, 10)
                .WithFiltering(true)
                .WithRetrieveDataMethod((context) =>
                {
                    var options = context.QueryOptions;
                    var result = new QueryResult<listmappingtoolconfig>();

                    var deffilter = options.GetFilterString("ConfigName");
                    var deffilter2 = options.GetFilterString("Edit");

                    IEnumerable<listmappingtoolconfig> query;
                    if (deffilter != null && deffilter2 != null)
                    {
                        query = MappingTool.MvcApplication.MappingtoolConfiguration
                                                                .Where(o => (o.Name.ToLower().Contains(deffilter.ToLower()) &&
                                                                            (o.AllowtoChange.Contains(deffilter2)))).AsQueryable();
                    }
                    else if (deffilter != null)
                    {
                        query = MappingTool.MvcApplication.MappingtoolConfiguration
                                                                .Where(o => o.Name.ToLower().Contains(deffilter.ToLower())).AsQueryable();
                    }
                    else if (deffilter2 != null)
                    {
                        query = MappingTool.MvcApplication.MappingtoolConfiguration
                                                                .Where(o => (o.AllowtoChange.Contains(deffilter2))).AsQueryable();
                    }
                    else
	                {
                        query = MappingTool.MvcApplication.MappingtoolConfiguration
                                                                .AsQueryable();
                    }

                    result.TotalRecords = query.Count();

                    if (options.GetLimitOffset().HasValue)
                    {                        
                        query = query.Skip(options.GetLimitOffset().Value).Take(options.GetLimitRowcount().Value);
                    }

                    result.Items = query.ToList();


                    return result;
                })
            );
            

            // #################################################################################################################
            // #
            // #    GridView for State View (RunbookState)
            // #
            // #################################################################################################################

            MVCGridDefinitionTable.Add("MappingToolRunbookState", new MVCGridBuilder<listrunnbookstate>()
               .WithAuthorizationType(AuthorizationType.AllowAnonymous)
               .AddColumns(cols =>
               {
                   cols.Add("RunnbookName").WithHeaderText("Runbook Name")
                       .WithValueExpression(p => p.RunnbookName);
                   cols.Add("CurrentState").WithHeaderText("State")
                       .WithValueExpression(p => p.CurrentState);
                   cols.Add("LastState").WithHeaderText("Last State")
                       .WithValueExpression(p => p.LastState);
                   cols.Add("SuccessCount").WithHeaderText("Success Count")
                       .WithValueExpression(p => p.SuccessCount);
                   cols.Add("FaildCount").WithHeaderText("Failed Count")
                       .WithValueExpression(p => p.FaildCount);
               })
               .WithRetrieveDataMethod((context) =>
               {
                   var runbookstate = new QueryResult<listrunnbookstate>();

                   MappingToolState mappingtoolstateclass = new MappingToolState();
                   runbookstate.Items = mappingtoolstateclass.GetAutomationRunningRunbooks(MappingTool.MvcApplication.Connectionstring);

                   return runbookstate;
               })
           );


            // #################################################################################################################
            // #
            // #    GridView for State View (MessageQueue)
            // #
            // #################################################################################################################

            QueryResult<listmessagequeue> mappingtoolqueuemsg = new QueryResult<listmessagequeue>();
            MVCGridDefinitionTable.Add("MappingQueueMessages", new MVCGridBuilder<listmessagequeue>(colDefaults)
                .WithAuthorizationType(AuthorizationType.AllowAnonymous)
                .AddColumns(cols =>
                {
                    cols.Add("Queue").WithHeaderText("Queue")
                        .WithValueExpression(p => p.Queue);
                    cols.Add("Insertiontime").WithHeaderText("Insertion Time")
                        .WithValueExpression(p => p.MsgCount);
                })
                .WithPaging(true, 10)
                .WithRetrieveDataMethod((context) =>
                {
                    var options = context.QueryOptions;
                    var result = new QueryResult<listmessagequeue>();

                    var filteredarchiv = new List<listmessagequeue>();
                    MappingToolState mappingtoolstateclass = new MappingToolState();
                    filteredarchiv = mappingtoolstateclass.GetAzureQueueMessages(MappingTool.MvcApplication.Connectionstring);

                    var query = filteredarchiv.AsQueryable();
                    result.TotalRecords = query.Count();

                    if (options.GetLimitOffset().HasValue)
                    {
                        query = query.Skip(options.GetLimitOffset().Value).Take(options.GetLimitRowcount().Value);
                    }

                    result.Items = query.ToList();


                    return result;
                })
            );

            // #################################################################################################################
            // #
            // #    GridView for State View (RBACConfigAAD)
            // #
            // #################################################################################################################

            MVCGridDefinitionTable.Add("RBACConfigAAD", new MVCGridBuilder<listrbacpermconfig>(colDefaults)
                .WithAuthorizationType(AuthorizationType.AllowAnonymous)
                .AddColumns(cols =>
                {
                    cols.Add("AADGroupID").WithValueExpression(p => p.AADGroupID.ToString()).WithVisibility(false);
                    cols.Add("ADGroupSID").WithValueExpression(p => p.ADGroupSID.ToString()).WithVisibility(false);
                    cols.Add("ADGroupuSNChanged").WithValueExpression(p => p.ADGroupuSNChanged.ToString()).WithVisibility(false);
                    cols.Add("MarkedasDelete").WithValueExpression(p => p.MarkedasDelete.ToString()).WithVisibility(false);
                    cols.Add("RBACPermID").WithValueExpression(p => p.RBACPermID.ToString()).WithVisibility(false);
                    cols.Add("SubscriptionID").WithValueExpression(p => p.SubscriptionID.ToString()).WithVisibility(false);
                    cols.Add("AzureRG").WithValueExpression(p => p.AzureRG.ToString()).WithVisibility(false);
                    cols.Add("RBACPermName").WithValueExpression(p => p.RBACPermName.ToString()).WithVisibility(false);
                    cols.Add("AADGroupName").WithHeaderText("AAD Group Name")
                        .WithValueExpression(p => p.AADGroupName);
                    cols.Add("ADGroupDN").WithHeaderText("AD Group DN")
                        .WithValueExpression(p => p.ADGroupDN);
                    cols.Add("ADGroupName").WithHeaderText("AD Group Name")
                        .WithValueExpression(p => p.ADGroupName);
                })
                .WithPaging(true, 10)
                .WithRetrieveDataMethod((context) =>
                {                                  
                    var options = context.QueryOptions;
                    var result = new QueryResult<listrbacpermconfig>();

                        var filtered = rbacconfiguration.Where(o => o.PartitionKey == "AADPerm");

                        var query = filtered.AsQueryable();
                        result.TotalRecords = query.Count();

                        if (options.GetLimitOffset().HasValue)
                        {
                            query = query.Skip(options.GetLimitOffset().Value).Take(options.GetLimitRowcount().Value);
                        }

                        result.Items = query.ToList();

                    return result;
                })
            );

            // #################################################################################################################
            // #
            // #    GridView for State View (RBACConfigRG)
            // #
            // #################################################################################################################

            MVCGridDefinitionTable.Add("RBACConfigRBAC", new MVCGridBuilder<listrbacpermconfig>()
                .WithAuthorizationType(AuthorizationType.AllowAnonymous)
                .AddColumns(cols =>
                {
                    cols.Add("AADGroupID").WithValueExpression(p => p.AADGroupID.ToString()).WithVisibility(false);
                    cols.Add("ADGroupSID").WithValueExpression(p => p.ADGroupSID.ToString()).WithVisibility(false);
                    cols.Add("ADGroupuSNChanged").WithValueExpression(p => p.ADGroupuSNChanged.ToString()).WithVisibility(false);
                    cols.Add("RBACPermID").WithValueExpression(p => p.RBACPermID.ToString()).WithVisibility(false);
                    cols.Add("SubscriptionID").WithValueExpression(p => p.SubscriptionID.ToString()).WithVisibility(false);
                    cols.Add("AADGroupName").WithHeaderText("AAD Group Name")
                        .WithValueExpression(p => p.AADGroupName);
                    cols.Add("ADGroupDN").WithHeaderText("AD Group DN")
                        .WithValueExpression(p => p.ADGroupDN);
                    cols.Add("ADGroupName").WithHeaderText("AD Group Name")
                        .WithValueExpression(p => p.ADGroupName);
                    cols.Add("AzureRG").WithHeaderText("Azure RG")
                        .WithValueExpression(p => p.AzureRG);
                    cols.Add("RBACPermName").WithHeaderText("RBAC Permission")
                        .WithValueExpression(p => p.RBACPermName);
                    cols.Add("MarkedasDelete").WithHeaderText("Marked ad delete")
                        .WithValueExpression(p => p.MarkedasDelete == (p.MarkedasDelete = "1") ? "true" : "false");
                })
                .WithPaging(true, 10)
                .WithRetrieveDataMethod((context) =>
                {
                    var options = context.QueryOptions;
                    var result = new QueryResult<listrbacpermconfig>();

                        var filtered = rbacconfiguration.Where(o => o.PartitionKey == "RBACPerm");

                        var query = filtered.AsQueryable();
                        result.TotalRecords = query.Count();

                        if (options.GetLimitOffset().HasValue)
                        {
                            query = query.Skip(options.GetLimitOffset().Value).Take(options.GetLimitRowcount().Value);
                        }

                        result.Items = query.ToList();

                    return result;
                })
            );


            // #################################################################################################################
            // #
            // #    GridView for RBACMarkedasDelete View
            // #
            // #################################################################################################################

            MVCGridDefinitionTable.Add("RBACMarkedAsDelete", new MVCGridBuilder<listrbacpermconfig>()
                .WithAuthorizationType(AuthorizationType.AllowAnonymous)
                .AddColumns(cols =>
                {
                    cols.Add("AADGroupID").WithValueExpression(p => p.AADGroupID.ToString()).WithVisibility(false);
                    cols.Add("ADGroupSID").WithValueExpression(p => p.ADGroupSID.ToString()).WithVisibility(false);
                    cols.Add("ADGroupuSNChanged").WithValueExpression(p => p.ADGroupuSNChanged.ToString()).WithVisibility(false);
                    cols.Add("MarkedasDelete").WithValueExpression(p => p.MarkedasDelete.ToString()).WithVisibility(false);
                    cols.Add("RBACPermID").WithValueExpression(p => p.RBACPermID.ToString()).WithVisibility(false);
                    cols.Add("SubscriptionID").WithValueExpression(p => p.SubscriptionID.ToString()).WithVisibility(false);
                    cols.Add("ADGroupDN").WithValueExpression(p => p.ADGroupDN.ToString()).WithVisibility(false);
                    cols.Add("AADGroupName").WithHeaderText("AAD Group Name")
                        .WithValueExpression(p => p.AADGroupName);
                    cols.Add("ADGroupName").WithHeaderText("AD Group Name")
                        .WithValueExpression(p => p.ADGroupName);
                    cols.Add("AzureRG").WithHeaderText("Azure RG")
                        .WithValueExpression(p => p.AzureRG);
                    cols.Add("RBACPermName").WithHeaderText("RBAC Permission")
                        .WithValueExpression(p => p.RBACPermName);
                    cols.Add("Restore").WithHtmlEncoding(false)
                        .WithSorting(false)
                        .WithHeaderText(" ")
                        .WithValueExpression((p, c) => c.UrlHelper.Action("RBACMarkedasDelete_Restore", "AdminTools", new { partitionkey = p.PartitionKey, rowkey = p.RowKey }))
                        .WithValueTemplate("<a href='{Value}' class='btn btn-warning' role='button'>Restore</a>");
                    cols.Add("Delete").WithHtmlEncoding(false)
                        .WithSorting(false)
                        .WithHeaderText(" ")
                        .WithValueExpression((p, c) => c.UrlHelper.Action("RBACMarkedasDelete_Delete", "AdminTools", new { AADGroupName = p.AADGroupName, AADGroupID = p.AADGroupID, AzureRG = p.AzureRG, SubscriptionID = p.SubscriptionID,
                                                                                                                             ADGroupName = p.ADGroupName, ADGroupSID = p.ADGroupSID, ADOUPath = p.ADGroupDN, PartitionKey = p.PartitionKey }))
                        .WithValueTemplate("<a href='{Value}' class='btn btn-danger' role='button'>Delete</a>");
                })
                .WithPaging(true, 10)
                .WithRetrieveDataMethod((context) =>
                {
                    rbacconfiguration = rbacclass.GetRBACConfig();
                    var options = context.QueryOptions;
                    var result = new QueryResult<listrbacpermconfig>();

                    var filtered = rbacconfiguration.Where(o => o.MarkedasDelete == "1");

                    var query = filtered.AsQueryable();
                    result.TotalRecords = query.Count();

                    if (options.GetLimitOffset().HasValue)
                    {
                        query = query.Skip(options.GetLimitOffset().Value).Take(options.GetLimitRowcount().Value);
                    }

                    result.Items = query.ToList();

                    return result;
                })
            );



            // #################################################################################################################
            // #
            // #    GridView for configured Azure ResourceGroup View
            // #
            // #################################################################################################################

            MVCGridDefinitionTable.Add("ConfiAzureRGs", new MVCGridBuilder<listexistrg>()
                .WithAuthorizationType(AuthorizationType.AllowAnonymous)
                .AddColumns(cols =>
                {
                    cols.Add("SubscriptionID").WithValueExpression(p => p.SubscriptionID.ToString()).WithVisibility(false);
                    cols.Add("AzureRG").WithHeaderText("ResourceGroup Name")
                        .WithValueExpression(p => p.RGName)
                        .WithFiltering(true);
                    cols.Add("Permissions").WithHeaderText("Permissions")
                        .WithValueExpression(p => p.Perm);   
                    cols.Add("Edit").WithHtmlEncoding(false)
                        .WithSorting(false)
                        .WithHeaderText(" ")
                        .WithValueExpression((p, c) => c.UrlHelper.Action("UpdateAzureRG", "AdminTools", new { partitionkey = p.PartitionKey, resourcegroup = p.RGName, subscriptionid = p.SubscriptionID, permissions = p.Perm }))
                        .WithValueTemplate("<a href='{Value}' class='btn btn-warning' role='button'>Edit</a>");                    
                })
                .WithSorting(true, "AzureRG")
                .WithPaging(true, 10)
                .WithFiltering(true)
                .WithRetrieveDataMethod((context) =>
                {
                    var options = context.QueryOptions;
                    var result = new QueryResult<listexistrg>();

                    var deffilter = options.GetFilterString("AzureRG");

                    IEnumerable<string> filtered;
                    if (deffilter != null)
                    {
                        filtered = rbacconfiguration
                                            .Where(o => (o.PartitionKey == "RBACPerm") && 
                                                        (o.AzureRG.Contains(deffilter)))
                                            .Select(o => o.AzureRG).Distinct();
                    }
                    else
                    {
                        filtered = rbacconfiguration
                                            .Where(o => o.PartitionKey == "RBACPerm")
                                            .Select(o => o.AzureRG).Distinct();
                    }                    
                    
                    List<listexistrg> configuredrgs = new List<listexistrg>();
                    
                    foreach (var item in filtered)
                    {
                        var permresult = rbacconfiguration
                                                .Where(o => o.AzureRG == item);

                        string permission = "";
                        string subscriptionid = "";

                        foreach (var perm in permresult)
                        {
                            permission += perm.RBACPermName + ",";
                            subscriptionid = perm.SubscriptionID;
                        }

                        configuredrgs.Add(new listexistrg
                                            {
                                                PartitionKey = "RBACPerm",
                                                RowKey = "null",
                                                RGName = item,
                                                Perm = permission,
                                                SubscriptionID = subscriptionid
                        });
                    }

                    var query = configuredrgs.AsQueryable();
                    result.TotalRecords = query.Count();

                    if (options.GetLimitOffset().HasValue)
                    {
                        query = query.Skip(options.GetLimitOffset().Value).Take(options.GetLimitRowcount().Value);
                    }

                    result.Items = query.ToList();

                    return result;

                })
            );
            
        }
    }
}