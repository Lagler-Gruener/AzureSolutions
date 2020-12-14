using module MappingToolLogA

enum ReturnCode
{
    Success = 0
    Warning = 1
    Error = 2
    Debug = 3
}

class ReturnMsg {
    [string]$ReturnCode
    [string]$ReturnMsg
    [string]$ReturnParameter1
    [string]$ReturnJsonParameters02
    [string]$LogMsg
}

#Get Functions

######################################################################
#
# Global functions
#
######################################################################

function Login-Azure()
{
    param (
        [parameter (Mandatory=$false)]
        [string] $SubscriptionID = "null"
    )

    $returnmsg = [ReturnMsg]::new()

    try 
    {
        $returnmsg.LogMsg = "Import required modules.`n"
        if(-not (Get-Module Az.Accounts)) {
            Import-Module Az.Accounts
        }
            
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Get Automation connection name $($global:HCAzConName).`n"
            $servicePrincipalConnection = Get-AutomationConnection -Name $global:HCAzConName 

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Create PSCredential.`n"
            $passwd = ConvertTo-SecureString $servicePrincipalConnection.Secret -AsPlainText -Force
            $pscredential = New-Object System.Management.Automation.PSCredential($servicePrincipalConnection.AplicationID, $passwd)      

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Connect to Azure.`n"                       
        if($SubscriptionID -ne "null")
        {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Select Subsctipin with ID: $SubscriptionID`n" 
            $connectazureresult = Connect-AzAccount -ServicePrincipal `
                                                    -TenantId  $servicePrincipalConnection.TenantId`
                                                    -Credential $pscredential `
                                                    -Subscription $SubscriptionID
            $returnmsg.ReturnParameter1 = (Get-AzContext).Tenant.Id
            
        }
        else {
            $connectazureresult = Connect-AzAccount -ServicePrincipal `
                                                    -TenantId  $servicePrincipalConnection.TenantId`
                                                    -Credential $pscredential                                                     
            $returnmsg.ReturnParameter1 = (Get-AzContext).Tenant.Id
        }

        $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Success
    }
    catch {

        $returnmsg.LogMsg = "Error in function Login-Azure. Error message: $($_.Exception.Message).`n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error
    }

    return $returnmsg
}

function Get-Variable-Assets-UnEnc
{        
    #Hardcoded variables
    $global:HCRGWebhook = "webhookrg"    
    $global:HCRGDelWebhook = "webhookrgdel"
    $global:HCAADWebhook = "webhookaad"
    $global:HCAADDelWebhook = "webhookaaddel"
    $global:HCAADCHWebhook = "webhookaadch"
    $global:HCAzConName = "MappingToolSP"  
    $global:HCAzLogACon = "MappingToolLogA"                                                                                                                                                      
    
    #Application configuration settings
        #Application On-Prem AD settings
        $global:ConfOUPathAADPerm = Get-AutomationVariable -Name "Conf-AD-OUPath-AADPerm"                                    
        $global:ConfOUPathRBACPerm = Get-AutomationVariable -Name "Conf-AD-OUPath-RBACPerm"   
        $global:ConfOUPathOldPerm = Get-AutomationVariable -Name "Conf-AD-OUPatch-OldPerm"
        $global:ConfMainADDC = Get-AutomationVariable -Name "Conf-AD-MainDC"
        $global:ConfAADPermissionWriteback = Get-AutomationVariable -Name "Conf-AAD-PermissionWriteback"
    
        
        $global:ConfAutoAcc = Get-AutomationVariable -Name "Conf-App-Automation-Account"
        $global:ConfLogAAcc = Get-AutomationVariable -Name "Conf-App-Loganalytics-WS"
        $global:ConfRGReqTag = Get-AutomationVariable -Name "Conf-App-RG-MainTag"
        $global:ConfApplRG = Get-AutomationVariable -Name "Conf-App-ResourceGroup"
        $global:ConfAppRGtoMon = Get-AutomationVariable -Name "Conf-App-RG-to-Monitor"
        $global:ConfApplStrAcc = Get-AutomationVariable -Name "Conf-App-StorageAccount"   
    
        #Application tables
        $global:ConfConfigurationTable = Get-AutomationVariable -Name "Conf-App-Configuration-Table"                    
        $global:ConfConfigurationTableBackup = Get-AutomationVariable -Name "Conf-App-Configuration-TableBak"                    
        $global:ConfPermMappingTable = Get-AutomationVariable -Name "Conf-App-Mapping-Table" 
        $global:ConfPermIssueTable = Get-AutomationVariable -Name "Conf-App-Config-Issues"       
        
        #Application queues        
        $global:ConfCloudMsgQueue = Get-AutomationVariable -Name "Conf-App-CL-Process-Msg-Queue"
        $global:ConfOnPremMsgQueue = Get-AutomationVariable -Name "Conf-App-OP-Process-Msg-Queue"
        $global:ConfMembershipMsgQueue = Get-AutomationVariable -Name "Conf-App-CL-MonMembership-Msg-Queue"    
        $global:ConfOnPremMonitorConfig = Get-AutomationVariable -Name "Conf-App-OP-MonConfig-Msg-Queue"
        $global:ConfCLMonitorConfig = Get-AutomationVariable -Name "Conf-App-CL-MonConfig-Msg-Queue"

    #Application naming standard settings
    $global:NSAADRBACPerm = Get-AutomationVariable -Name "NS-AAD-RBAC-Perm"                     
    $global:OnPremRBACRolePerm = Get-AutomationVariable -Name "NS-AD-OnPrem-RBAC-Perm" 
    $global:NSAADPerm = Get-AutomationVariable -Name "NS-AAD-Perm" 
    $global:OnPremAADRolePerm = Get-AutomationVariable -Name "NS-AD-OnPrem-Perm" 
    $global:ConfAADOldPermPrefix = Get-AutomationVariable -Name "Conf-AAD-OldPerm-Prefix"
    $global:ConfADOldPermPrefix = Get-AutomationVariable -Name "Conf-AD-OldPerm-Prefix"
}

function GenerateWorkflowGuid
{
    ([guid]::NewGuid()).Guid
}

######################################################################
#
# Azure Graph functions
#
######################################################################

