<#

\\192.168.21.67\Scripts\Capital
\\192.168.21.67\Scripts\Financial Reporting
\\192.168.21.67\Scripts\MDV
\\192.168.21.67\Scripts\NBAV
\\192.168.21.67\Scripts\Pricing
\\192.168.21.67\Scripts\Project Actuary

#>

$monitoredFolders = Import-Csv .\sshmatrix.csv
$transferedFolder = "D:\Testing\Transfered"

function Move-Files($path, $name)
{
    Write-Host "I would copy '$path' this "
}

$folder = '\\192.168.21.67\Scripts' # Enter the root path you want to monitor.
$filter = '*.*'  # You can enter a wildcard filter here.

# On startup, we need to check to see if any files were previously missed

foreach($folder in $monitoredFolders)
{
    $existingItems = Get-ChildItem -Path $folder.source
    foreach($item in $existingItems)
    {
        Write-Host "Found" $item.FullName -ForegroundColor Yellow
        Move-Files($item.FullName,$folder.destinationpath)

        try {
            $Password = ConvertTo-SecureString 'Password!' -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ('sovereign', $Password)

            Import-Module Posh-SSH
            $newSSHSession = New-SFTPSession -ComputerName $folder.destinationserver -Credential $Credential

            Write-Host "Copying" $item.FullName "to" $folder.destinationserver
            $SftpPath = "/"+$folder.destinationpath
            $result = Set-SFTPFile -SessionId ($newSSHSession).SessionId -LocalFile $item.FullName -RemotePath $SftpPath

            $result | Out-File -FilePath d:\testing\transmit.log -Append
            Write-Host "Disconnecting from" $folder.destinationserver
            Remove-SFTPSession -SessionId ($newSSHSession).SessionId

            $count = 1;
            $fullpath = $transferedFolder+"\"+$item.Name

            # check if the path exists, and if it does increment in ones until we find a filename
            Write-Host $fullpath
            if(Test-Path $fullpath)
            {
                do
                {
                    $filenumber = $count.ToString()+"-"+$item.Name
                    $fullpath = $transferedFolder+"\"+$filenumber
                    $count++
                    $fullpath
                } while(Test-Path $fullpath)
            }

            Write-Host "Found valid destination name" $fullpath
            Move-Item $item.FullName -Destination $fullpath -Verbose
        }
        catch {
            $_ |Out-File -FilePath d:\testing\verboseout.log -Append           
        }

    }
}

<#
 # This section puts the hooks in using the .NET api
 #>

$result = @($monitoredFolders.source | ? { Test-Path -Path $_ } | % {

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
        $transferedFolder = "D:\Testing\Transfered"


        try {
            $FilePath = Split-Path $path -Parent;
            $FileName = Split-Path $path -Leaf;
            $folderID = Split-Path $FilePath -Leaf

            $monitoredFolders = Import-Csv .\sshmatrix.csv
            $connectionDetails = $monitoredFolders |Where-Object {$_.destinationpath -eq $folderID}

            $monitoredFolders |Out-File -FilePath d:\testing\out.log;
            $connectionDetails |Out-File -FilePath d:\testing\out.log -Append;

            Write-Host "The file '$FileName' from '$FilePath' was $changeType at $timeStamp with $folderID";
            Write-Host "Connecting to SFTP server" $connectionDetails.destinationserver
            $Password = ConvertTo-SecureString 'Password!' -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ('sovereign', $Password)

            Import-Module Posh-SSH
            $newSSHSession = New-SFTPSession -ComputerName $connectionDetails.destinationserver -Credential $Credential

            Write-Host "Copying" $path "to" $connectionDetails.destinationserver
            $SftpPath = "/"+$connectionDetails.destinationpath
            $result = Set-SFTPFile -SessionId ($newSSHSession).SessionId -LocalFile $path -RemotePath $SftpPath

            $result | Out-File -FilePath d:\testing\transmit.log;
            Write-Host "Disconnecting from" $connectionDetails.destinationserver
            Remove-SFTPSession -SessionId ($newSSHSession).SessionId

            $count = 1;
            $fullpath = $transferedFolder+"\"+$FileName

            # check if the path exists, and if it does increment in ones until we find a filename
            Write-Host $fullpath
            if(Test-Path $fullpath)
            {
                do
                {
                    $filenumber = $count.ToString()+"-"+$FileName
                    $fullpath = $transferedFolder+"\"+$filenumber
                    $count++
                    $fullpath
                } while(Test-Path $fullpath)
            }

            Write-Host "Found valid destination name" $fullpath "from" $path
            Move-Item $path -Destination $fullpath -Verbose
        }
        catch {
            $_ |Out-File -FilePath d:\testing\verboseout.log -Append           
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