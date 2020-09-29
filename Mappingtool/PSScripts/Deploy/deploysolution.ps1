
#region Login into Azure and select the right subscription

Login-AzAccount

Get-AzSubscription

Select-AzSubscription -Subscription bb8e13db-cd67-4923-8aea-a4d66b65cf84

#endregion

#region Define Parameters

$OUAADPerm = "OU=AAD,OU=TestOU,DC=dokatemp,DC=com"
$OURBACPerm = "OU=RG,OU=TestOU,DC=dokatemp,DC=com"

#endregion

#region Define Public Variables

$RG = "RG-Sol-MappingTool"
$ToolName = "AppMappingTool" #Important, only use A-Z,a-z
$AppLocation = "West Europe"
$CloudQueueName = "cloud-queue"
$OnPremQueueName = "on-premqueue"
$RBACConfigTable = "rbacconfiguration"
$PermMappingTable = "rolemapping"
$IssueTable = "workflowissue"
$Runbooklocation = "C:\temp\MappingTool\Runbooks"


#endregion

#region define sevice prinzipal

$credentials = New-Object -TypeName Microsoft.Azure.Commands.ActiveDirectory.PSADPasswordCredential `
                          -Property @{StartDate = Get-Date; EndDate=Get-Date -Year 2124; Password='StrongPassworld!23'}
$sp = New-AzADServicePrincipal -DisplayName "$($ToolName)-sp" -PasswordCredential $credentials

#endregion

#region create azure automation

$newautomacc = New-AzAutomationAccount -ResourceGroupName $RG -Name "$($ToolName)-automacc" -Location $AppLocation

#endregion

#region Import Module MappingTool
    Write-Output "Import supported MappingTool module"
    $mappingtoomodule = New-AzAutomationModule -Name MappingTool -AutomationAccountName $newautomacc.AutomationAccountName -ResourceGroupName $newautomacc.ResourceGroupName -ContentLinkUri https://mappingtoolstracc.blob.core.windows.net/sources/MappingTool.zip

    do {
        Start-Sleep -Seconds 30
        Write-Output "Wait 30 seconds"

    } while ((Get-AzAutomationModule -ResourceGroupName $RG -AutomationAccountName "$($ToolName)-automacc" -Name MappingTool).ProvisioningState -eq "Creating")

    if ((Get-AzAutomationModule -ResourceGroupName $RG -AutomationAccountName "$($ToolName)-automacc" -Name MappingTool).ProvisioningState -eq "Succeeded") {
        Write-Output "Finish"
    }
    else {
        Write-Output "Failed to import module"
    }

#endregion

#region Import Module Az.Accounts

    Write-Output "Import supported Az.Accounts module"
    $azaccountmodule = New-AzAutomationModule -Name Az.Accounts -AutomationAccountName $newautomacc.AutomationAccountName -ResourceGroupName $newautomacc.ResourceGroupName -ContentLinkUri https://mappingtoolstracc.blob.core.windows.net/sources/az.accounts.zip
    
    do {
        Start-Sleep -Seconds 30
        Write-Output "Wait 30 seconds"

    } while ((Get-AzAutomationModule -ResourceGroupName $RG -AutomationAccountName "$($ToolName)-automacc" -Name Az.Accounts).ProvisioningState -eq "Creating")

    Start-Sleep -Seconds 30

    if ((Get-AzAutomationModule -ResourceGroupName $RG -AutomationAccountName "$($ToolName)-automacc" -Name Az.Accounts).ProvisioningState -eq "Succeeded") {
        Write-Output "Finish"
    }
    else {
        Write-Output "Failed to import module"
    }

#endregion

#region Import Module Az.Resources

Write-Output "Import supported Az.Resources module"
$azaccountmodule = New-AzAutomationModule -Name Az.Resources -AutomationAccountName $newautomacc.AutomationAccountName -ResourceGroupName $newautomacc.ResourceGroupName -ContentLinkUri https://mappingtoolstracc.blob.core.windows.net/sources/az.resources.zip

do {
    Start-Sleep -Seconds 30
    Write-Output "Wait 30 seconds"

} while ((Get-AzAutomationModule -ResourceGroupName $RG -AutomationAccountName "$($ToolName)-automacc" -Name Az.Resources).ProvisioningState -eq "Creating")

Start-Sleep -Seconds 30

if ((Get-AzAutomationModule -ResourceGroupName $RG -AutomationAccountName "$($ToolName)-automacc" -Name Az.Resources).ProvisioningState -eq "Succeeded") {
    Write-Output "Finish"
}
else {
    Write-Output "Failed to import module"
}

#endregion

#region Import Module Az.Storage

Write-Output "Import supported Az.Storage module"
$azaccountmodule = New-AzAutomationModule -Name Az.Storage -AutomationAccountName $newautomacc.AutomationAccountName -ResourceGroupName $newautomacc.ResourceGroupName -ContentLinkUri https://mappingtoolstracc.blob.core.windows.net/sources/az.storage.zip

do {
    Start-Sleep -Seconds 30
    Write-Output "Wait 30 seconds"

} while ((Get-AzAutomationModule -ResourceGroupName $RG -AutomationAccountName "$($ToolName)-automacc" -Name Az.Storage).ProvisioningState -eq "Creating")

Start-Sleep -Seconds 30

if ((Get-AzAutomationModule -ResourceGroupName $RG -AutomationAccountName "$($ToolName)-automacc" -Name Az.Storage).ProvisioningState -eq "Succeeded") {
    Write-Output "Finish"
}
else {
    Write-Output "Failed to import module"
}

#endregion

#region Import Module AzTable

Write-Output "Import supported AzTable module"
$azaccountmodule = New-AzAutomationModule -Name AzTable -AutomationAccountName $newautomacc.AutomationAccountName -ResourceGroupName $newautomacc.ResourceGroupName -ContentLinkUri https://mappingtoolstracc.blob.core.windows.net/sources/aztable.zip

do {
    Start-Sleep -Seconds 30
    Write-Output "Wait 30 seconds"

} while ((Get-AzAutomationModule -ResourceGroupName $RG -AutomationAccountName "$($ToolName)-automacc" -Name AzTable).ProvisioningState -eq "Creating")

Start-Sleep -Seconds 30

if ((Get-AzAutomationModule -ResourceGroupName $RG -AutomationAccountName "$($ToolName)-automacc" -Name AzTable).ProvisioningState -eq "Succeeded") {
    Write-Output "Finish"
}
else {
    Write-Output "Failed to import module"
}

#endregion

#region Import Module Az.Automation

Write-Output "Import supported Az.Automation module"
$azaccountmodule = New-AzAutomationModule -Name Az.Automation -AutomationAccountName $newautomacc.AutomationAccountName -ResourceGroupName $newautomacc.ResourceGroupName -ContentLinkUri https://mappingtoolstracc.blob.core.windows.net/sources/az.automation.zip

do {
    Start-Sleep -Seconds 30
    Write-Output "Wait 30 seconds"

} while ((Get-AzAutomationModule -ResourceGroupName $RG -AutomationAccountName "$($ToolName)-automacc" -Name Az.Automation).ProvisioningState -eq "Creating")

Start-Sleep -Seconds 30

if ((Get-AzAutomationModule -ResourceGroupName $RG -AutomationAccountName "$($ToolName)-automacc" -Name Az.Automation).ProvisioningState -eq "Succeeded") {
    Write-Output "Finish"
}
else {
    Write-Output "Failed to import module"
}

#endregion

#region Create Automation Shared Resources

Write-Output "Create connection object"
$FieldValues = @{"TenantId"=(Get-AzTenant).Id;"AplicationID"=$sp.ApplicationId;"Secret"=$credentials.Password}
$mappingtoolconnection = New-AzAutomationConnection -Name "MappingToolSP" -ConnectionTypeName Mappingtool.RunAsAccount -ConnectionFieldValues $FieldValues -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName

Write-Output "Create variables"
$varaadperm = New-AzAutomationVariable -Name "Conf-AD-OUPath-AADPerm" -Value $OUAADPerm -Description "Configuration setting: AD OUTPath for AAD Permissions" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varrbacperm = New-AzAutomationVariable -Name "Conf-AD-OUPath-RBACPerm" -Value $OURBACPerm -Description "Configuration setting: AD OUTPath for ResourceGroup RBAC Permissions" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varautomacc = New-AzAutomationVariable -Name "Conf-App-Automation-Account" -Value "$($ToolName)-automacc" -Description "Configuration setting: Application Automation Account" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varcloudqueue = New-AzAutomationVariable -Name "Conf-App-Cloud-Msg-Queue" -Value $CloudQueueName -Description "Configuration setting: Main message queue for cloud tasks" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varonpremqueue = New-AzAutomationVariable -Name "Conf-App-OnPrem-Msg-Queue" -Value $OnPremQueueName -Description "Configuration setting: Main message queue for On-Prem tasks" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varconft = New-AzAutomationVariable -Name "Conf-App-Configuration-Table" -Value $RBACConfigTable -Description "Configuration setting: Main configuration table for mapping tool application" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varmappingt = New-AzAutomationVariable -Name "Conf-App-Mapping-Table" -Value $PermMappingTable -Description "Configuration setting: Main mapping table for application. This table includes the RBAC to Permission mapping" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varissuet = New-AzAutomationVariable -Name "Conf-App-Issue-Table" -Value $IssueTable -Description "Configuration setting: Main issue table for application. This table includes all issues from the application" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varloga = New-AzAutomationVariable -Name "Conf-App-Loganalytics-WS" -Value "$($ToolName)-loga" -Description "Configuration setting: Application main Log Analytics workspace for minitoring" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varapprg = New-AzAutomationVariable -Name "Conf-App-ResourceGroup" -Value $RG -Description "Configuration setting: mapping tool resource group" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varmaintag = New-AzAutomationVariable -Name "Conf-App-RG-MainTag" -Value "GroupMapping" -Description "Configuration setting: main resource group tag to get RBAC permission settings" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varrgtomon = New-AzAutomationVariable -Name "Conf-App-RG-to-Monitor" -Value "AZ-RBAC-" -Description "Configuration setting: Resoucegroup name (start with) to monitor for new permissions" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varstracc = New-AzAutomationVariable -Name "Conf-App-StorageAccount" -Value "$($ToolName.ToLower())stracc" -Description "Configuration setting: Main storage account for mapping tool application" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varnsaadperm = New-AzAutomationVariable -Name "NS-AAD-Perm" -Value "AZ-AAD-" -Description "Naming Standard for AAD Permissions. Each AAD Group start with:" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varnsrbacperm = New-AzAutomationVariable -Name "NS-AAD-RBAC-Perm" -Value "AZ-RBAC-" -Description "Naming standard setting: Naming standard for Azure AD groups (start with). Mapping between Azure Resource Group RBAC and AzureAD" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varnsopperm = New-AzAutomationVariable -Name "NS-AD-OnPrem-Perm" -Value "OP-AAD-" -Description "Naming Standard for AD (On-Prem) Permissions. Each AD Group start with" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName
$varoprbacperm = New-AzAutomationVariable -Name "NS-AD-OnPrem-RBAC-Perm" -Value "OP-RBAC-" -Description "Naming standard setting: Naming standard for On-Prem AD groups (start with). Mapping between Azure Resource Group RBAC and On-Prem" -Encrypted $false -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName

#endregion

####WICHTIG hier noch GitHub einbinden für den Source Control!#######
#Demo URL:  https://docs.microsoft.com/en-us/azure/automation/source-control-integration#:~:text=Configure%20source%20control%20in%20Azure%20portal&text=In%20your%20Automation%20account%2C%20select,the%20prompts%20to%20complete%20authentication.
#region Import Automation Runbooks including Webhooks

foreach ($file in (Get-ChildItem -Path $Runbooklocation)) {
    Write-Output "Import Runbook $($file.Name)"
    $importstatus = Import-AzAutomationRunbook -Path $file.FullName -ResourceGroupName $newautomacc.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName -Description "" -Name $file.Name -Published -Type PowerShell

    if($file.Name -eq "AddtoQueue.ps1")
    {
        Write-Output "Create AAD webhhok"
        $aadwebhook = New-AzAutomationWebhook -Name "webhookaad" -AutomationAccountName $newautomacc.AutomationAccountName -ResourceGroupName $newautomacc.ResourceGroupName -RunbookName $importstatus.Name -IsEnabled $true -ExpiryTime (Get-Date).AddYears(10) -Force

        Write-Output "Create ResourceGroup webhhok"
        $rgwebhook = New-AzAutomationWebhook -Name "webhookrg" -AutomationAccountName $newautomacc.AutomationAccountName -ResourceGroupName $newautomacc.ResourceGroupName -RunbookName $importstatus.Name -IsEnabled $true -ExpiryTime (Get-Date).AddYears(10) -Force

        Write-Output "Create AAD webhhok"
        $aadwebhook = New-AzAutomationWebhook -Name "webhookaad" -AutomationAccountName "AppMappingTool-automacc" -ResourceGroupName $RG -RunbookName "TaskAddMSGtoQueue" -IsEnabled $true -ExpiryTime (Get-Date).AddYears(10) -Force

        Write-Output "Create ResourceGroup webhhok"
        $rgwebhook = New-AzAutomationWebhook -Name "webhookrg" -AutomationAccountName "AppMappingTool-automacc" -ResourceGroupName $RG -RunbookName "TaskAddMSGtoQueue" -IsEnabled $true -ExpiryTime (Get-Date).AddYears(10) -Force
    }
}

#endregion

#region Create EventGrid for Subscriptions

$includedEventTypes = "Microsoft.Resources.ResourceWriteSuccess"
$AdvFilter1=@{operator="StringIn"; key="data.authorization.action"; Values=@('Microsoft.Resources/subscriptions/resourceGroups/write')} 
$AdvFilter2=@{operator="StringContains"; key="data.authorization.scope"; Values=@('/resourceGroups/RG-','/resourceGroups/rg-','/resourceGroups/rG-','/resourceGroups/Rg-')} 

$RGEventGridSubscription = New-AzEventGridSubscription -EventSubscriptionName "$($ToolName)-subevent" `
                                                       -EndpointType webhook `
                                                       -Endpoint $($rgwebhook.WebhookURI) `
                                                       -IncludedEventType $includedEventTypes `
                                                       -AdvancedFilter @($AdvFilter1;$AdvFilter2)


#endregion

#WICHTIG, SP noch als Storage Queue Data Contributor und als AAD User Administrator berechtigen
#region Create Storage Account

    $appstorageacc = New-AzStorageAccount -Name "$($ToolName.ToLower())stracc" -ResourceGroupName $RG -Location $AppLocation -SkuName Standard_LRS -Kind StorageV2
    $appstorageacc | New-AzStorageQueue -Name $CloudQueueName 
    $appstorageacc | New-AzStorageQueue -Name $OnPremQueueName
    
    $appstorageacc | New-AzStorageTable -Name $RBACConfigTable
    $appstorageacc | New-AzStorageTable -Name $PermMappingTable
    $appstorageacc | New-AzStorageTable -Name $IssueTable

#endregion

#region Create LogAnalytics account

$Workspace = New-AzOperationalInsightsWorkspace -Location $AppLocation -Name "$($ToolName)-loga1" -Sku Standard -ResourceGroupName $RG

#endregion

#region Enable Hybrid Worker functionality

$hybridworkersolution = Set-AzOperationalInsightsIntelligencePack -ResourceGroupName $RG -WorkspaceName "$($ToolName)-loga" -IntelligencePackName "AzureAutomation" -Enabled $true 

#endregion

#region Create Hybrid Worker install script
#URL: https://blog.nillsf.com/index.php/2019/11/25/setting-up-an-azure-automation-hybrid-worker/

#Install SCOM Agent 
#https://go.microsoft.com/fwlink/?LinkId=828603
#WorkspaceID
#WorkspaceKey

$RegistrationURL = (Get-AzAutomationRegistrationInfo -ResourceGroupName $RG -AutomationAccountName $newautomacc.AutomationAccountName).Endpoint
$RegistrationKey = (Get-AzAutomationRegistrationInfo -ResourceGroupName $RG -AutomationAccountName $newautomacc.AutomationAccountName).PrimaryKey

#Add-HybridRunbookWorker -Url $RegistrationURL -Key $RegistrationKey


#endregion


#Create Credentials for Hybrid Worker User!!!
#Assign User to Hybrid Worker Group