function Check-is-user-synced()
{
    param (
        [parameter (Mandatory=$true)]
        [string] $upn,
        [parameter (Mandatory=$true)]
        [string] $AADTenantID
    )
    
    $returnmsg = [ReturnMsg]::new()

    try {

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Get Automation connection name $($global:HCAzConName).`n"
        $servicePrincipalConnection = Get-AutomationConnection -Name $global:HCAzConName 

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Define AppIdURI, authority and redirecturi `n"
            $resourceAppIdURI = "https://graph.microsoft.com"
            $authority = "https://login.microsoftonline.com/$AADTenantID"
            $redirectUri = "urn:ietf:wg:oauth:2.0:oob" 

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Generate oauth token `n"
            $body = @{grant_type="client_credentials";`
                     resource=$resourceAppIdURI;`
                     client_id=$servicePrincipalConnection.AplicationID;`
                     client_secret=$servicePrincipalConnection.Secret}

            $oauth = Invoke-RestMethod -Method Post -Uri $authority/oauth2/token?api-version=1.0 `
                                       -Body $body -UseBasicParsing

            if($oauth.access_token)
            {
                $returnmsg.LogMsg = $returnmsg.LogMsg + "done `n"

                $token = @{
                        'Content-Type'='application/json'
                        'Authorization'="Bearer " + $oauth.access_token
                        'ExpiresOn'= $oauth.expires_on
                }

                $url = 'https://graph.microsoft.com/beta/users?&$filter=userPrincipalName+eq+''{0}''&$select=id,onPremisesSyncEnabled,userPrincipalName,givenName,surname,displayName,onPremisesSecurityIdentifier' -f $upn
                $returnmsg.LogMsg = $returnmsg.LogMsg + "$url `n"

                $returnmsg.LogMsg = $returnmsg.LogMsg + "Invoke WebRequest to get user information `n"
                $myReport = (Invoke-WebRequest -Method Get -Headers @{Authorization = $token.Authorization} -Uri $url -UseBasicParsing)

                $userdata = ($myReport | ConvertFrom-Json).value

                if($userdata.onPremisesSyncEnabled -eq "true")
                {
                    $returnmsg.LogMsg = $returnmsg.LogMsg + "User is a synced user `n"

                    $returnmsg.ReturnParameter1 = "true"
                    $returnmsg.ReturnJsonParameters02 = ($userdata | ConvertTo-Json)
                    $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
                    $returnmsg.ReturnMsg = [ReturnCode]::Success 
                }
                else {
                    $returnmsg.LogMsg = $returnmsg.LogMsg + "User isn't a synced user `n"

                    $returnmsg.ReturnParameter1 = "false"
                    $returnmsg.ReturnJsonParameters02 = ($userdata | ConvertTo-Json)
                    $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
                    $returnmsg.ReturnMsg = [ReturnCode]::Success 
                }
            }
            else 
            {
                $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in function Check-is-user-synced. Error message: Authorization Access Token is null `n"
                $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
                $returnmsg.ReturnMsg = [ReturnCode]::Error 
            }
    }
    catch {

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in function Check-is-user-synced. Error message: $($_.Exception.Message) `n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error  
    }    

    return $returnmsg
}

function Rename-AADGroup()
{
    param (
        [parameter (Mandatory=$true)]
        [string] $AADGroup,
        [parameter (Mandatory=$true)]
        [string] $AADGroupID,
        [parameter (Mandatory=$true)]
        [string] $AADTenantID
    )

    try {

        $returnmsg = [ReturnMsg]::new()

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Get Automation connection name $($global:HCAzConName).`n"
            $servicePrincipalConnection = Get-AutomationConnection -Name $global:HCAzConName 

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Define AppIdURI, authority and redirecturi `n"
            $resourceAppIdURI = "https://graph.microsoft.com"
            $authority = "https://login.microsoftonline.com/$AADTenantID"
            $redirectUri = "urn:ietf:wg:oauth:2.0:oob" 

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Generate oauth token `n"
            $body = @{grant_type="client_credentials";`
                     resource=$resourceAppIdURI;`
                     client_id="3f97610b-da2d-4dcd-aea3-075666ce5800";`
                     client_secret="hB-yvRL1r93n6H4.Rq8Ezp~__ML4GPYy-7"}

            $oauth = Invoke-RestMethod -Method Post -Uri $authority/oauth2/token?api-version=1.0 `
                                       -Body $body -UseBasicParsing

            if($oauth.access_token)
            {
                $returnmsg.LogMsg = $returnmsg.LogMsg + "done `n"

                $token = @{
                        'Content-Type'='application/json'
                        'Authorization'="Bearer " + $oauth.access_token
                        'ExpiresOn'= $oauth.expires_on
                }

                $returnmsg.LogMsg = $returnmsg.LogMsg + "Rename group $($AADGroup) to $($global:ConfAADOldPermPrefix)$($AADGroup)$($defaultsuffix) `n"
                $defaultsuffix = $(Get-Date).ToFileTime()
                $body = @{
                        'description'="Renamed Group by AppMappingTool";
                        'displayName'="$($global:ConfAADOldPermPrefix)$($AADGroup)$($defaultsuffix)"
                        } | ConvertTo-Json

                $url = 'https://graph.microsoft.com/v1.0/groups/{0}' -f $AADGroupID
                $returnmsg.LogMsg = $returnmsg.LogMsg + "$url `n"

                $returnmsg.LogMsg = $returnmsg.LogMsg + "Invoke WebRequest to rename Azure AD group `n"

                $myresult = (Invoke-WebRequest -Method Patch `
                                               -Headers @{Authorization = $token.Authorization} `
                                               -Uri $url `
                                               -UseBasicParsing `
                                               -Body $body `
                                               -ContentType "application/json")                                                  

                $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
                $returnmsg.ReturnMsg = [ReturnCode]::Success
            }
            else 
            {                
                $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in function Rename-AADGroup. Error message: Authorization Access Token is null `n"
                $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
                $returnmsg.ReturnMsg = [ReturnCode]::Error 
            }
    }
    catch {

        if($_.Exception.Response.StatusCode -eq "NotFound")
        {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Warning in function Rename-AADGroup. Warning message: $($_.Exception.Message) `n"
            $returnmsg.ReturnCode = [ReturnCode]::Warning.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Warning  
        }
        else {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in function Rename-AADGroup. Error message: $($_.Exception.Message) `n"
            $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Error     
        }        
    }    

    return $returnmsg

}

######################################################################
#
# On-Prem AD functions
#
######################################################################

