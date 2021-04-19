param(
  $workspaceName = "AppMTLogAb76b5ab98b0a464",
  $ruleName = "Log Analytics ($workspaceName)"
)

Import-Module Az
Login-AzAccount


# Find the ResourceId for the Log Analytics workspace

$workspaceResource = Get-AzResource -ResourceType "Microsoft.OperationalInsights/workspaces" -Name $workspaceName
$workspaceId = $workspaceResource.ResourceId
function Get-AzCachedAccessToken()
{
    $ErrorActionPreference = 'Stop'

    $azureRmProfileModuleVersion = (Get-Module Az.Profile).Version
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azureRmProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."    
    }
  
    $currentAzureContext = Get-AzContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}
$token = Get-AzCachedAccessToken

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
        },
        {
          "category": "SignInLogs",
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