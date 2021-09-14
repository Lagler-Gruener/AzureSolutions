<#
    .SYNOPSIS
        Azure VM vnet change
        
    .DESCRIPTION
        That script give you the ability to change the virtual network for an Azure VM
        
    .EXAMPLE
        none
        
    .NOTES  
        The latest version of AZ models are required
        
#>

#[CmdletBinding()]
#param (
#    [Parameter()]
#    [TypeName]
#    $ParameterName
#)

#######################################################################################################################
#region define global variables

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#endregion
#######################################################################################################################

#######################################################################################################################
#region Functions

#login to azure and get access token
function Login-Azure()
{
    try 
    {
        if(-not (Get-Module Az.Accounts)) {
            Import-Module Az.Accounts
        }
    
        Connect-AzAccount               
    }
    catch {
        Write-Error "Error in function Login-Azure. Error message: $($_.Exception.Message)"
    }
}

#endregion
#######################################################################################################################


#######################################################################################################################
#region Script start

    Write-Host "Connect to Azure"
    Login-Azure

    #region section select subscription
    try 
    {            
        $subscriptions = Get-AzSubscription

        if (($subscriptions).count -gt 0)
        {
            Write-Host "#######################################################################"
            Write-Host "There are more subscription available:"

            $count = 0
            foreach ($subscription in $subscriptions) 
            {
                Write-Host "$($count): $($subscription.Name)"
                $count++
            }

            Write-Host "Please select the right subscription (insert the number)"
            Write-Host "#######################################################################"
            $result = Read-Host

            $selectedsubscription = $subscriptions[$result]
            Select-AzSubscription -SubscriptionObject $selectedsubscription

            clear

            Write-Host "#######################################################################"
            Write-Host "Please select the VM where you want to change the VNET:"

            $vmcount = 0
            $VMs = Get-AzVM

            foreach($VM in $VMs)
            {
                Write-Host "$($vmcount): $($VM.Name)"
                $vmcount++
            }

            Write-Host "Please select the right VM (insert the number)"
            Write-Host "#######################################################################"

            $vmresult = Read-Host

            $selectedvm = $VMs[$vmresult]            

            if($selectedvm.NetworkProfile.NetworkInterfaces.Count -gt 1)
            {
                clear 
                Write-Host "VM have more the one NIC attached."
                break
            }

            $existnetworkinterface = Get-AzNetworkInterface -ResourceId $selectedvm.NetworkProfile.NetworkInterfaces[0].Id

            clear

            Write-Host "#######################################################################"
            Write-Host "Please select the destination VNET:"

            $vnetcount = 0
            $VNets = Get-AzVirtualNetwork

            foreach($VNet in $VNets)
            {
                Write-Host "$($vnetcount): $($VNet.Name)"
                $vnetcount++
            }

            Write-Host "Please select the right VNet (insert the number)"
            Write-Host "#######################################################################"
            $vnetresult = Read-Host

            $selectedvnet = $VNets[$vnetresult]

            clear

            Write-Host "#######################################################################"
            Write-Host "Please select the destination Subnet:"

            $subnetcount = 0
            $Subnets = $selectedvnet.Subnets

            foreach($Subnet in $Subnets)
            {
                Write-Host "$($subnetcount): $($Subnet.Name)"
                $subnetcount++
            }

            Write-Host "Please select the right Subnet (insert the number)"
            Write-Host "#######################################################################"
            $subnetresult = Read-Host

            $selectedsubnet = $Subnets[$subnetresult]

            clear

            Write-Host "#######################################################################"
            Write-Host "Overview about the changes"
            Write-Host " "
            Write-Host "VM: $($selectedvm.Name)"
            Write-Host "To VNet: $($selectedvnet.Name)"
            Write-Host "To Subnet: $($selectedsubnet.Name)"
            Write-Host " "                    
            Write-Host "#######################################################################"
            Write-Host "Are the changes correct?"
            Write-Host "Keep in mind, the VM will be down for a few seconds!"
            Write-Host " "

            $submitresult = Read-Host "Yes/No"

            if($submitresult.ToLower() -eq "yes")
            {
                Write-Host "Stop VM"
                    Stop-AzVM -Name $selectedvm.Name -ResourceGroupName $selectedvm.ResourceGroupName -Force

                Write-Host "Remove VM"
                    Remove-AzVm -Name $selectedvm.Name -ResourceGroupName $selectedvm.ResourceGroupName -Force

                Write-Host "Remove network interface"
                    Remove-AzNetworkInterface -Name $existnetworkinterface.Name -ResourceGroupName $existnetworkinterface.ResourceGroupName -Force                
 
                Write-Host "Create VM"                
                    $NIC = New-AzNetworkInterface -Name $existnetworkinterface.Name -ResourceGroupName $existnetworkinterface.ResourceGroupName -Location $existnetworkinterface.Location -SubnetId $selectedsubnet.Id
                    $VirtualMachine = New-AzVMConfig -VMName $selectedvm.Name -VMSize $selectedvm.HardwareProfile.VmSize            

                    if ($selectedvm.StorageProfile.OsDisk.OsType -eq "Windows")
                    {
                        $VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $selectedvm.StorageProfile.OsDisk.ManagedDisk.id -CreateOption Attach -Windows
                    }
                    elseif ($selectedvm.StorageProfile.OsDisk.OsType -eq "Linux") {
                        $VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $selectedvm.StorageProfile.OsDisk.ManagedDisk.id -CreateOption Attach -Linux
                    }
                    
                    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id

                    New-AzVM -ResourceGroupName $selectedvm.ResourceGroupName `
                            -Location $selectedvm.Location `
                            -VM $VirtualMachine `
                            -Verbose                         
            }
            else {
                Write-Host "The process cancled"
            }

        }
        else 
        {
            $selectedsubscription = $subscriptions[0]
            Select-AzSubscription -SubscriptionObject $selectedsubscription
        }
    }
    catch {
        Write-Error "Error in select subscription section. Error message: $($_.Exception.Message)"
    }

    #endregion

#endregion
#######################################################################################################################