function Create-AD-Group
{
    param (
        [parameter (Mandatory=$true)]
        [string] $GroupName,
        [parameter (Mandatory=$true)]
        [string] $SamAccountName,
        [parameter (Mandatory=$true)]
        [string] $DisplayName,        
        [parameter (Mandatory=$true)]
        [string] $GroupCategory,
        [parameter (Mandatory=$true)]
        [string] $GroupScope,
        [parameter (Mandatory=$true)]
        [string] $OUPath,
        [parameter (Mandatory=$true)]
        [string] $Description,
        [parameter (Mandatory=$true)]
        [ValidateSet('RG','AAD')]
        [string] $RequestType
    )

    $returnmsg = [ReturnMsg]::new()
    try {

        if(Get-ADGroup -Filter {cn -eq $GroupName})
        {            
            $returnmsg.LogMsg = "Active Directory Group $GroupName already exist. `n"
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Please check the On-Prem group and Fix the issue! `n"
            $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Error 
        }
        else {

            $returnmsg.LogMsg = "Create new Active Directory group: $GroupName `n"
               $rcad = New-ADGroup -Name $GroupName.ToLower() `
                                   -SamAccountName $SamAccountName.ToLower() `
                                   -GroupCategory $GroupCategory `
                                   -GroupScope $GroupScope `
                                   -DisplayName $DisplayName.ToLower() `
                                   -Path $OUPath `
                                   -Description $Description

            $returnmsg.LogMsg = $returnmsg.LogMsg + "Get SID from created Active Directory group `n"
                $sid = (Get-ADGroup -Identity $GroupName).SID.Value
            
            $returnmsg.LogMsg = $returnmsg.LogMsg + "SID: $sid `n"

            #Update Azure Storage Table
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Get Azure configuration row `n"
                $configtable = Get-AzTableTable -TableName $ConfConfigurationTable -resourceGroup $ConfApplRG `
                                                -storageAccountName $ConfApplStrAcc
                
                if($RequestType -eq "RG")
                {
                    [string]$filterPT = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("PartitionKey",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,"RBACPerm")
                    [string]$filterGN = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("ADGroupName",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,$GroupName.ToLower())
                    [string]$finalFilter = [Microsoft.Azure.Cosmos.Table.TableQuery]::CombineFilters($filterPT,"and",$filterGN)        

                    $newadgroupconfig = Get-AzTableRow -table $configtable -CustomFilter $finalFilter
                }
                elseif($RequestType -eq "AAD") {
                    [string]$filterPT = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("PartitionKey",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,"AADPerm")
                    [string]$filterGN = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("ADGroupName",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,$GroupName.ToLower())
                    [string]$finalFilter = [Microsoft.Azure.Cosmos.Table.TableQuery]::CombineFilters($filterPT,"and",$filterGN) 

                    $newadgroupconfig = Get-AzTableRow -table $configtable -CustomFilter $finalFilter
                }

            $returnmsg.LogMsg = $returnmsg.LogMsg + "Row information $newadgroupconfig `n"
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Update Azure configuration row `n"
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Add new SID to row `n"
                $newadgroupconfig.ADGroupSID = $sid
                $newadgroupconfig.ADGroupDN = "cn=$($GroupName.ToLower()),$($OUPath.ToLower())"
                if($newadgroupconfig.Validatet -eq "open")
                {
                    $returnmsg.LogMsg = $returnmsg.LogMsg + "Change validation state to true `n"
                    $newadgroupconfig.Validatet = "true"
                }
                
                $rupdrow = $newadgroupconfig | Update-AzTableRow -Table $configtable

            $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Success 
        }           

    }
    catch {

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in function Create-AD-Group. Error message: $($_.Exception.Message) `n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error 

    }    

    return $returnmsg
}

function Move-AD-Group
{
    param (
        [parameter (Mandatory=$true)]
        [string] $GroupName,
        [parameter (Mandatory=$true)]
        [string] $OUPath,
        [parameter (Mandatory=$true)]
        [string] $Description
    )

    $returnmsg = [ReturnMsg]::new()
    try {

        if(Get-ADGroup -Filter {cn -eq $GroupName})
        {            
            $returnmsg.LogMsg = "Active Directory Group $GroupName exist. `n"
            
            $grp = Get-ADGroup -Filter {cn -eq $GroupName}

            if($grp.DistinguishedName -eq $OUPath)
            {
                $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
                $returnmsg.ReturnMsg = [ReturnCode]::Success 
            }
            else {
                $returnmsg.LogMsg = $returnmsg.LogMsg + "Group already moved to another OU. Move the group to the right OU. `n"
                $returnmsg.ReturnCode = [ReturnCode]::Warning.Value__
                $returnmsg.ReturnMsg = [ReturnCode]::Warning 
            }

            $defaultsuffix = $(Get-Date).ToFileTime()

            $newgroupname = "$($global:ConfADOldPermPrefix)$($GroupName)$($defaultsuffix)"
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Rename AD group to $($global:ConfADOldPermPrefix)$($GroupName)$($defaultsuffix) `n"
            $renameobj = Rename-ADObject -Identity $OUPath -NewName $newgroupname

            $returnmsg.LogMsg = $returnmsg.LogMsg + "Get path from renamed AD group: $newgroupname `n"
            $grprenamed = Get-ADGroup -Filter {cn -eq $newgroupname}

            $returnmsg.LogMsg = $returnmsg.LogMsg + "Change description and other informations for AD group: $($global:ConfADOldPermPrefix)$($GroupName) `n"
            $newdescription = Set-ADGroup -Identity $grprenamed.DistinguishedName -Description $Description -displayName $newgroupname -SamAccountName $newgroupname

            $returnmsg.LogMsg = $returnmsg.LogMsg + "Move AD group to the target location $($global:ConfOUPathOldPerm) `n"
            $move = Move-ADObject -Identity $grprenamed.DistinguishedName -TargetPath $global:ConfOUPathOldPerm
        }
        else {

            

            $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Success 
        }           

    }
    catch {

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in function Move-AD-Group. Error message: $($_.Exception.Message) `n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error 

    }    

    return $returnmsg
}

######################################################################
#
# Azure AD functions
#
######################################################################

function Create-AADGroup()
{
    param (
        [parameter (Mandatory=$true)]
        [string] $AADGroup
    )

    $returnmsg = [ReturnMsg]::new()

    try
    {
        $returnmsg.LogMsg = "Check AADGroup name value. `n"

        if($null -eq (Get-AzADGroup -DisplayName $AADGroup))
        {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Create AAD Group $AADGroup `n"
                $newgrp = New-AzADGroup -DisplayName $AADGroup.ToLower() -MailNickname $AADGroup.ToLower()

            $returnmsg.ReturnParameter1 = $newgrp.Id
            $returnmsg.LogMsg = $returnmsg.LogMsg + "AAD Group successfully created `n"

            $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Success
        }
        else 
        {
            $returnmsg.ReturnParameter1 = (Get-AzADGroup -DisplayName $AADGroup).Id
            $returnmsg.LogMsg = $returnmsg.LogMsg + "AAD group already exist. `n"
            $returnmsg.ReturnCode = [ReturnCode]::Warning.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Warning
        }
    }
    catch
    {
        $returnmsg.LogMsg = "Error in section Create-AADGroup. Error message: $($_.Exception.Message) `n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error
    }

    return $returnmsg

}

