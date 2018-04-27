$servers = "localhost"
#Run the commands for each server in the list
$infoColl = @()

Foreach ($s in $servers)
{
	$CPUInfo = Get-WmiObject Win32_Processor -ComputerName $s #Get CPU Information
	$OSInfo = Get-WmiObject Win32_OperatingSystem -ComputerName $s #Get OS Information
	#Get Memory Information. The data will be shown in a table as MB, rounded to the nearest second decimal.
	$OSTotalVirtualMemory = [math]::round($OSInfo.TotalVirtualMemorySize / 1MB, 2)
	$OSTotalVisibleMemory = [math]::round(($OSInfo.TotalVisibleMemorySize / 1MB), 2)
	$PhysicalMemory = Get-WmiObject CIM_PhysicalMemory -ComputerName $s | Measure-Object -Property capacity -Sum | % { [Math]::Round(($_.sum / 1GB), 2) }
    $IPAddress = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $s |where {($_.DefaultIPGateway -ne $null) -and ($_.DefaultIPGateway -like "*.*")}).IPAddress
	Foreach ($CPU in $CPUInfo)
	{

		$infoObject = New-Object PSObject -Property @{            
			ServerName					= $CPU.SystemName
			Processor					= $CPU.Name
			IP_Address					= $IPAddress.toString()
			Model						= $CPU.Description
			Manufacturer				= $CPU.Manufacturer
			PhysicalCores				= $CPU.NumberOfCores
			LogicalCores				= $CPU.NumberOfLogicalProcessors
			OS_Name						= $OSInfo.Caption
			OS_Version					= $OSInfo.Version
			Memory						= $PhysicalMemory
		}               

		$infoObject #Output to the screen for a visual feedback.
		$infoColl += $infoObject
	}
}
$infoColl | Export-Csv -path .\Server_Inventory_$((Get-Date).ToString('MM-dd-yyyy')).csv -NoTypeInformation #Export the results in csv file.