#Requironments:
# Latest Az Modules
# Latest AzureADPreview Module
# Latest AzTable Module

[CmdletBinding()]
param (
    [parameter (Mandatory=$true)]
    [string] $Hybridworkerusername,

    [parameter (Mandatory=$true)]
    [string]$Hybridworkerpasswort,

    [parameter (Mandatory=$true)]
    [string]$PATDeploymentToken,

    [parameter (Mandatory=$true)]
    [string]$TenantID = ""
)

$ErrorActionPreference = ""

#region Functions
function Get-RandomCharacters($length, $characters) { 
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length } 
    $private:ofs="" 
    return [String]$characters[$random]
}

function Logging($State, $Section, $MSG){

    $LogMessage = "$State;$Section;$MSG"
    Add-Content -Path .\Logging.txt -Value $LogMessage
}

#endregion

try {
    
    Import-Module AzureADPreview

    #region Login into Azure and select the right subscription

    Write-Output "-----------------------------------------------------------------------"
    Write-Output " "
    Write-Output "                           Login into azure                            "
    Write-Output " "
    Write-Output "-----------------------------------------------------------------------"
      
    if ($TenantID -eq "") {
        Login-AzAccount       
    }    
    else {
        Login-AzAccount -Tenant $TenantID
    }

    Write-Output "-----------------------------------------------------------------------"
    Write-Output " "
    Write-Output "                           Login into azure ad                         "
    Write-Output " "
    Write-Output "-----------------------------------------------------------------------"

    $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
    $aadToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.windows.net").AccessToken
    
        Connect-AzureAD -AadAccessToken $aadToken `
                        -AccountId $context.Account.Id `
                        -TenantId $context.tenant.id

        Logging -State "Success" `
                -Section "Login into Azure" `
                -MSG "Success"                                

    Write-Output "-----------------------------------------------------------------------"
    Write-Output " "
    Write-Output "                           Get subscriptions                           "
    Write-Output " "
    Write-Output "-----------------------------------------------------------------------"

    $subscriptions = Get-AzSubscription
    $hassubscription = @{}

    $i = 1;
    foreach ($subscription in $subscriptions)
    {
        Write-Output "$i for subscription $($subscription.Name)"    
        $hassubscription[$i] = "$($subscription.Id);$($subscription.TenantId)"
        $i++
    }


    [int]$selsubs = Read-Host -Prompt "Please enter the subscription number for you deployment"

    #endregion

    
if($hassubscription.ContainsKey($selsubs))
{
    $splitselsub = $hassubscription.Item($selsubs).Split(";")
    $selectedsubscription = $splitselsub[0] 
    Select-AzSubscription -Subscription $splitselsub[0]          

    Write-Output "-----------------------------------------------------------------------"
    Write-Output " "
    Write-Output "                       Start resource deployment                       "
    Write-Output " "
    Write-Output "-----------------------------------------------------------------------"


    #region Global Parameters for deployment
    # Variables change is not supported!
    
        Write-Output "- Define global variables"

            $TenantID = $splitselsub[1]
            $RG = "RG-MappingTool"
            $ToolName = "AppMT"
            $ToolNameSuffix = $selectedsubscription.Replace('-','').Substring(0, 15)
            $AppLocation = "West Europe"        
                            
            $CloudQueueName = "cloud-queue"
            $OnPremQueueName = "on-premqueue"
            $RBACConfigTable = "rbacconfiguration"
            $PermMappingTable = "rolemapping"
            $IssueTable = "workflowissue"                
            $GitHubPatToken = ConvertTo-SecureString $PATDeploymentToken -AsPlainText -Force     
            
            $installmodtable = @{}
            $installmodtable.Add("1", "Az.Accounts;https://github.com/Lagler-Gruener/Sol-MappingToolDeploy/blob/main/Modules/az.accounts.zip?raw=true")
            $installmodtable.Add("2","Az.Resources;https://github.com/Lagler-Gruener/Sol-MappingToolDeploy/blob/main/Modules/az.resources.zip?raw=true")
            $installmodtable.Add("3","Az.Storage;https://github.com/Lagler-Gruener/Sol-MappingToolDeploy/blob/main/Modules/az.storage.zip?raw=true")
            $installmodtable.Add("4","AzTable;https://github.com/Lagler-Gruener/Sol-MappingToolDeploy/blob/main/Modules/aztable.zip?raw=true")
            $installmodtable.Add("5","Az.Automation;https://github.com/Lagler-Gruener/Sol-MappingToolDeploy/blob/main/Modules/az.automation.zip?raw=true")
            $installmodtable.Add("6","MappingToolLogA;https://github.com/Lagler-Gruener/Sol-MappingToolDeploy/blob/main/Modules/MappingToolLogA.zip?raw=true")
            $installmodtable.Add("7","MappingTool;https://github.com/Lagler-Gruener/Sol-MappingToolDeploy/blob/main/Modules/MappingTool.zip?raw=true")

        Write-Output "DONE"
        Write-Output " "
    
    #endregion     

    #region Resource deployment

        #region Deploy solution resourcegroup if not exist

        Write-Output "- Deploy resourcegroup $RG"
            try {
                                
                $deploymentrg = ""

                if (Get-AzResourceGroup -Name $RG -ErrorAction SilentlyContinue) {
                    Write-Output "Azure resource group exist."
                    $deploymentrg = Get-AzResourceGroup -Name $RG
                }
                else {
                    Write-Output "Create Azure resource group $RG"
        
                    $tags = @{
                        "Product"="Azure Mappingtool by. Hannes Lagler-Gruener"; 
                        "Details"="Visit the Github Account (https://github.com/Lagler-Gruener/AzureSolutions/tree/master/Mappingtool) to get more information."
                    }
        
                    $deploymentrg = New-AzResourceGroup -Name $RG -Location $AppLocation -Tag $tags            
                }  
                
                if($deploymentrg -eq "")
                {
                    throw "Error resourcegroup not deployed! Script stopped"
                }

                Write-Output "DONE"
                Write-Output " "
            }
            catch {
                throw "Error in resourcegroup deployment. Error message $($_.Exception.Message)"
            }

        #endregion

        #region create azure service principal
            
            Write-Output "- Deploy azure service principal SP-$($ToolName)-$($ToolNameSuffix)"
            try {                       

                [Reflection.Assembly]::LoadWithPartialName('System.Web')
                $sppw = Get-RandomCharacters -length 35 -characters abcdefghiklmnoprstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-+!-#*
            
                $spcredentials = New-Object -TypeName Microsoft.Azure.Commands.ActiveDirectory.PSADPasswordCredential `
                                            -Property @{StartDate = Get-Date; EndDate=Get-Date -Year 2124; Password=$sppw}
        
                $spcreateerror = ""
                $sp = New-AzADServicePrincipal -DisplayName "SP-$($ToolName)-$($ToolNameSuffix)" `
                                                -PasswordCredential $spcredentials `
                                                -ErrorAction SilentlyContinue

                if($null -eq $sp)
                {
                    throw "Error sp not deployed! Script stopped Error: $spcreateerror"
                }

                Write-Output "DONE"
                Write-Output " "

                Write-Output "Assign owner permission to subscription $selectedsubscription"

                    $id = $sp.ApplicationId
                    $ownerassigment = New-AzRoleAssignment -ApplicationId $id `
                                                           -RoleDefinitionName Owner `
                                                           -Scope "/subscriptions/$selectedsubscription"

                Write-Output "DONE"
                Write-Output " "

                Write-Output "Assign User Administrator permission to tenant $($TenantID)"

                    $useradminresult = Get-AzureADDirectoryRole | Where-Object DisplayName -EQ "User Administrator"

                    if ($null -eq $useradminresult) {
                        $templater = Get-AzureADDirectoryRoleTemplate | Where-Object DisplayName -EQ "User Administrator"
                        $useradminresult = Enable-AzureADDirectoryRole -RoleTemplateId $templater.ObjectId
                    }

                    $useradminassigment = Add-AzureADDirectoryRoleMember -ObjectId $useradminresult.ObjectId `
                                                                         -RefObjectId $sp.Id
                    
                Write-Output "DONE"
                Write-Output " "
            }
            catch {
                throw "Error in sp deployment. Error message $($_.Exception.Message)"
            }
    
        #endregion

            #region create azure automation

                Write-Output "- Deploy azure automation account $($ToolName)AutomAcc$($ToolNameSuffix)"
                try {                                             

                    $newautomacc = New-AzAutomationAccount -ResourceGroupName $deploymentrg.ResourceGroupName -Name "$($ToolName)AutomAcc$($ToolNameSuffix)" -Location $AppLocation
                
                    if($null -eq $newautomacc)
                    {
                        throw "Error automationaccount not deployed! Script stopped"
                    }

                    Write-Output "DONE"
                    Write-Output " "
                }
                catch {
                    throw "Error in automationaccount deployment. Error message $($_.Exception.Message)"
                }

            #endregion

            #region create azure keyvault

                #Force purge KeyVault: az keyvault purge --name --location --no-wait --subscription
                Write-Output "- Deploy azure keyvault  $($ToolName)KeyV$($ToolNameSuffix)"
                try {
                                                        
                    $keyvaultmappingtool = New-AzKeyVault -Name "$($ToolName)KeyV$($ToolNameSuffix)" `
                                                          -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                          -Location $AppLocation
                    
                    if($null -eq $keyvaultmappingtool)
                    {
                        throw "Error keyvault not deployed! Script stopped"
                    }                    

                    Write-Output "DONE"
                    Write-Output " "
                }
                catch {
                    throw "Error in keyvault deployment. Error message $($_.Exception.Message)"                                    
                }

            #endregion

            #region create azure storage account

                Write-Output "- Deploy azure storage account $($ToolName.ToLower())$($ToolNameSuffix)"
                try {                    

                    $appstorageacc = New-AzStorageAccount -Name "$($ToolName.ToLower())$($ToolNameSuffix)" -ResourceGroupName $deploymentrg.ResourceGroupName -Location $AppLocation -SkuName Standard_LRS -Kind StorageV2

                    if($null -eq $appstorageacc)
                    {
                        throw "Error storage account not deployed! Script stopped"
                    }

                    Write-Output "DONE"
                    Write-Output " "

                    Write-Output "Assign sp $($sp.DisplayName) to the 'Storage Queue Data Contributor'"

                        $strqueuerole = Get-AzRoleDefinition | where {$_.Name -eq "Storage Queue Data Contributor"}
                        $sproleassignment = New-AzRoleAssignment -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                                 -ResourceName $appstorageacc.StorageAccountName `
                                                                 -ApplicationId $sp.ApplicationId `
                                                                 -RoleDefinitionName "Storage Queue Data Contributor" `
                                                                 -ResourceType Microsoft.Storage/storageAccounts
                    Write-Output "DONE"
                    Write-Output " "    
                    
                    Write-Output "Create cfconfigissue table and add default rows"
                        $appstorageacc | New-AzStorageTable -Name "cfconfigissue"    
                    
                    Write-Output "Create cfrbacarchiv table and add default rows"
                        $appstorageacc | New-AzStorageTable -Name "cfrbacarchiv"    
                            
                    Write-Output "DONE"
                    Write-Output " "

                    Write-Output "Create cfrbacperm table and add default rows"
                        $appstorageacc | New-AzStorageTable -Name "cfrbacperm"     
                            
                    Write-Output "DONE"
                    Write-Output " "

                    Write-Output "Create cfrolemapping table and add default rows"
                        $appstorageacc | New-AzStorageTable -Name "cfrolemapping"     
                
                    Write-Output "DONE"
                    Write-Output " "

                    Write-Output "Create cfmappingtool table and add default rows"
                        $appstorageacc | New-AzStorageTable -Name "cfmappingtool"  
                }
                catch {
                    throw "Error in storage account deployment. Error message $($_.Exception.Message)"     
                }
            
            #endregion

            #region create azure loganalytics account

                Write-Output "- Deploy azure loganalytics $($ToolName)LogA$($ToolNameSuffix)"
                try {                                                  
                    $Workspace = New-AzOperationalInsightsWorkspace -Location $AppLocation -Name "$($ToolName)LogA$($ToolNameSuffix)" -Sku Standard -ResourceGroupName $deploymentrg.ResourceGroupName

                    if($null -eq $Workspace)
                    {
                        throw "Error storage account not deployed! Script stopped"
                    }

                    $kvkey = (Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $deploymentrg.ResourceGroupName -Name $Workspace.Name).PrimarySharedKey

                    Write-Output "DONE"
                    Write-Output " "
                }
                catch {
                    throw "Error in loganalytics deployment. Error message $($_.Exception.Message)"     
                }

            #endregion

            #region create azure webapp

                Write-Output "- Deploy azure app service plan $($ToolName)AppSvcPlan$($ToolNameSuffix)"
                try {                                                    
                    $appsvcplan = New-AzAppServicePlan -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                       -Location $AppLocation `
                                                       -Name "$($ToolName)AppSvcPlan$($ToolNameSuffix)" `
                                                       -Tier Standard `
                                                       -WorkerSize Small `
                                                       -NumberofWorkers 1 

                    if($null -eq $appsvcplan)
                    {
                        throw "Error app service plan not deployed! Script stopped"
                    }

                    Write-Output "DONE"
                    Write-Output " "

                    Write-Output "- Deploy azure app service $($ToolName)Admintool$($ToolNameSuffix)"

                    $webapp = New-AzWebApp -ResourceGroupName $deploymentrg.ResourceGroupName `
                                           -Location $AppLocation `
                                           -AppServicePlan $appsvcplan.Name `
                                           -Name "$($ToolName)Admintool$($ToolNameSuffix)"
                    
                    if($null -eq $webapp)
                    {
                        throw "Error app service not deployed! Script stopped"
                    }

                    Write-Output "DONE"
                    Write-Output " "
                }
                catch {
                    throw "Error in app service deployment. Error message $($_.Exception.Message)"                
                }

            #endregion
            
            #region create azure application insight

            Write-Output "- Deploy azure application insights $($ToolName)AppInsight$($ToolNameSuffix)"
            try {

                $appinsight = New-AzApplicationInsights -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                        -Name "$($ToolName)AppInsight$($ToolNameSuffix)" `
                                                        -location $AppLocation   
                                                        
                Write-Output "DONE"
                Write-Output " "
            
            }
            catch {
                throw "Error in app insight deployment. Error message $($_.Exception.Message)"      
            }  

        #endregion

    #endregion

        Write-Output "-----------------------------------------------------------------------"
        Write-Output "                                                                       "
        Write-Output "                     Start resource configuration                      "
        Write-Output "                                                                       "
        Write-Output "-----------------------------------------------------------------------"

        #region Resource configuration


                try {                                    
                    
                    #region create runas account                        
                        Write-Output "- Download create runas script"
                        Invoke-WebRequest https://raw.githubusercontent.com/azureautomation/runbooks/master/Utility/AzRunAs/Create-RunAsAccount.ps1 -outfile Create-RunAsAccount.ps1

                        Write-Output "DONE"
                        Write-Output " "

                        Write-Output "- Create runas account"

                        .\Create-RunAsAccount.ps1 -ResourceGroup $deploymentrg.ResourceGroupName `
                                                -AutomationAccountName $newautomacc.AutomationAccountName `
                                                -SubscriptionId $selectedsubscription `
                                                -ApplicationDisplayName "SP-$($ToolName)-RunasAccount" `
                                                -SelfSignedCertPlainPassword $sppw `
                                                -CreateClassicRunAsAccount $false
                        
                        Write-Output "DONE"
                        Write-Output " "
                            
                    #endregion                    
                    
                    #region installing required modules
                        Write-Output "- Installing required modules"

                        $failmodules = @{}
                        foreach ($module in ($installmodtable.GetEnumerator() | Sort-Object Name))
                        {
                            try {                                
                                $splitmodule = $module.Value.Split(";")
                                $modulename = $splitmodule[0].ToString()
                                $moduleuri = $splitmodule[1].ToString()

                                Write-Output $modulename

                                $azaccountmodule = New-AzAutomationModule -Name $modulename `
                                                                        -AutomationAccountName $newautomacc.AutomationAccountName `
                                                                        -ResourceGroupName $newautomacc.ResourceGroupName `
                                                                        -ContentLinkUri $moduleuri

                                do {
                                    Start-Sleep -Seconds 30                                    

                                } while ((Get-AzAutomationModule -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                                -AutomationAccountName $newautomacc.AutomationAccountName `
                                                                -Name $modulename).ProvisioningState -eq "Creating")

                                Start-Sleep -Seconds 30

                                if ((Get-AzAutomationModule -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                            -AutomationAccountName $newautomacc.AutomationAccountName `
                                                            -Name $modulename).ProvisioningState -eq "Succeeded") {
                                    Write-Output "DONE"
                                    Write-Output " "
                                }
                                else {
                                    Write-Output "Failed to import module"
                                    $failmodules.Add($module.Name, "$($modulename);$($moduleuri)")
                                    Write-Output " "
                                }
                            }
                            catch {
                                Write-Output "Cannot import module. Error: $($_.Exception.Message)"
                            }
                        }   
                        
                        
                        Write-Output "Check for fail imports and try it once more."
                        foreach ($module in ($failmodules.GetEnumerator() | Sort-Object Name))
                        {
                            $splitmodule = $module.Value.Split(";")
                            $modulename = $splitmodule[0].ToString()
                            $moduleuri = $splitmodule[1].ToString()

                            Write-Output "Try module $modulename once more to import"
                            $azaccountmodule = New-AzAutomationModule -Name $modulename `
                                                                      -AutomationAccountName $newautomacc.AutomationAccountName `
                                                                      -ResourceGroupName $newautomacc.ResourceGroupName `
                                                                      -ContentLinkUri $moduleuri

                            do {
                                Start-Sleep -Seconds 30                                    

                            } while ((Get-AzAutomationModule -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                    -AutomationAccountName $newautomacc.AutomationAccountName `
                                                    -Name $modulename).ProvisioningState -eq "Creating")

                                Start-Sleep -Seconds 30

                            if ((Get-AzAutomationModule -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                -AutomationAccountName $newautomacc.AutomationAccountName `
                                                -Name $modulename).ProvisioningState -eq "Succeeded") {
                                Write-Output "DONE"
                                Write-Output " "
                            }
                            else {
                                Write-Output "Failed to import module"                            
                                Write-Output " "
                                Write-Host -ForegroundColor Red "Please import module $modulename manuell"
                            }
                        }

                    #endregion

                    #region create connection strings and credentials

                        Write-Output "- Create connection object"
                        try
                        {                                                                        
                            $FieldValues = @{"TenantId"=$TenantID;"SubscriptionID"=$selectedsubscription;"ApplicationID"=$sp.ApplicationId;"Secret"=$spcredentials.Password}
                            $mappingtoolconnection = New-AzAutomationConnection -Name "MappingToolSP" `
                                                                                -ConnectionTypeName Mappingtool.SP `
                                                                                -ConnectionFieldValues $FieldValues `
                                                                                -ResourceGroupName $newautomacc.ResourceGroupName `
                                                                                -AutomationAccountName $newautomacc.AutomationAccountName

                            Write-Output "DONE"
                            Write-Output " "

                            Write-Output "- Create hybrid worker credentials"
                            $Password = ConvertTo-SecureString $Hybridworkerpasswort -AsPlainText -Force
                            $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Hybridworkerusername, $Password
                            $hybridworkercred = New-AzAutomationCredential -ResourceGroupName $newautomacc.ResourceGroupName `
                                                                        -AutomationAccountName $newautomacc.AutomationAccountName `
                                                                        -Name "hybridworkeruser" `
                                                                        -Value $Credential

                            Write-Output "DONE"
                            Write-Output " "


                            Write-Output "Create automation account connection object"
                            $FieldValues = @{"WorkspaceID"=$Workspace.CustomerId;"SharedKey"=$kvkey}
                            $mappingtoolconnection = New-AzAutomationConnection -Name "MappingToolLogA" `
                                                                                -ConnectionTypeName MappingtTool.LogA `
                                                                                -ConnectionFieldValues $FieldValues `
                                                                                -ResourceGroupName $newautomacc.ResourceGroupName `
                                                                                -AutomationAccountName $newautomacc.AutomationAccountName 

                            Write-Output "DONE"
                            Write-Output " "

                        }
                        catch
                        {
                            throw "Error create connection and credentials. Error: $_."
                        }
                        
                    #endregion

                    #region import azure automation runbooks

                    Write-Output "- Import Azure Automation runbooks"
                    Write-Output "Define github source control"

                        try{
                            $sourcecontrol = New-AzAutomationSourceControl -Name SCMappingToolGitHub `
                                                                           -RepoUrl https://github.com/Lagler-Gruener/Sol-MappingToolDeploy.git `
                                                                           -SourceType GitHub `
                                                                           -FolderPath "/Runbooks" `
                                                                           -Branch main `
                                                                           -ResourceGroupName $newautomacc.ResourceGroupName `
                                                                           -AutomationAccountName $newautomacc.AutomationAccountName `
                                                                           -AccessToken $GitHubPatToken

                            Write-Output "DONE"
                            Write-Output " "
                            
                            Write-Output "Start Automation Runbook sync and wait until finished"                                                    
                            Start-AzAutomationSourceControlSyncJob -ResourceGroupName $newautomacc.ResourceGroupName `
                                        -AutomationAccountName $newautomacc.AutomationAccountName `
                                        -Name "SCMappingToolGitHub"

                            do {

                                $status = Get-AzAutomationSourceControlSyncJob -ResourceGroupName $newautomacc.ResourceGroupName `
                                                        -AutomationAccountName $newautomacc.AutomationAccountName `
                                                        -Name "SCMappingToolGitHub"

                                $state = $status.ProvisioningState
                                Start-Sleep -Seconds 5

                            } until ($state -eq "Completed")

                            Write-Output "DONE"
                            Write-Output " "
                            
                            Write-Output "Add storage account name to automation account as variable"
                            New-AzAutomationVariable -ResourceGroupName $deploymentrg.ResourceGroupName -AutomationAccountName $newautomacc.AutomationAccountName -Name "AppMappingToolStrAcc" -Value $appstorageacc.StorageAccountName -Encrypted $false

                            Write-Output "DONE"
                            Write-Output " "

                        }
                        catch
                        {
                            throw "Error create github source control. Error: $_."
                        }
                    
                    #endregion

                    #region Create webhooks for runbook 

                        try
                        {
                            Write-Output "Create AAD webhhok"
                            $aadwebhook = New-AzAutomationWebhook -Name "webhookaad" -AutomationAccountName $newautomacc.AutomationAccountName -ResourceGroupName $deploymentrg.ResourceGroupName -RunbookName "TaskAddMSGtoQueue" -IsEnabled $true -ExpiryTime (Get-Date).AddYears(10) -Force
                
                            Write-Output "DONE"
                            Write-Output " "

                            #Write-Output "Create AAD CH webhhok"
                            #$aadwchebhook = New-AzAutomationWebhook -Name "webhookaadch" -AutomationAccountName $newautomacc.AutomationAccountName -ResourceGroupName $deploymentrg.ResourceGroupName -RunbookName "TaskAddMSGtoQueue" -IsEnabled $true -ExpiryTime (Get-Date).AddYears(10) -Force
                
                            #Write-Output "DONE"
                            #Write-Output " "

                            #Write-Output "Create AAD Del webhhok"
                            #$aaddelwebhook = New-AzAutomationWebhook -Name "webhookaaddel" -AutomationAccountName $newautomacc.AutomationAccountName -ResourceGroupName $deploymentrg.ResourceGroupName -RunbookName "TaskAddMSGtoQueue" -IsEnabled $true -ExpiryTime (Get-Date).AddYears(10) -Force
                    
                            Write-Output "DONE"
                            Write-Output " "

                            Write-Output "Create ResourceGroup webhhok"
                            $rgwebhook = New-AzAutomationWebhook -Name "webhookrg" -AutomationAccountName $newautomacc.AutomationAccountName -ResourceGroupName $deploymentrg.ResourceGroupName -RunbookName "TaskAddMSGtoQueue" -IsEnabled $true -ExpiryTime (Get-Date).AddYears(10) -Force
                    
                            Write-Output "DONE"
                            Write-Output " "

                            Write-Output "Create ResourceGroup Del webhhok"
                            $rgdelwebhook = New-AzAutomationWebhook -Name "webhookrgdel" -AutomationAccountName $newautomacc.AutomationAccountName -ResourceGroupName $deploymentrg.ResourceGroupName -RunbookName "TaskAddMSGtoQueue" -IsEnabled $true -ExpiryTime (Get-Date).AddYears(10) -Force

                            Write-Output "DONE"
                            Write-Output " "
                        }
                        catch
                        {
                            throw "Error create import runbooks Error: $_."
                        }

                    #endregion

                    #region create azure keyvault secrets

                        try {
                            
                            try {
                                
                                if($keyvaultmappingtool -eq $null)
                                {
                                    throw "Error create keyVault"
                                }
                                else {
                                    Write-Output "Add WebhookAdd to KeyVault"
                                    $secretwebhookaad = Set-AzKeyVaultSecret -VaultName $keyvaultmappingtool.VaultName `
                                                                            -Name $aadwebhook.Name `
                                                                            -SecretValue (ConvertTo-SecureString ($aadwebhook.WebhookURI).ToString() -AsPlainText -Force)
                                    
                                    Write-Output "DONE"
                                    Write-Output " "
                            
                                    #Write-Output "Add WebhookAADCH to KeyVault"                                                
                                    #$secretwebhookaadch = Set-AzKeyVaultSecret -VaultName $keyvaultmappingtool.VaultName `
                                    #                                        -Name $aadwchebhook.Name `
                                    #                                        -SecretValue (ConvertTo-SecureString ($aadwchebhook.WebhookURI).ToString() -AsPlainText -Force)
                            
                                    #Write-Output "DONE"
                                    #Write-Output " "
                                    
                                    #Write-Output "Add WebhookAADDel to KeyVault"
                                    #$secretwebhookaaddel = Set-AzKeyVaultSecret -VaultName $keyvaultmappingtool.VaultName `
                                    #                                        -Name $aaddelwebhook.Name `
                                    #                                        -SecretValue (ConvertTo-SecureString ($aaddelwebhook.WebhookURI).ToString() -AsPlainText -Force)
                            
                                    #Write-Output "DONE"
                                    #Write-Output " "

                                    Write-Output "Add WebhookRG to KeyVault"
                                    $secretwebhookrg = Set-AzKeyVaultSecret -VaultName $keyvaultmappingtool.VaultName `
                                                                            -Name $rgwebhook.Name `
                                                                            -SecretValue (ConvertTo-SecureString ($rgwebhook.WebhookURI).ToString() -AsPlainText -Force)
                            
                                    Write-Output "DONE"
                                    Write-Output " "
                                    
                                    Write-Output "Add WebhookRGDel to KeyVault"
                                    $secretwebhookrgdel = Set-AzKeyVaultSecret -VaultName $keyvaultmappingtool.VaultName `
                                                                            -Name $rgdelwebhook.Name `
                                                                            -SecretValue (ConvertTo-SecureString ($rgdelwebhook.WebhookURI).ToString() -AsPlainText -Force)    
                                                                                                                            
                                    Write-Output "DONE"
                                    Write-Output " "

                                    Write-Output "Add MappingTool-SubScriptionID to KeyVault"
                                    $kvMappingToolSubscriptionID = Set-AzKeyVaultSecret -VaultName $keyvaultmappingtool.VaultName `
                                                                                        -Name "MappingTool-SubScriptionID" `
                                                                                        -SecretValue (ConvertTo-SecureString ($selectedsubscription).ToString() -AsPlainText -Force)    
                            
                                    Write-Output "DONE"
                                    Write-Output " "

                                    Write-Output "MappingTool-SP-ApplicationID to KeyVault"
                                    $kvMappingToolAppID = Set-AzKeyVaultSecret -VaultName $keyvaultmappingtool.VaultName `
                                                                            -Name "MappingTool-SP-ApplicationID" `
                                                                            -SecretValue (ConvertTo-SecureString ($sp.ApplicationId).ToString() -AsPlainText -Force)
                            
                                    Write-Output "DONE"
                                    Write-Output " "

                                    Write-Output "Add MappingToolSP-secret to KeyVault"
                                    $kvMappingToolAppSecret = Set-AzKeyVaultSecret -VaultName $keyvaultmappingtool.VaultName `
                                                                                -Name "MappingToolSP-secret" `
                                                                                -SecretValue (ConvertTo-SecureString ($sppw).ToString() -AsPlainText -Force)     
                                    
                                    Write-Output "DONE"
                                    Write-Output " "                                            
                                    
                                    Write-Output "Add MappingTool-SP-TenantID to KeyVault"
                                    $kvMappingToolTenantID = Set-AzKeyVaultSecret -VaultName $keyvaultmappingtool.VaultName `
                                                                                -Name "MappingTool-SP-TenantID" `
                                                                                -SecretValue (ConvertTo-SecureString $TenantID -AsPlainText -Force)     
                                    
                                    Write-Output "DONE"
                                    Write-Output " "

                                    Write-Output "Get storage account connection string and add it to Azure KeyVault"
                                    $saKey = (Get-AzStorageAccountKey -ResourceGroupName $deploymentrg.ResourceGroupName -Name $appstorageacc.StorageAccountName)[0].Value

                                    $connectionstring = 'DefaultEndpointsProtocol=https;AccountName=' + $appstorageacc.StorageAccountName + ';AccountKey=' + $saKey + ';EndpointSuffix=core.windows.net' 


                                    Write-Output "DONE"
                                    Write-Output " "

                                    Write-Output "Add MappingTool-SP-TenantID to KeyVault"
                                    $kvsecretstrconnstr = Set-AzKeyVaultSecret -VaultName $keyvaultmappingtool.VaultName `
                                                                               -Name "MappingTool-StrAcc-ConenctionStr" `
                                                                               -SecretValue (ConvertTo-SecureString $connectionstring  -AsPlainText -Force)   
                                                                    

                                    Write-Output "Add MappingTool-LogA-WorkspaceID to KeyVault"
                                    $secretstrconnstr = Set-AzKeyVaultSecret -VaultName $keyvaultmappingtool.VaultName `
                                                                             -Name "MappingTool-LogA-WorkspaceID" `
                                                                             -SecretValue (ConvertTo-SecureString $Workspace.CustomerId  -AsPlainText -Force) 
                                    
                                    Write-Output "DONE"
                                    Write-Output " "  
                                                                   
                                    Write-Output "Add MappingTool-LogA-SharedKey to KeyVault"
                                    $secretstrconnstr = Set-AzKeyVaultSecret -VaultName $keyvaultmappingtool.VaultName `
                                                                             -Name "MappingTool-LogA-SharedKey" `
                                                                             -SecretValue (ConvertTo-SecureString $kvkey -AsPlainText -Force) 
                                    
                                    Write-Output "DONE"
                                    Write-Output " "

                                }
                            }
                            catch {
                                throw "Error create import secrets Error: $_."
                            }
                        }
                        catch {
                            
                        }

                    #endregion

                    #region Create storage table resources         
            
                        try {                                                        

                            Write-Output "Get default config from GitHub"

                                Invoke-WebRequest https://github.com/Lagler-Gruener/Sol-MappingToolDeploy/blob/main/Storage/MappingToolConfig.txt?raw=true -OutFile MappingToolConfig.txt

                                $defsettings = Get-Content -Path .\MappingToolConfig.txt

                                $tableconfig = $appstorageacc | Get-AzStorageTable -Name "cfmappingtool"
                                foreach ($line in $defsettings)
                                {            
                                    Write-Output "Get settings for line"
                                        $splitsettings = $line.Split(";")
                                                        
                                        $varsetting = ""
                                        if($splitsettings[5] -eq "%SubscriptionID%")
                                        {
                                            $varsetting = $selectedsubscription
                                        }
                                        elseif($splitsettings[5] -eq "%AutomationAccount%")
                                        {
                                            $varsetting = $newautomacc.AutomationAccountName
                                        }
                                        elseif($splitsettings[5] -eq "%LogAnalyticsAccount%")
                                        {
                                            $varsetting = "$($ToolName)-loga"
                                        }
                                        elseif($splitsettings[5] -eq "%StorageAccount%")
                                        {
                                            $varsetting = $appstorageacc.StorageAccountName
                                        }
                                        elseif ($splitsettings[5] -eq "%DefTags%") 
                                        {
                                            $varsetting = "CostCenter,"
                                        }
                                        elseif($splitsettings[5] -eq "null")
                                        {
                                            $varsetting = ""
                                        }
                                        else {
                                            $varsetting = $splitsettings[5]
                                        }

                                        Write-Output "Write-Entry $($splitsettings[1])"
                                        
                                        Add-AzTableRow -table $tableconfig.CloudTable `
                                                       -partitionKey $splitsettings[0] `
                                                       -rowKey $splitsettings[1] `
                                                       -property @{
                                                                "AllowtoChange"=$splitsettings[2];
                                                                "Description"=$splitsettings[3];
                                                                "Name"=$splitsettings[4];
                                                                "Value"=$varsetting;
                                                            }
                                }    

                            Write-Output "DONE"
                            Write-Output " "   
                            
                            Write-Output "Write subscription into mapping table"

                                $tablemapping = $appstorageacc | Get-AzStorageTable -Name "cfrolemapping"

                                    Add-AzTableRow -table $tablemapping.CloudTable `
                                                   -partitionKey "SUB" `
                                                   -rowKey $selectedsubscription `
                                                   -property @{
                                                            "SubMapping"="Prod";
                                                        }

                            Write-Output "DONE"
                            Write-Output " "   

                        }
                        catch {
                            throw "Error create storage table resources Error: $($_.Exception.Message)"
                        }

                    #endregion

                    #region Create storage queue resources
                        
                        try {
                                                
                            Write-Output "Create stroage queue m-config-cl"
                                $appstorageacc | New-AzStorageQueue -Name "m-config-cl" 

                            Write-Output "DONE"
                            Write-Output " "

                            Write-Output "Create stroage queue m-config-op"
                                $appstorageacc | New-AzStorageQueue -Name "m-config-op"

                            Write-Output "DONE"
                            Write-Output " "

                            Write-Output "Create stroage queue m-grpmembers-cl"
                                $appstorageacc | New-AzStorageQueue -Name "m-grpmembers-cl" 

                            Write-Output "DONE"
                            Write-Output " "

                            Write-Output "Create stroage queue p-addgrp-cl"
                                $appstorageacc | New-AzStorageQueue -Name "p-addgrp-cl"

                            Write-Output "DONE"
                            Write-Output " "

                            Write-Output "Create stroage queue p-adgrp-op"
                                $appstorageacc | New-AzStorageQueue -Name "p-adgrp-op"

                            Write-Output "DONE"
                            Write-Output " "
                        }
                        catch {
                            throw "Error create storage queue resources Error: $_."
                        }

                    #endregion

                    #region Create Azure WebApp
        
                        try {
                                                    
                            Write-Output "Add Appsettings"
                                $AppSettings = @{
                                            "ConnectionString" = "InstrumentationKey=$($appinsight.InstrumentationKey);IngestionEndpoint=https://westeurope-2.in.applicationinsights.azure.com/";
                                            "APPINSIGHTS_INSTRUMENTATIONKEY" = $appinsight.InstrumentationKey;
                                            "APPINSIGHTS_PROFILERFEATURE_VERSION" = "1.0.0";
                                            "APPINSIGHTS_SNAPSHOTFEATURE_VERSION" = "1.0.0";
                                            "ApplicationInsightsAgent_EXTENSION_VERSION" = "~2";
                                            "DiagnosticServices_EXTENSION_VERSION" = "~3";
                                            "InstrumentationEngine_EXTENSION_VERSION" = "disabled";
                                            "SnapshotDebugger_EXTENSION_VERSION" = "disabled";
                                            "MappingToolAppID" = $kvMappingToolAppID.Id;
                                            "MappingToolAppSecret" = $kvMappingToolAppSecret.Id;
                                            "MappingToolTenantID" = $kvMappingToolTenantID.Id;
                                            "MappingToolSubscriptionID"=$kvMappingToolSubscriptionID.Id;
                                            "KeyVaultStorageKey"=$kvsecretstrconnstr.Id}

                                $webappsettings = Set-AzWebApp -Name $webapp.Name `
                                                            -AppSettings $AppSettings `
                                                            -ResourceGroupName $deploymentrg.ResourceGroupName 

                            Write-Output "DONE"
                            Write-Output " "

                            Write-Output "Create Managed Identiy for WebApp"
                                $webappmi = Set-AzWebApp -AssignIdentity $true `
                                                        -Name $webapp.Name `
                                                        -ResourceGroupName $deploymentrg.ResourceGroupName 

                            Write-Output "DONE"
                            Write-Output " "
                                
                            Start-Sleep -Seconds 10

                            Write-Output "Assign Managed Identity to KeyVault"
                                Set-AzKeyVaultAccessPolicy -VaultName $keyvaultmappingtool.VaultName `
                                                           -ObjectId $webappmi.Identity.PrincipalId `
                                                           -PermissionsToSecrets get, list
        
                            Write-Output "DONE"
                            Write-Output " "

                            Write-Output "Deploy webapp content"
                                $gitwebapprepo="https://github.com/Lagler-Gruener/Sol-MappingToolDeploy.git"

                                $PropertiesObject = @{
                                        repoUrl = "$gitwebapprepo";
                                        branch = "main";
                                        isManualIntegration = "true";
                                    }

                                Set-AzResource -PropertyObject $PropertiesObject -ResourceGroupName $deploymentrg.ResourceGroupName `
                                            -ResourceType Microsoft.Web/sites/sourcecontrols -ResourceName "$($webapp.Name)/web" `
                                            -ApiVersion 2019-08-01 -Force

                            Write-Output "DONE"
                            Write-Output " "

                        }
                        catch {
                            throw "Error configure webapp resources Error: $_."
                        }
                    #endregion

                    #region Create LogicApp(s)

                        try {
                                                            
                            Write-Output "Deploy LogicApp connections"

                            $connectorsgiturl = "https://github.com/Lagler-Gruener/Sol-MappingToolDeploy/blob/main/LogicApp/Connectors/connectors.json?raw=true"
                            $connectordeploystate = New-AzResourceGroupDeployment -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                                                  -TemplateUri $connectorsgiturl `
                                                                                  -subscriptionid $selectedsubscription

                            Write-Output "DONE"
                            Write-Output " "   

                            Write-Output "Deploy LogicApp Monitoring"

                            $monitorgiturl = "https://github.com/Lagler-Gruener/Sol-MappingToolDeploy/blob/main/LogicApp/Monitoring/LogicAppMappingTool-Monitor.json?raw=true"
                            $connectordeploystate = New-AzResourceGroupDeployment -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                                                  -TemplateUri $monitorgiturl `
                                                                                  -subscriptionid $selectedsubscription `
                                                                                  -automationaccname $newautomacc.AutomationAccountName
                            
                            Write-Output "DONE"
                            Write-Output " "   
                                                        
                            Write-Output "Deploy LogicApp Workflow"

                            $monitorgiturl = "https://github.com/Lagler-Gruener/Sol-MappingToolDeploy/blob/main/LogicApp/Workflow/LogicAppMappingTool-Workflow.json?raw=true"
                            $connectordeploystate = New-AzResourceGroupDeployment -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                                                  -TemplateUri $monitorgiturl `
                                                                                  -subscriptionid $selectedsubscription `
                                                                                  -automationaccname $newautomacc.AutomationAccountName

                            Write-Output "DONE"
                            Write-Output " "   
                        }
                        catch {
                            throw "Error createlogicapp resources Error: $_."
                        }

                    #endregion

                    #region Configure LogAnalytics
                        
                        try {
                            #Define global schedule options
                                $schedule = New-AzScheduledQueryRuleSchedule -FrequencyInMinutes 5 -TimeWindowInMinutes 5
                                $triggerCondition = New-AzScheduledQueryRuleTriggerCondition -ThresholdOperator "GreaterThan" -Threshold 0 

                            #region create add grp add alert             
                                Write-Output "Create actiongroup appmtaadgrp"

                                    $webhookaddgroup = New-AzActionGroupReceiver -Name "rcaadgrpadd" `
                                                                                  -WebhookReceiver `
                                                                                  -ServiceUri $aadwebhook.WebhookURI `
                                                                                  -UseCommonAlertSchema

                                    $actgrpaddgrpadd = Set-AzActionGroup -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                                         -Name "$($ToolName)aadgrpadd" `
                                                                         -ShortName "appmtgrpadd" `
                                                                         -Receiver $webhookaddgroup                                                                  

                                Write-Output "DONE"
                                Write-Output " " 

                                Write-Output "Create alert rule for aad group add"

                                    $source = New-AzScheduledQueryRuleSource -Query "AuditLogs
                                                                            | where OperationName == 'Add group'
                                                                            | extend displayName_ = tostring(TargetResources[0].displayName)
                                                                            | extend id_ = tostring(TargetResources[0].id)
                                                                            | extend userPrincipalName_ = tostring(parse_json(tostring(InitiatedBy.user)).userPrincipalName)
                                                                            | where Identity <> '$($sp.DisplayName)'
                                                                            | project OperationName, displayName_, id_, userPrincipalName_" `
                                                                -DataSourceId $Workspace.ResourceId

                                                        
                                    $aznsActionGroup = New-AzScheduledQueryRuleAznsActionGroup -ActionGroup $actgrpaddgrpadd.Id 

                                    $alertingAction = New-AzScheduledQueryRuleAlertingAction -AznsAction $aznsActionGroup -Severity "0" -Trigger $triggerCondition

                                    New-AzScheduledQueryRule -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                            -Location $AppLocation `
                                                            -Action $alertingAction `
                                                            -Enabled $true `
                                                            -Description "Azure AD group add alert rule. Created by mappingtool deployment script" `
                                                            -Schedule $schedule `
                                                            -Source $source `
                                                            -Name "$($ToolName)addgroupadd"
                            
                            #endregion
                                
                            #region create aad grp delete alert


                                Write-Output "Create alert rule for aad group delete"

                                    $source = New-AzScheduledQueryRuleSource -Query "AuditLogs
                                                                                        | where OperationName == 'Delete group'
                                                                                        | extend displayName_ = tostring(TargetResources[0].displayName)
                                                                                        | extend id_ = tostring(TargetResources[0].id)
                                                                                        | extend userPrincipalName_ = tostring(parse_json(tostring(InitiatedBy.user)).userPrincipalName)
                                                                                        | where Identity <> '$($sp.DisplayName)'
                                                                                        | project OperationName, displayName_, id_, userPrincipalName_" `
                                                                            -DataSourceId $Workspace.ResourceId

                                    $aznsActionGroup = New-AzScheduledQueryRuleAznsActionGroup -ActionGroup $webhookaddgroup.Id 

                                    $alertingAction = New-AzScheduledQueryRuleAlertingAction -AznsAction $aznsActionGroup -Severity "0" -Trigger $triggerCondition

                                    New-AzScheduledQueryRule -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                            -Location $AppLocation `
                                                            -Action $alertingAction `
                                                            -Enabled $true `
                                                            -Description "Azure AD group delete alert rule. Created by mappingtool deployment script" `
                                                            -Schedule $schedule `
                                                            -Source $source `
                                                            -Name "$($ToolName)addgroupdel"

                            #endregion

                            #region create aad grp change alert

                                Write-Output "DONE"
                                Write-Output " " 

                                Write-Output "Create alert rule for aad group change"

                                    $source = New-AzScheduledQueryRuleSource -Query "AuditLogs                                     
                                                                                        | where OperationName == 'Add member to group' or OperationName == 'Remove member from group'
                                                                                        | extend displayName_ = tostring(TargetResources[0].displayName)
                                                                                        | extend id_ = tostring(TargetResources[0].id)
                                                                                        | extend userPrincipalName_ = tostring(parse_json(tostring(InitiatedBy.user)).userPrincipalName)
                                                                                        | where Identity <> '$($sp.DisplayName)'
                                                                                        | project OperationName, displayName_, id_, userPrincipalName_" `
                                                                            -DataSourceId $Workspace.ResourceId

                                    $aznsActionGroup = New-AzScheduledQueryRuleAznsActionGroup -ActionGroup $webhookaddgroup.Id 

                                    $alertingAction = New-AzScheduledQueryRuleAlertingAction -AznsAction $aznsActionGroup -Severity "0" -Trigger $triggerCondition

                                    New-AzScheduledQueryRule -ResourceGroupName $deploymentrg.ResourceGroupName `
                                                            -Location $AppLocation `
                                                            -Action $alertingAction `
                                                            -Enabled $true `
                                                            -Description "Azure AD group change alert rule. Created by mappingtool deployment script" `
                                                            -Schedule $schedule `
                                                            -Source $source `
                                                            -Name "$($ToolName)addgroupch"
                            
                            #endregion
                        
                        }
                        catch {
                            throw "Error configure logicapp resources. Error: $_."
                        }
                    #endregion

                    #region create event subscriptions

                    try {
                             
                        Write-Output "Register Resource provider Microsoft.EventGrid"
                            Register-AzResourceProvider -ProviderNamespace "Microsoft.EventGrid"

                            $registered = $false

                            do {
                                if ((Get-AzResourceProvider -Location $AppLocation | where {$_.ProviderNamespace -eq "Microsoft.EventGrid"}).RegistrationState -eq "Registered") {
                                    $registered = $true    
                                }

                            } until ($registered)                            

                        Write-Output "Create event subscription 'add event'"

                            $includedEventTypes = "Microsoft.Resources.ResourceWriteSuccess"
                            $AdvFilter1=@{operator="StringIn"; key="data.operationName"; Values=@('Microsoft.Resources/subscriptions/resourceGroups/write','Microsoft.Resources/tags/write')} 
                            
                            $rgeventsubrgadd = New-AzEventGridSubscription -EventSubscriptionName "$($ToolName)-event-rg-add" `
                                                                           -EndpointType webhook `
                                                                           -Endpoint $($rgwebhook.WebhookURI) `
                                                                           -IncludedEventType $includedEventTypes `
                                                                           -AdvancedFilter @($AdvFilter1) `
                                                                           -ResourceGroupName $($deploymentrg.ResourceGroupName)
                            
                        Write-Output "DONE"
                        Write-Output " "                                          
                        

                        Write-Output "Create event subscription 'delete event'"

                            $includedEventTypes = "Microsoft.Resources.ResourceDeleteSuccess"
                            $AdvFilter1=@{operator="StringIn"; key="data.operationName"; Values=@('Microsoft.Resources/subscriptions/resourcegroups/delete')} 
                                                                                                
                            $rgeventsubrgdelete = New-AzEventGridSubscription -EventSubscriptionName "$($ToolName)-event-rg-delete" `
                                                                              -EndpointType webhook `
                                                                              -Endpoint $($rgdelwebhook.WebhookURI) `
                                                                              -IncludedEventType $includedEventTypes `
                                                                              -AdvancedFilter @($AdvFilter1) `
                                                                              -ResourceGroupName $($deploymentrg.ResourceGroupName)
                        Write-Output "DONE"
                        Write-Output " " 
                    }
                    catch {
                        throw "Error configure eventsubscription resources. Error: $_."                                             
                    }                                                                                

                    #endregion

                    #region enable azure ad diagnostic settings

                    Write-Output "Enable AzureAD audit diagnostic settings for MappingTool"

                    try {
                        
                        $workspaceName = $workspace.Name
                        $ruleName = "MappingToolLogging"
                        $workspaceId = $($workspace.ResourceId)

#setup diag settings
$uri = "https://management.azure.com/providers/microsoft.aadiam/diagnosticSettings/{0}?api-version=2017-04-01-preview" -f $ruleName
$body = @"
{
    "id": "providers/microsoft.aadiam/diagnosticSettings/$ruleName",
    "type": null,
    "name": "Log Analytics",
    "location": null,
    "kind": null,
    "tags": null,
    "properties": {
      "storageAccountId": null,
      "serviceBusRuleId": null,
      "workspaceId": "$workspaceId",
      "eventHubAuthorizationRuleId": null,
      "eventHubName": null,
      "metrics": [],
      "logs": [
        {
          "category": "AuditLogs",
          "enabled": true,
          "retentionPolicy": { "enabled": false, "days": 0 }
        }
      ]
    },
    "identity": null
  }
"@

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}
$response = Invoke-WebRequest -Method Put -Uri $uri -Body $body -Headers $headers

if ($response.StatusCode -ne 200) {
    throw "an error occured: $($response | out-string)"

}
                    }
                    catch {
                        throw "Error configure AzureAD diagnostic settings. Error: $_."   
                    }

                    #endregion


                    Write-Output "-----------------------------------------------------------------------"
                    Write-Output "                                                                       "
                    Write-Output "                         Deployment succede                            "
                    Write-Output "                                                                       "
                    Write-Output "-----------------------------------------------------------------------"
                    Write-Output " "
                    Write-Output "Next steps are:"
                    Write-Output "1.) Start the automated Hybridworker deployment described here (IMPORTANT open the Powershell in ADMIN Mode)"
                    Write-Output "    https://docs.microsoft.com/en-us/azure/automation/automation-windows-hrw-install#automated-deployment"
                    Write-Output " "
                    Write-Output "The NewOnPremiseHybridWorkerParameters are:"
                    Write-Output "-------------------------------------------"
                    Write-Output " "
                    Write-Output "-AutomationAccountName: $($newautomacc.AutomationAccountName)"
                    Write-Output "-AAResourceGroupName: $($deploymentrg.ResourceGroupName)"
                    Write-Output "-OMSResourceGroupName: $($deploymentrg.ResourceGroupName)"
                    Write-Output "-HybridGroupName: MappingTool"
                    Write-Output "-SubscriptionID: $selectedsubscription"
                    Write-Output "-WorkspaceName: $($Workspace.Name)"
                    Write-Output " "
                    Write-Output "-------------------------------------------"                                            
                    Write-Output "2.) Configure the web application "
                    Write-Output "    https://$($webapp.HostNames[0]))"
                    Write-Output " "
                    Write-Output "5.) Assign identity to the Logic App"
                    Write-Output "      -LogicAppMappingTool-Monitor"
                    Write-Output "      -LogicAppMappingTool-Workflow"
                }
                catch {
                    
                }

        #endregion        

    }
    else {
        Write-Output "Wrong Subscription selected!"
    }
}
catch {
    Write-Output "Error in deployment, deployment rollback is starting. Error: $($_)"

    $rollback = Read-Host -Prompt "Start rollback? yes/no [Default=yes]"

    if($rollback -eq "no")
    {
        Write-Output "Exit script without rollback."
    }
    elseif (($rollback -eq "yes") -or ($rollback -eq "")) {
        Write-Output "Rollback configuration"

        Remove-AzResourceGroup -Name $deploymentrg.ResourceGroupName -Force

        Write-Output "Please open the Azure Cloudshell and execute tho following command:"
        Write-Output " "
        Write-Output "az keyvault purge --name $($keyvaultmappingtool.VaultName) --location '$($AppLocation)' --no-wait --subscription $($selectedsubscription)"

        Remove-AzADServicePrincipal -ObjectId $sp.Id -Force
        Remove-AzADServicePrincipal -DisplayName "SP-$($ToolName)-RunasAccount" -Force

        Remove-AzEventGridSubscription -EventSubscriptionName $rgeventsubrgadd.EventSubscriptionName
        Remove-AzEventGridSubscription -EventSubscriptionName $rgeventsubrgdelete.EventSubscriptionName

        Write-Output "-----------------------------------------------------------------------"
        Write-Output "                                                                       "
        Write-Output "                     Rollback finished                                 "
        Write-Output "                                                                       "
        Write-Output "-----------------------------------------------------------------------"
    }
    #OFFEN
}