######################################################################
#
# Queue functions
#
######################################################################

function Add-Msg-to-Queue()
{   
    param (
        [parameter (Mandatory=$true)]
        [string] $QueueName,
        [parameter (Mandatory=$false)]
        [string] $WorkflowID = "null",
        [parameter (Mandatory=$true)]
        [ValidateSet('RG','AAD',"RG-Rem","AAD-Rem", "AD-Rem")]
        [string] $RequestType,
        [parameter (Mandatory=$true)]
        [string] $ADGroupName,
        [parameter (Mandatory=$false)]
        [string] $ADOUPath = "null",
        [parameter (Mandatory=$false)]
        [string] $ADGroupSID = "null",
        [parameter (Mandatory=$false)]
        [string] $ADGroupDesc = "null",
        [parameter (Mandatory=$true)]
        [string] $AADGroupName,
        [parameter (Mandatory=$false)]
        [string] $AADGroupID = "null",
        [parameter (Mandatory=$false)]
        [string] $AADRoleID = "null",
        [parameter (Mandatory=$false)]
        [string] $AzureRG = "null",
        [parameter (Mandatory=$false)]
        [string] $SubscriptionID = "null",
        [parameter (Mandatory=$false)]
        [string] $PartitionKey = "null"        

    )

    $returnmsg = [ReturnMsg]::new()

    try 
    {
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Get Storage Account Queue `n"
            $queue = Get-AzStorageQueue –Name $QueueName –Context $ctx

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Create JSON Msg for storage queue `n"
            $jsonmsg = @{
                        "WorkflowID" = $WorkflowID
                        "Type" = $RequestType
                        "AADGroupName" = $AADGroupName.ToLower()
                        "AADGroupID" = $AADGroupID
                        "AzureRG" = $AzureRG
                        "SubscriptionID" = $SubscriptionID
                        "ADGroupName" = $ADGroupName.ToLower()
                        "ADSID" = $ADGroupSID
                        "ADOUPath" = $ADOUPath
                        "ADGroupDesc" = $ADGroupDesc
                        "State" = "1"
                        "PartitionKey" = $PartitionKey
                    } | ConvertTo-Json      
        
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Message: $jsonmsg `n"

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Create Message Queue object `n"
            $queueMessage = New-Object -TypeName "Microsoft.Azure.Storage.Queue.CloudQueueMessage,$($queue.CloudQueue.GetType().Assembly.FullName)" `
                                       -ArgumentList $jsonmsg
        
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Add Message to Queue `n"        
            $addmsg = $queue.CloudQueue.AddMessage($QueueMessage)

        $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Success     
    }
    catch {
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in function Add-Msg-to-On-Prem-Queue. Error message: $($_.Exception.Message) `n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error     
    }

    return $returnmsg
}

function Add-Msg-to-MembershipQueue()
{   
    param (
        [parameter (Mandatory=$true)]
        [string] $QueueName,
        [parameter (Mandatory=$false)]
        [string] $WorkflowID = "null",
        [parameter (Mandatory=$true)]
        $QueueMessage        
    )

    $returnmsg = [ReturnMsg]::new()

    try 
    {
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Get Storage Account Queue `n"
            $queue = Get-AzStorageQueue –Name $QueueName –Context $ctx  
        
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Message: $QueueMessage `n"

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Create Message Queue object `n"
            $queueMessage = New-Object -TypeName "Microsoft.Azure.Storage.Queue.CloudQueueMessage,$($queue.CloudQueue.GetType().Assembly.FullName)" `
                                       -ArgumentList $QueueMessage
        
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Add Message to Queue `n"        
            $addmsg = $queue.CloudQueue.AddMessage($QueueMessage)

        $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Success     
    }
    catch {
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in function Add-Msg-to-MembershipQueue. Error message: $($_.Exception.Message) `n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error     
    }

    return $returnmsg
}

function Check-Msg-from-Queue()
{
    param (
        [parameter (Mandatory=$true)]
        [string] $QueueName
    )
    
    $returnmsg = [ReturnMsg]::new()

    try {

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Get Storage Account Queue `n"
            $queue = Get-AzStorageQueue –Name $QueueName –Context $ctx  
        
        if((Get-AzStorageQueue –Name $QueueName –Context $ctx).ApproximateMessageCount -gt 0)
        {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Message Count is greater then 0, execute action task `n"
            
            $returnmsg.ReturnParameter1 = "1"
            $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Success 
        }   
        else {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Message Count is 0. `n"
            
            $returnmsg.ReturnParameter1 = "0"
            $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Success 
        }

    }
    catch {

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in function Get-Msg-from-Queue. Error message: $($_.Exception.Message) `n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error  
    }    

    return $returnmsg
}

######################################################################
#
# Table functions
#
######################################################################

function Get-RBAC-Mapping()
{
    param (
        [parameter (Mandatory=$true)]
        [string] $MappingTableName,
        [parameter (Mandatory=$true)]
        [string] $ConfigTableName,
        [parameter (Mandatory=$true)]
        [string] $mappingvalue,
        [parameter (Mandatory=$true)]
        [string] $RGName,
        [parameter (Mandatory=$true)]
        [ValidateSet('RG','AAD')]
        [string] $RequestType,
        [parameter (Mandatory=$true)]
        [string] $SubscriptionID
    )

    $returnmsg = [ReturnMsg]::new()

    try 
    {
        $returnmsg.LogMsg = "Get Azure Table $MappingTableName in ResourceGroup $($global:ConfApplRG) bind to the Storage Account $($global:ConfApplStrAcc) `n"        
            $ConfPermMappingTable = Get-AzTableTable -TableName $MappingTableName -resourceGroup $($global:ConfApplRG) `
                                                     -storageAccountName $($global:ConfApplStrAcc)

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Get Azure Table Row filtered by the ColumnName Mapping with the Value $($mappingvalue.ToLower())  and PartitionKey RBAC `n"
            $mappingresult = Get-AzTableRow -Table $ConfPermMappingTable -ColumnName Mapping `
                                            -Value $mappingvalue.ToLower() -Operator Equal 

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Get Azure Table Row filtered by the ColumnName RowKey with the Value $SubscriptionID and PartitionKey SUB `n"
            $submappingresult = Get-AzTableRow -Table $ConfPermMappingTable -PartitionKey "SUB" -RowKey $SubscriptionID
                                            
            if($null -eq $mappingresult)
            {
                $mappingresult = Get-AzTableRow -Table $ConfPermMappingTable -ColumnName Mapping `
                                                -Value $mappingvalue.ToUpper() -Operator Equal 
            }
        
        if($null -ne $submappingresult)
        {
            if($null -eq $mappingresult)
            {
                $returnmsg.LogMsg = $returnmsg.LogMsg + "Return Mapping Result null `n"
                    $jsonmsg = @{
                                "State"= "null"
                                "MappingRBACPerm" = "null"
                                "MappringRBACShortName" = "null"
                                "AADGroupName" = "null"
                                "ADGroupName" = "null"
                                "ADGroupSID" = "null"
                                "RoleID" = "null"
                                "actiontype" = "null"
                                "SubscriptionID" = $SubscriptionID
                            } | ConvertTo-Json

                $returnmsg.ReturnJsonParameters02 = $jsonmsg
            }
            else
            {                
                $returnmsg.LogMsg = $returnmsg.LogMsg + "Get Azure Table $ConfigTableName in ResourceGroup $($global:ConfApplRG) bind to the Storage Account $($global:ConfApplStrAcc), to check if configuration always exist`n"  
                
                if($RequestType -eq "RG")
                {
                    $aadgroupname = ("$($global:NSAADRBACPerm)$($submappingresult.SubMapping)-$($RGName)-$($mappingresult.Mapping)").ToLower()
                    $adgroupname = ("$($global:OnPremRBACRolePerm)$($submappingresult.SubMapping)-$($RGName)-$($mappingresult.Mapping)").ToLower()
                }elseif ($RequestType -eq "AAD") {
                    $aadgroupname = ("$($global:NSAADPerm)$($RGName)-$($mappingresult.Mapping)").ToLower()
                    $adgroupname = ("$($global:OnPremAADRolePerm)$($RGName)-$($mappingresult.Mapping)").ToLower()
                }
                
                    $configtable = Get-AzTableTable -TableName $ConfigTableName -resourceGroup $($global:ConfApplRG) `
                                                    -storageAccountName $($global:ConfApplStrAcc)
                                                            
                    [string]$filterRBACPerm = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("RBACPermID",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,$mappingresult.RBACID)
                    [string]$filterResourceGroup = [Microsoft.Azure.Cosmos.Table.TableQuery]::GenerateFilterCondition("RowKey",[Microsoft.Azure.Cosmos.Table.QueryComparisons]::Equal,$aadgroupname.ToLower())
                    [string]$finalFilter = [Microsoft.Azure.Cosmos.Table.TableQuery]::CombineFilters($filterRBACPerm,"and",$filterResourceGroup)

                $returnmsg.LogMsg = $returnmsg.LogMsg + "Get Table row filterd by $finalFilter`n"
                    $appconfigresult = Get-AzTableRow -table $configtable -customFilter $finalFilter

                if($null -eq $appconfigresult)
                {
                    $returnmsg.LogMsg = $returnmsg.LogMsg + "Return Mapping Result create`n"
                        $jsonmsg = @{
                                    "State"= "create"
                                    "MappingRBACPerm" = $mappingresult.RBACPerm
                                    "MappringRBACShortName" = $mappingresult.Mapping
                                    "AADGroupName" = $aadgroupname.ToLower()
                                    "ADGroupName" = $adgroupname.ToLower()
                                    "ADGroupSID" = "null"
                                    "actiontype" = "create"
                                    "RoleID" = $mappingresult.RBACID
                                    "SubscriptionID" = $SubscriptionID
                                } | ConvertTo-Json

                    $returnmsg.ReturnJsonParameters02 = $jsonmsg
                }
                else
                {
                    $returnmsg.LogMsg = $returnmsg.LogMsg + "Return Mapping Result exist`n"
                        $jsonmsg = @{
                                    "State"= "exist"
                                    "MappingRBACPerm" = $mappingresult.RBACPerm
                                    "MappringRBACShortName" = $mappingresult.Mapping
                                    "AADGroupName" = $aadgroupname.ToLower()
                                    "ADGroupName" = $aadgroupname.ToLower()
                                    "ADGroupSID" = "null"
                                    "actiontype" = "exist"
                                    "RoleID" = $mappingresult.RBACID
                                    "SubscriptionID" = $SubscriptionID
                                } | ConvertTo-Json

                    $returnmsg.ReturnJsonParameters02 = $jsonmsg       
                }
            }
        }
        else {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Return Subscription Mapping Result is null `n"
                    $jsonmsg = @{
                                "State"= "null"
                                "MappingRBACPerm" = "null"
                                "MappringRBACShortName" = "null"
                                "AADGroupName" = "null"
                                "ADGroupName" = "null"
                                "ADGroupSID" = "null"
                                "RoleID" = "null"
                                "actiontype" = "null"
                                "SubscriptionID" = "null"
                            } | ConvertTo-Json

                $returnmsg.ReturnJsonParameters02 = $jsonmsg

            $returnmsg.ReturnCode = [ReturnCode]::Warning.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Warning

            return $returnmsg
        }

        $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Success

        return $returnmsg
    }
    catch{

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in function Get-RBAC-Mapping. Error message: $($_.Exception.Message)`n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error     
        
        return $returnmsg
    }
}

