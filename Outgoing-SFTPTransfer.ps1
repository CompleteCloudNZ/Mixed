<#
# per-environment variables listed below. These will typically be different between DEV, FST etc
#
# NOT COMPLETE
#
#>

$monitoredFolders = Import-Csv .\sshmatrix-outgoing.csv
$environment = "DEV"
$remoteUser = ""
$logFolder = ".\logs\"
$eventID = "7249"
$passwordFile = ".\" + $remoteUser + ".txt"

$debugEventLog = $true
$skipStartupChecks = $true

<#
# The below checks for the presence of the event log information.
# If it does not exist, it creates it using teh $environment variable able as a prefix
#>

$eventSource = $environment + "_" + "SFTP_Outgoing"
if (!([System.Diagnostics.EventLog]::SourceExists($eventSource)))
{
    New-EventLog -LogName "Application" -Source $eventSource
}

Import-Module .\Posh-SSH.psd1

function Write-SFTPLogs($msg)
{
    if($textLog) { $msg | Out-File -FilePath "$($logFolder)$(Get-Date -Format yyyyMMdd)-incoming-connections.log" -Append }
    if ($debugEventLog) { Write-eventlog -LogName Application -message $msg -Source $eventSource -EventId $eventID }
    Write-Host $msg
}


# On startup, we need to check to see if any files were previously missed

while ($true)
{
    foreach ($folder in $monitoredFolders)
    {

        <#
        # This section checks for any files using the incoming csv $monitoredFolders source column
        #
        # If no file is found, the foreach statement following will not be initiated and the script will move onto the next location
        # If a file is found, the foreach statement will be undertaken
        #>

        $existingItems = Get-ChildItem -Path $folder.source -Recurse -File
        $existingItems
        foreach ($item in $existingItems) 
        {
            try {
                <# here we build some dynamic variables from the discovered files for use within the script #>
                $path = $item.FullName
                Write-Host $path -ForegroundColor Red
                $FilePath = Split-Path $path -Parent;
                $FileName = Split-Path $path -Leaf;
                $folderID = Split-Path $FilePath -Leaf

                <# Read the password from the encoded text file and build the connection credentials #>
                $Password = Get-Content $passwordFile |ConvertTo-SecureString
                $Credential = New-Object System.Management.Automation.PSCredential ($remoteUser, $Password)
                $subfolder = ""
                Write-Host $FilePath " = filepath"

                <#
                # Split the Full Path at the ToPMCS folder.
                # This give us a path varaible, stored in $folderPathName containing any subfolder information
                # This also gives us the section preceeding "ToPCMS" to lookup from the CSV file to discover the destination details
                #>

                $subfolder = ($FilePath -split "ToPMCS")[1] -replace "\","/"
                $newSSHSession = New-SFTPSession -ComputerName $folder.sourceserver -Credential $Credential
                <# 
                # Lookup all child items within the SFTP source location
                # Store the details of the discovered files in $responsefiles variable
                #>
                $sftlocation = "/" + $folder.sourcepath + "/"
                $responsefiles = Get-SFTPChildItem -SessionId $newSSHSession.SessionId -Recursive -Path $sftlocation 
                <# Loop through each discovered file #>
                foreach ($file in $responsefiles) 
                {
                    <# 
                    # First we check to see if the file we have encountered is a folder.
                    #
                    # This is to allow us to handle it differently. Folders are NOT downloaded, they are created locally.
                    #>

                    if ($file.Length -eq "-1") 
                    {
                        <#
                        # Split the Full Path at the ToSov folder. 
                        # This give us a path varaible, stored in $folderPathName containing any subfolder information
                        #>

                        $folderPathName = $folder.destination + ($file.FullName -split "ToSov")[1] -replace "/", "\"
                        <# 
                        # Next we test to see if the destination path, including subfolders exists. 
                        # If it doesn't, use New-Item to create it
                        #> 

                        if (!(Test-Path $folderPathName)) 
                        {
                            Write-SFTPLogs((Get-Date).ToString() + " - Creating FOLDER " + $folderPathName)

                            New-SFTPItem -ItemType directory -Path $folderPathName
                        }
                    }
                    else <# The file is a file, not a folder #> 
                    {
                        Write-SFTPLogs((Get-Date).ToString() + " - " + $endFile + " is a valid file, transferring.")

                        $subfolderPath = ($file.FullName -split "ToPMCS")[1] -replace "\", "/" 
                        $subfolderParent = Split-Path $subfolderPath -Parent
                        if ($subfolderParent -eq "/") 
                        {
                            $subfolderParent = ""
                        }

                        $destinationPath = $folder.destination + $subfolderParent
                        $result = Get-SFTPFile -SessionId ($newSSHSession).SessionId -RemoteFile $file.FullName -LocalPath $destinationPath -Overwrite -verbose
                        $result | Out-File -FilePath "$($logFolder)$(Get-Date -Format yyyyMMdd)-incoming-transmit.log" -Append 

                        Write-SFTPLogs((Get-Date).ToString() + " - " + $endFile + " has trasnfered, checking length parameters.")

                        $endFile = $destinationPath + "\" + $fileName
                        $localfile = Get-ChildItem $endFile

                        Write-SFTPLogs((Get-Date).ToString() + " - " + $endFile + " transfered successfully. Deleting source")

                        # the file has transfered ok, remove it
                        Write-Host "Removing " $file.FullName -ForegroundColor Red
                        $result = Remove-SFTPItem -SessionId $newSSHSession.SessionId -Path $file.FullName -verbose
                        $result | Out-File -FilePath "$($logFolder)$(Get-Date -Format yyyyMMdd)-incoming-transmit.log" -Append
                        <# end of checking file #>
                    }
                }
                Write-SFTPLogs((Get-Date).ToString() + " - Disconnecting from " + $folder.sourceserver)

                Get-SFTPSession |Where-Object {$_.Connected -eq $false} | Remove-SFTPSession
                #>
            }
            catch {
                $_ | Out-File -FilePath "$($logFolder)$(Get-Date -Format yyyyMMdd)-incoming-error.log" -Append
                Write-eventlog -LogName Application -message $_.Exception.message -EntryType Error -Source $eventSource -EventId $eventID
            }
        }
    } 
    Start-Sleep 30
}