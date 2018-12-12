[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)] [string] $ImageName,
    [Parameter(Mandatory = $true)] [string] $GroupNameList,
	[Parameter(Mandatory = $true)] [string] $UserList
)
Add-PSSnapin Citrix.*
$IdPoolName= $ImageName	
$ProvSchemeName =$IdPoolName
$GroupNameArray = $GroupNameList.Split(",")
$UserListArray = $UserList.Split(",")


$MachineCount = $GroupNameArray.Count
$MachineArray = New-Object -TypeName System.Collections.ArrayList

$LogOBJ = Start-LogHighLevelOperation  -AdminAddress $ddc -Source "Studio"  -Text "Add Computer"

$adAccounts = New-AcctADAccount -IdentityPoolName $IdPoolName -Count $MachineCount

$vms = New-ProvVm -ProvisioningSchemeName $ProvSchemeName -ADAccountName $adAccounts.SuccessfulAccounts

$Catalog = Get-BrokerCatalog -Name $ProvSchemeName

foreach ($ADAccount in $vms.CreatedVirtualMachines)
{
    New-BrokerMachine -MachineName $ADAccount.ADAccountSid -CatalogUid $Catalog.Uid
    $MachineArray.Add($ADAccount.IdentityPoolName)
}

Stop-LogHighLevelOperation -HighLevelOperationId $LogOBJ.Id -IsSuccessful $True

for($i=0;$i -lt $MachineCount;$i++)
{
    $NumDesktops = 1
    $peakPoolSize = 2
    $SrcCatalog = $ProvSchemeName 
    $weekendPoolSizeByHour = new-object int[] 24
    $weekdayPoolSizeByHour = new-object int[] 24
    9..17 | %{ $weekdayPoolSizeByHour[$_] = $peakPoolSize } 
    $peakHours = (0..23 | %{ $_ -ge 9 -and $_ -le 17 })
    $logId = Start-LogHighLevelOperation -Text "Create PvD desktop group" `
        -Source "Create PvD Desktop Group Script" 

    $grp = New-BrokerDesktopGroup  -DesktopKind 'Private'  -DeliveryType 'DesktopsOnly'  -LoggingId $logId.Id -Name $GroupNameArray[$i].ToString() -PublishedName $GroupNameArray[$i].ToString() -SessionSupport 'SingleSession' -ShutdownDesktopsAfterUse $False
    
    $grp = Get-BrokerDesktopGroup  -Name $GroupNameArray[$i].ToString()

    $count = Add-BrokerMachinesToDesktopGroup -Catalog $SrcCatalog -Count $NumDesktops -DesktopGroup $GroupNameArray[$i].ToString() -LoggingId $logId.Id
    
    New-BrokerAssignmentPolicyRule -DesktopGroupUid $grp.Uid -Enabled $True -IncludedUserFilterEnabled $False -LoggingId $logId.Id -MaxDesktops 1 -Name ($GroupNameArray[$i].ToString() + '_AssignRule') | Out-Null
    
    New-BrokerAccessPolicyRule -AllowedConnections 'NotViaAG' -AllowedProtocols @('HDX','RDP') -AllowedUsers 'Filtered' -AllowRestart $True -DesktopGroupUid $grp.Uid -Enabled $True -IncludedSmartAccessFilterEnabled $True -IncludedUserFilterEnabled $True  -IncludedUsers $UserListArray[$i].ToString() -LoggingId $logId.Id -Name ($GroupNameArray[$i].ToString() + '_Direct') | Out-Null
	
    New-BrokerAccessPolicyRule  -AllowedConnections 'ViaAG' -AllowedProtocols @('HDX','RDP') -AllowedUsers 'Filtered' -AllowRestart $True -DesktopGroupUid $grp.Uid -Enabled $True -IncludedSmartAccessFilterEnabled $True -IncludedSmartAccessTags @() -IncludedUserFilterEnabled $True -IncludedUsers $UserListArray[$i].ToString() -LoggingId $logId.Id -Name ($GroupNameArray[$i].ToString() + '_AG') | Out-Null
    
    New-BrokerPowerTimeScheme -DaysOfWeek 'Weekdays' -DesktopGroupUid $grp.Uid -DisplayName 'Weekdays' -LoggingId $logId.Id -Name ($GroupNameArray[$i].ToString() + '_Weekdays') -PeakHours $peakHours -PoolSize $weekdayPoolSizeByHour | Out-Null 
    
    New-BrokerPowerTimeScheme  -DaysOfWeek 'Weekend'  -DesktopGroupUid $grp.Uid -DisplayName 'Weekend' -LoggingId $logId.Id  -Name ($GroupNameArray[$i].ToString() + '_Weekend')  -PeakHours $peakHours -PoolSize $weekendPoolSizeByHour | Out-Null	
    
    Stop-LogHighLevelOperation  -HighLevelOperationId $logId.Id -IsSuccessful $True 
}