function Update-RBAC-Removed()
{
    param (
        [string[]] $arrtags,
        [string]$rgname
        
    )    

    $returnmsg = [ReturnMsg]::new()

    try {

        $returnmsg.LogMsg = "Get all rows from configuration table. `n"

        $tableconfig = Get-Info-from-Config-Table -TableRowKey "*" `
                                                  -TablePartitionKey "RBACPerm" `
                                                  -TableName $($global:ConfConfigurationTable)        

        if($tableconfig.ReturnMsg -eq [ReturnCode]::Success)
        {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Done `n"
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Find relevant rows based on filter: AzureRG = $($rgname.ToLower())"
            $aadconfig = ($tableconfig.ReturnJsonParameters02 | ConvertFrom-Json) | where {$_.AzureRG.ToLower() -eq $rgname.ToLower()}

            $returnmsg.LogMsg = $returnmsg.LogMsg + "Check configuration"
            $removeresarr = @()
            foreach($aadconfitem in $aadconfig)
            {
                $table = Get-AzTableTable -TableName $($global:ConfPermMappingTable) `
                                          -resourceGroup $($global:ConfApplRG) `
                                          -storageAccountName $($global:ConfApplStrAcc)  

                $permid = $aadconfitem.RBACPermID
                $mappingresult = Get-AzTableRow -Table $table `
                                                -ColumnName RBACID `
                                                -Value $permid -Operator Equal 

                if(!$arrtags.Contains($mappingresult.Mapping.ToLower()))
                {
                    $removeresarr = $removeresarr + $mappingresult.Mapping
                    $returnmsg.LogMsg = $returnmsg.LogMsg + "Warning permission $($aadconfitem.AADGroupName) with tag ID: $($mappingresult.Mapping) was removed from resourcegroup $($aadconfitem.AzureRG) `n"
                    $returnmsg.LogMsg = $returnmsg.LogMsg + "Update permission with flag 'MarkedasDelete' = 1 `n"
                                                           
                    $updateresultValidated = Update-Table-Entry -TableName $($global:ConfConfigurationTable)  `
                                                                -TablePartitionKey $aadconfitem.PartitionKey `
                                                                -TableRowKey $aadconfitem.RowKey `
                                                                -RowKeytoChange "MarkedasDelete" `
                                                                -RowValuetoChange "1"
                    if($updateresultValidated.ReturnMsg -eq [ReturnCode]::Success)
                    {
                        $returnmsg.LogMsg = $returnmsg.LogMsg + "Done `n"
                    }
                    else {                        
                        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in Function Update-Table-Entry. Error: $($updateresultValidated.LogMsg)"
                        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
                        $returnmsg.ReturnMsg = [ReturnCode]::Error
                    }
                }  
                else {
                    $updateresultValidated = Update-Table-Entry -TableName $($global:ConfConfigurationTable)  `
                                                                -TablePartitionKey $aadconfitem.PartitionKey `
                                                                -TableRowKey $aadconfitem.RowKey `
                                                                -RowKeytoChange "MarkedasDelete" `
                                                                -RowValuetoChange "0"
                }                         
            }

            $returnmsg.ReturnJsonParameters02 = $removeresarr | ConvertTo-Json
            $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Success
        }
        else {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in Function Get-Info-from-Config-Table. Error: $($loginazureresult.LogMsg)"
            $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Error
        }
    }    
    catch {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in section Update-Table-Entry. Error message: $($_.Exception.Message) `n"
            $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Error
        }    

    return $returnmsg
}

function Update-Table-Entry
{
    param (        
        [parameter (Mandatory=$true)]
        [string] $TableName,
        [parameter (Mandatory=$false)]
        [string] $TableRowKey = "none",
        [parameter (Mandatory=$false)]
        [string] $TablePartitionKey = "none",
        [parameter (Mandatory=$false)]
        [string] $CustomFilter = "none",
        [parameter (Mandatory=$true)]
        [string] $RowKeytoChange,
        [parameter (Mandatory=$true)]
        [string] $RowValuetoChange
    )

    $returnmsg = [ReturnMsg]::new()

    try {            
        $returnmsg.LogMsg = "Get Azure Table $TableName in RG $($global:ConfApplRG) bin at Storage Account $($global:ConfApplStrAcc) `n"
        $configtable = Get-AzTableTable -TableName $TableName -resourceGroup $($global:ConfApplRG) `
                                        -storageAccountName $($global:ConfApplStrAcc)

        if(($TableRowKey -ne "none") -and ($TablePartitionKey -ne "none"))
        {
            $tablerow = Get-AzTableRow -table $configtable -PartitionKey $TablePartitionKey -RowKey $TableRowKey

            if($null -ne $tablerow)
            {
                $returnmsg.LogMsg = $returnmsg.LogMsg + "Tablerow found by filter PartitionKey $TablePartitionKey and Rowkey $TableRowKey `n"

                $returnmsg.LogMsg = $returnmsg.LogMsg + "Update RowKey $RowKeytoChange from value $($tablerow.$RowKeytoChange) to $RowValuetoChange `n"

                $tablerow.$RowKeytoChange = $RowValuetoChange

                $rupdrow = $tablerow | Update-AzTableRow -Table $configtable 

                if($null -ne $rupdrow)
                {
                    $returnmsg.LogMsg = $returnmsg.LogMsg + "Success `n"
                    $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
                    $returnmsg.ReturnMsg = [ReturnCode]::Success
                }
                else {
                    $returnmsg.LogMsg = $returnmsg.LogMsg + "Warning row value cannot be updated `n"
                    $returnmsg.ReturnCode = [ReturnCode]::Warning.Value__
                    $returnmsg.ReturnMsg = [ReturnCode]::Warning
                }
            }
        }
        elseif ($CustomFilter -ne "none") {
            $tablerow = Get-AzTableRow -table $configtable -CustomFilter $CustomFilter

            if($null -ne $tablerow)
            {
                $returnmsg.LogMsg = $returnmsg.LogMsg + "Tablerow found by custom filter $CustomFilter `n"

                $returnmsg.LogMsg = $returnmsg.LogMsg + "Update RowKey $RowKeytoChange from value $($tablerow.$RowKeytoChange) to $RowValuetoChange `n"

                $tablerow.$RowKeytoChange = $RowValuetoChange

                $rupdrow = $tablerow | Update-AzTableRow -Table $configtable 

                if($null -ne $rupdrow)
                {
                    $returnmsg.LogMsg = $returnmsg.LogMsg + "Success `n"
                    $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
                    $returnmsg.ReturnMsg = [ReturnCode]::Success
                }
                else {
                    $returnmsg.LogMsg = $returnmsg.LogMsg + "Warning row value cannot be updated `n"
                    $returnmsg.ReturnCode = [ReturnCode]::Warning.Value__
                    $returnmsg.ReturnMsg = [ReturnCode]::Warning
                }
            }
        }
        else {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in section Update-Table-Entry. Error message: No RowKey and PartitionKey or CustomFilter defined `n"
            $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Error
        }
    }
    catch {
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in section Update-Table-Entry. Error message: $($_.Exception.Message) `n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error
    }

    return $returnmsg
}

