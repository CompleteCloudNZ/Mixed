$computers = get-content .\servers.txt
$firsttwo = "192.168"

foreach($computer in $computers)
{
    Write-Host $computer
    $NICs = Get-WMIObject Win32_NetworkAdapterConfiguration -computername $computer  |Where-Object{$_.IPEnabled -eq “TRUE”}
    foreach($NIC in $NICs) 
    {
        if($NIC.IPAddress -match $firsttwo)
        {
            $DNSServers = "192.168.50.10","192.168.51.10"
            $NIC
            $NIC.SetDNSServerSearchOrder($DNSServers)
            $NIC.SetDynamicDNSRegistration("TRUE")
        }
    }
}