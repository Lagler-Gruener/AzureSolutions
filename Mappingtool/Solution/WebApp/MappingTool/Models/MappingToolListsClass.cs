using Microsoft.Azure.Cosmos.Table;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace MappingTool.Models
{
    public class listrbacmapping : TableEntity
    {
        public string Mapping { get; set; }
        public string RBACID { get; set; }
        public string RBACPerm { get; set; }
        public string PermAssign { get; set; }
    }

    public class listrbacpermconfig : TableEntity
    {
        public string AADGroupID { get; set; }
        public string AADGroupName { get; set; }
        public string ADGroupDN { get; set; }
        public string ADGroupName { get; set; }
        public string ADGroupSID { get; set; }
        public string ADGroupuSNChanged { get; set; }
        public string AzureRG { get; set; }
        public string MarkedasDelete { get; set; }
        public string RBACPermID { get; set; }
        public string RBACPermName { get; set; }
        public string SubscriptionID { get; set; }
        public string Validatet { get; set; }
    }

    public class listazurerbacroles
    {
        public string RBACID { get; set; }

        public string RBACValue { get; set; }
    }

    public class listarchivconfig : TableEntity
    {
        public string BackupData { get; set; }
    }

    public class listsubscriptions : TableEntity
    {
        public string SubMapping { get; set; }
    }

    public class listmappingtoolconfig : TableEntity
    {
        public string AllowtoChange { get; set; }
        public string Name { get; set; }
        public string Value { get; set; }
        public string Description { get; set; }
    }

    public class listmessagequeue
    {
        public string Queue { get; set; }
        public string MsgCount { get; set; }

    }

    public class listrunnbookstate
    {
        public string RunnbookName { get; set; }
        public string CurrentState { get; set; }
        public string LastState { get; set; }
        public string FaildCount { get; set; }
        public string SuccessCount { get; set; }
    }

    public class listsrgnew
    {
        public IEnumerable<listrbacmapping> RbacConfig { get; set; }
        public IEnumerable<listsubscriptions> Subscriptions { get; set; }
        public IEnumerable<listazuretags> Tags { get; set; }
        public IEnumerable<listazurergs> RGs { get; set; }
        public IEnumerable<listazurergreqconfigs> RGDefConfigs { get; set; }
    }

    public class listexistrg : TableEntity
    {
        public string RGName { get; set; }
        public string Perm { get; set; }
        public string SubscriptionID { get; set; }
    }

    public class listazurergs
    {
        public string RGName { get; set; }
        public string RGRBACPermTagValue { get; set; }
        public string RGSubscription { get; set; }
    }

    public class listazuretags
    {
        public string TagName { get; set; }
        public string TagValue { get; set; }
    }

    public class listazurergreqconfigs
    {
        public string RGPrefix { get; set; }
    }

}