function Add-Info-to-Config-Table()
{
    param (
        [parameter (Mandatory=$true)]
        [string] $TableName,
        [parameter (Mandatory=$true)]
        [string] $AADGroupName,
        [parameter (Mandatory=$true)]
        [string] $AADGroupID,
        [parameter (Mandatory=$false)]
        [string] $RBACPermName="null",
        [parameter (Mandatory=$false)]
        [string] $RBACPermID="null",
        [parameter (Mandatory=$true)]
        [string] $ADGroupName,
        [parameter (Mandatory=$false)]
        [string] $ADGroupSID = "null",
        [parameter (Mandatory=$false)]
        [string] $ADGroupDN = "null",
        [parameter (Mandatory=$false)]
        [string] $AZRG = "null",        
        [parameter (Mandatory=$true)]
        [string] $TablePartitionKey,
        [parameter (Mandatory=$false)]
        [string] $Validated = "open",
        [parameter (Mandatory=$false)]
        [string] $SubscriptionID = "null"
    )

    $returnmsg = [ReturnMsg]::new()

    try
    {
        $returnmsg.LogMsg = "Get Azure Table $TableName in RG $($global:ConfApplRG) bin at Storage Account $($global:ConfApplStrAcc) `n"
            $table = Get-AzTableTable -TableName $TableName -resourceGroup $($global:ConfApplRG) `
                                      -storageAccountName $($global:ConfApplStrAcc)

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Add new Table Row `n"
            $resultaddtableinfo = Add-AzTableRow -table $table `
                                                 -partitionKey $TablePartitionKey `
                                                 -rowKey ($AADGroupName) -property @{"AADGroupName"=$AADGroupName.ToLower();`
                                                                                     "AADGroupID"=$AADGroupID;`
                                                                                     "RBACPermName"=$RBACPermName.ToLower();`
                                                                                     "RBACPermID"=$RBACPermID;`
                                                                                     "ADGroupName"=$ADGroupName.ToLower();`
                                                                                     "ADGroupSID"=$ADGroupSID; `
                                                                                     "ADGroupDN"=$ADGroupDN.ToLower(); `
                                                                                     "ADGroupuSNChanged"= "0"; `
                                                                                     "AzureRG"=$AZRG; `
                                                                                     "Validatet"=$Validated; `
                                                                                     "SubscriptionID" = $SubscriptionID;
                                                                                     "MarkedasDelete" = "0"}

        $returnmsg.ReturnJsonParameters02 = $resultaddtableinfo
        $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Success
    }
    catch
    {
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in section Add-Info-to-Table. Error message: $($_.Exception.Message) `n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error
    }

    return $returnmsg
}

function Add-Info-to-ConfigBackup-Table()
{
    param (
        [parameter (Mandatory=$true)]
        [string] $TablePartitionKey,
        [parameter (Mandatory=$true)]
        [string] $TableRowKey,
        [parameter (Mandatory=$true)]
        [string] $BackupData,
        [parameter (Mandatory=$true)]
        [string] $TableName      
    )

    $returnmsg = [ReturnMsg]::new()

    try
    {
        $returnmsg.LogMsg = "Get Azure Table $TableName in RG $($global:ConfApplRG) bin at Storage Account $($global:ConfApplStrAcc) `n"
            $table = Get-AzTableTable -TableName $TableName -resourceGroup $($global:ConfApplRG) `
                                      -storageAccountName $($global:ConfApplStrAcc)

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Add new Backup Row to Table `n"
            $resultaddtableinfo = Add-AzTableRow -table $table `
                                                 -partitionKey $TablePartitionKey `
                                                 -rowKey $TableRowKey `
                                                 -property @{"BackupData"=$BackupData}

        $returnmsg.ReturnJsonParameters02 = $resultaddtableinfo
        $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Success
    }
    catch
    {
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in section Add-Info-to-ConfigBackup-Table. Error message: $($_.Exception.Message) `n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error
    }

    return $returnmsg
}

