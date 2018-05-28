#By BigTeddy 05 September 2011

#This script uses the .NET FileSystemWatcher class to monitor file events in folder(s).
#The advantage of this method over using WMI eventing is that this can monitor sub-folders.
#The -Action parameter can contain any valid Powershell commands.  I have just included two for example.
#The script can be set to a wildcard filter, and IncludeSubdirectories can be changed to $true.
#You need not subscribe to all three types of event.  All three are shown for example.
# Version 1.1


<#

\\192.168.21.67\Scripts\Capital
\\192.168.21.67\Scripts\Financial Reporting
\\192.168.21.67\Scripts\MDV
\\192.168.21.67\Scripts\NBAV
\\192.168.21.67\Scripts\Pricing
\\192.168.21.67\Scripts\Project Actuary

#>

$monitoredFolders = Import-Csv .\sshmatrix.csv

function Move-Files($path, $name)
{
    Write-Host "I would copy '$path' this "
}

$folder = '\\192.168.21.67\Scripts' # Enter the root path you want to monitor.
$filter = '*.*'  # You can enter a wildcard filter here.

$result = @($monitoredFolders.Source | ? { Test-Path -Path $_ } | % {

    $dir = $_;
    
    $fsw = New-Object IO.FileSystemWatcher $dir, $filter -Property @{
        IncludeSubdirectories = $false
        NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'
    };
    
    $sourceIdentifier = $_ -split "\\" 
    $sourceIdentifier = $sourceIdentifier[$sourceIdentifier.Count-1] -replace " ",""
    Write-Host "Configuring source identifier '$sourceIdentifier'"
    #Write-Host "$sourceIdentifier"
    $oc = Register-ObjectEvent $fsw Created -SourceIdentifier $sourceIdentifier -Action {
    
        $path = $Event.SourceEventArgs.FullPath;
        $name = $Event.SourceEventArgs.Name;
        $changeType = $Event.SourceEventArgs.ChangeType;
        $timeStamp = $Event.TimeGenerated;

        Write-Host "The file '$name' from '$path' was $changeType at $timeStamp";
        if($changeType -eq "Created")
        {
            Move-Files($path,$name)
        }
    };

    new-object PSObject -Property @{ Watcher = $fsw; OnCreated = $oc };
    
    });

    <# to remove the fsw subscriptions, run the below.
    
    unregister-event Capital
    unregister-event FinancialReporting
    unregister-event MDV
    unregister-event NBAV
    unregister-event Pricing
    unregister-event ProjectActuary

    #>

# In the following line, you can change 'IncludeSubdirectories to $true if required.                          

<# Here, all three events are registerd.  You need only subscribe to events that you need:

$fsw = New-Object IO.FileSystemWatcher $folder, $filter -Property @{IncludeSubdirectories = $false;NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'}



Register-ObjectEvent $fsw Created -SourceIdentifier FileCreated -Action {
    $name = $Event.SourceEventArgs.Name
    $path = $Event.SourceEventArgs.FullPath
    $changeType = $Event.SourceEventArgs.ChangeType
    $timeStamp = $Event.TimeGenerated
    Write-Host $Event.SourceEventArgs
    Write-Host "The file '$name' was $changeType at $timeStamp. Full path here: '$path'" -fore green
    Out-File -FilePath c:\scripts\filechange\outlog.txt -Append -InputObject "The file '$name' was $changeType at $timeStamp"
}

Register-ObjectEvent $fsw Deleted -SourceIdentifier FileDeleted -Action {
    $name = $Event.SourceEventArgs.Name
    $changeType = $Event.SourceEventArgs.ChangeType
    $timeStamp = $Event.TimeGenerated
    Write-Host "The file '$name' was $changeType at $timeStamp" -fore red
    Out-File -FilePath c:\scripts\filechange\outlog.txt -Append -InputObject "The file '$name' was $changeType at $timeStamp"
}

Register-ObjectEvent $fsw Changed -SourceIdentifier FileChanged -Action {
    $name = $Event.SourceEventArgs.Name
    $changeType = $Event.SourceEventArgs.ChangeType
    $timeStamp = $Event.TimeGenerated
    Write-Host "The file '$name' was $changeType at $timeStamp" -fore white
    Out-File -FilePath c:\scripts\filechange\outlog.txt -Append -InputObject "The file '$name' was $changeType at $timeStamp"
}

<# To stop the monitoring, run the following commands:

Unregister-Event FileDeleted
Unregister-Event FileCreated
Unregister-Event FileChanged


$subscribedEvents = Get-EventSubscriber 
foreach($event in $subscribedEvents) {
    unregister-event -SubscriptionId $event.SubscriptionId
}
#>