function Add-Info-to-ConfigIssue-Table()
{
    param (
        [parameter (Mandatory=$true)]
        [string] $TablePartitionKey,
        [parameter (Mandatory=$true)]
        [string] $TableRowKey,
        [parameter (Mandatory=$true)]
        [ValidateSet('AD-Del','AD-Mv','AAD-Del')]
        [string] $IssueType,
        [parameter (Mandatory=$true)]
        [string] $IssueMsg,
        [parameter (Mandatory=$true)]
        [string] $TableName      
    )

    $returnmsg = [ReturnMsg]::new()

    try
    {
        $returnmsg.LogMsg = "Get Azure Table $TableName in RG $($global:ConfApplRG) at Storage Account $($global:ConfApplStrAcc) `n"
            $table = Get-AzTableTable -TableName $TableName -resourceGroup $($global:ConfApplRG) `
                                      -storageAccountName $($global:ConfApplStrAcc)

        $returnmsg.LogMsg = "Check if entry always exist `n"
        $keyresult = Get-AzTableRow -Table $table -PartitionKey $TablePartitionKey -RowKey $TableRowKey

        if($null -ne $keyresult)
        {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Update issue in table `n"
            $keyresult.IssueType = $IssueType
            $keyresult.IssueMsg = $IssueMsg

            $updateresult = $keyresult | Update-AzTableRow -table $table

        }
        else {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Add new issue to table `n"
            $resultaddtableinfo = Add-AzTableRow -table $table `
                                                 -partitionKey $TablePartitionKey `
                                                 -rowKey $TableRowKey `
                                                 -property @{"IssueType"=$IssueType;`
                                                             "IssueMsg"=$IssueMsg}
            
        }

        $returnmsg.ReturnJsonParameters02 = $resultaddtableinfo
        $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Success
    }
    catch
    {
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in section Add-Info-to-ConfigBackup-Table. Error message: $($_.Exception.Message) `n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error
    }

    return $returnmsg
}

function Remove-Info-from-Config-Table()
{
    param (
        [parameter (Mandatory=$true)]
        [string] $TablePartitionKey,
        [parameter (Mandatory=$true)]
        [string] $TableRowKey,
        [parameter (Mandatory=$true)]
        [string] $TableName       
    )

    $returnmsg = [ReturnMsg]::new()

    try
    {
        $returnmsg.LogMsg = "Get Azure Table $TableName in RG $($global:ConfApplRG) in at Storage Account $($global:ConfApplStrAcc) `n"
            $table = Get-AzTableTable -TableName $TableName -resourceGroup $($global:ConfApplRG) `
                                      -storageAccountName $($global:ConfApplStrAcc)

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Remove row from Azure Table `n"
            $resultaddtableinfo = Get-AzTableRow -table $table `
                                                 -partitionKey $TablePartitionKey `
                                                 -rowKey $TableRowKey

            $removeresult = $resultaddtableinfo | Remove-AzTableRow -Table $table

        $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Success
    }
    catch
    {
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in section Remove-Info-from-Config-Table. Error message: $($_.Exception.Message) `n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error
    }

    return $returnmsg
}

function Get-Info-from-Config-Table()
{
    param (
        [parameter (Mandatory=$true)]
        [string] $TableRowKey,
        [parameter (Mandatory=$true)]
        [string] $TablePartitionKey,
        [parameter (Mandatory=$true)]
        [string] $TableName       
    )

    $returnmsg = [ReturnMsg]::new()

    try
    {
        $returnmsg.LogMsg = "Get Azure Table $TableName in RG $($global:ConfApplRG) bin at Storage Account $($global:ConfApplStrAcc) `n"
            $table = Get-AzTableTable -TableName $TableName -resourceGroup $($global:ConfApplRG) `
                                      -storageAccountName $($global:ConfApplStrAcc)

        if($TableRowKey -eq "*")
        {
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Get all table rows `n"
                $rowkeyresult = Get-AzTableRow -Table $table | ConvertTo-Json

        }
        else {                    
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Get Table Row `n"
                $rowkeyresult = Get-AzTableRow -Table $table `
                                               -PartitionKey $TablePartitionKey `
                                               -RowKey $TableRowKey | ConvertTo-Json
        }

        $returnmsg.LogMsg = $returnmsg.LogMsg + "Return rowkey count `n"

        if($null -ne $rowkeyresult)
        {
            $returnmsg.ReturnParameter1 = "true"
            $returnmsg.ReturnJsonParameters02 = $rowkeyresult
            $returnmsg.ReturnCode = [ReturnCode]::Success.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Success
        }        
        else {
            $returnmsg.ReturnParameter1 = "false"
            $returnmsg.ReturnJsonParameters02 = "null"
            $returnmsg.LogMsg = $returnmsg.LogMsg + "Warning, no row found."
            $returnmsg.ReturnCode = [ReturnCode]::Warning.Value__
            $returnmsg.ReturnMsg = [ReturnCode]::Warning
        }        
    }
    catch
    {
        $returnmsg.LogMsg = $returnmsg.LogMsg + "Error in section Get-Info-from-Config-Table. Error message: $($_.Exception.Message) `n"
        $returnmsg.ReturnCode = [ReturnCode]::Error.Value__
        $returnmsg.ReturnMsg = [ReturnCode]::Error
    }

    return $returnmsg
}

######################################################################
#
# Log Analytics functions
#
######################################################################

function Write-State-to-LogAnalytics
{    
    param (
        [parameter (Mandatory=$true)]
        [ValidateSet('Success','Warning','Error', 'Debug')]
        [string] $MessageType,
        [parameter (Mandatory=$false)]
        [string] $WorkflowID = "null",
        [parameter (Mandatory=$true)]
        [string] $ScriptName,
        [parameter (Mandatory=$false)]
        [string] $ScriptSection="None",
        [parameter (Mandatory=$false)]
        [string] $InfoMessage="None",        
        [parameter (Mandatory=$false)]
        [string] $WarnMessage="None",
        [parameter (Mandatory=$false)]
        [string] $ErrorMessage="None",
        [parameter (Mandatory=$false)]
        [string] $AdditionalInfo="None",
        [parameter (Mandatory=$false)]
        [ValidateSet('AppMpTool','AppMpToolPermChanges')]
        [string] $LogName="AppMpTool",
        [parameter (Mandatory=$false)]
        [string] $InitiatedBy="None"
    )    

    try
    {        
        $tempdate = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date), (Get-AutomationVariable -Name "Conf-App-TimeZone"))
    }
    catch
    {
        $tempdate = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date), 'W. Europe Standard Time')
    }

    $date = get-date -Date $tempdate -Format G

    #$MappingToolLogALog = "AppMappingtool"

    $OMSMessage = @{"MonitorType"="Client"; `
                    "Hostname"="AzureAutomation"; `
                    "Date"=$date; `
                    "LogName"=$LogName; `
                    "State"=$MessageType; `
                    "WorkflowID"=$WorkflowID; `
                    "ScriptName"=$ScriptName; `
                    "ScriptSection"=$ScriptSection; `
                    "InfoMessage"=$InfoMessage; `
                    "WarnMessage"=$WarnMessage; `
                    "ErrorMessage"=$ErrorMessage;`
                    "AdditionalInfo"=$AdditionalInfo; `
                    "InitiatedBy"=$InitiatedBy}        

    $MappingToolLogACon = Get-AutomationConnection -Name $global:HCAzLogACon

    $json = $OMSMessage | ConvertTo-Json

    Post-LogAnalyticsData -customerId $($MappingToolLogACon.WorkspaceID) `
                          -sharedKey $($MappingToolLogACon.SharedKey) `
                          -body ([System.Text.Encoding]::UTF8.GetBytes($json)) `
                          -logType $LogName  
}

######################################################################
#
# Admin portal functions
#
######################################################################

function Call-Fix-Configuration-Issue
{
    param (
        [parameter (Mandatory=$true)]
        [object] $PartitionKey,
        [parameter (Mandatory=$true)]
        [object] $RowKey,
        [parameter (Mandatory=$true)]
        [object] $Action
    )

    $tableconfig = Get-Info-from-Config-Table -TableRowKey $RowKey `
                                              -TablePartitionKey $PartitionKey `
                                              -TableName $global:ConfConfigurationTable

    if($Action -eq "fix")
    {
        
    }
    elseif($Action -eq "discard")
    {

    }
}