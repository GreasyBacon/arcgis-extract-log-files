<#
Main.ps1

    Written By: Rhys Walsh-Tindall

    Purpose: 
    - Dynamically locate logs for ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store running on the current machine.
    - Copies those logs to a specified directory, or default directory.
    - Creates a ZIP file of all logs copies.
    - Deletes copied log files.

    Parameter Usage:

        -help

        See a help message pretty much replicating this comment.

        -server

        Inlcude ArcGIS Server logs if specified.

        -portal

        Include Portal for ArcGIS logs if specified.

        -datastore

        Include ArcGIS DataStore logs if specified.
        Recommended to use -datastorefolder in combination with this parameter.

        -datastorefolder

        Only needed when -datastore is used.
        Specify the folder to grab logs from.
        If not specified, a prompt will appear asking user to select a folder using a number value.
        # Valid valuies - couchlog / database / elasticlog / server
        # Default - $null

        -destination

        Where the log files will be copied temporarily, and where the output ZIP file will be created.

    Example:

    ./ExtractLogFiles.ps1 -server -portal -datastore -datastorefolder 'server' -destination "C:\temp"

        Will copy most recent log file for Server, Portal, and DataStore (from server folder) and add to an output ZIP file within the "C:\temp" directory.

    ./ExtractLogFiles.ps1 -server -portal

        Will copy most recent log file for Server and Portal and add to an output ZIP file within the current directory.

#>
param (
    [switch]$help,
    [string]$destination,
    [switch]$server,
    [switch]$portal,
    [switch]$datastore,
    [string]$datastorefolder
)


$defaultLogLocations = @{
    ArcGIS_Server = @{
        Install_Directory = $env:AGSSERVER
        Log_Settings_File = $env:AGSSERVER + "framework/etc/arcgis-logsettings.json"
        Default_Log_Dir = (Get-Content ($env:AGSSERVER + "framework/etc/arcgis-logsettings.json") | ConvertFrom-Json).logDir
        Post_Machine_Name_Dir = "\server\"
        File_Type = "log"
        File_Format = "XML"
    }
    Portal_For_ArcGIS = @{
        # intial logging - C:\Program Files\ArcGIS\Portal\framework\service\logs\service-0.log
        Install_Directory = $env:AGSPORTAL
        Log_Settings_File = $env:AGSPORTAL + "framework/etc/arcgis-logsettings.json"
        Default_Log_Dir = (Get-Content ($env:AGSPORTAL + "framework/etc/arcgis-logsettings.json") | ConvertFrom-Json).logDir
        Post_Machine_Name_Dir = "\portal\"
        File_Type = "log"
        File_Format = "XML"
    }
    ArcGIS_Data_Store = @{
        Install_Directory = $env:AGSDATASTORE
        Log_Settings_File = $env:AGSDATASTORE + "framework/etc/arcgis-logsettings.json"
        Default_Log_Dir = (Get-Content ($env:AGSDATASTORE + "framework/etc/arcgis-logsettings.json") | ConvertFrom-Json).logDir
        Post_Machine_Name_Dirs = @('couchlog', 'database', 'elasticlog', 'server')
        # logs from 'server' are the only XML compatible files
    }
}

function Get-Machine-Name {
    param( 
        [Parameter(Mandatory)] [string]$FolderPath 
    )

    $machineNameCount = (Get-ChildItem $FolderPath | Measure-Object).Count
    if ($machineNameCount -gt 1) {
       
        $machineName = (Get-ChildItem $FolderPath | Sort-Object -Property "LastWriteTime" -Descending | Select-Object -First 1).Name    
   
    } else {
    
        $machineName = (Get-ChildItem $FolderPath | Select-Object -First 1).Name
  
    }
    return $machineName
}

function Get-Most-Recent-Log-File {
    param(
        [Parameter(Mandatory)]  [string]$FolderPath
    )
    $logFileName = (Get-ChildItem $FolderPath | Sort-Object -Property "LastWriteTime" -Descending | Select-Object -First 1).Name
    return $logFileName    

}

function Get-Log-File-Path {
    param(
        [Parameter(Mandatory)]  [string]$item = "",
        [Parameter(Mandatory=$false)] [string]$datastoreFolder = ""
    )
    
    switch ($item)
    {
        { @("ArcGIS_Server", "Portal_For_ArcGIS") -contains $_ } {
        
            $initialPath = $defaultLogLocations[$item]["Default_Log_Dir"]
            $machineName = Get-Machine-Name -FolderPath $initialPath
            $postMachineNameFolder = $defaultLogLocations[$item]["Post_Machine_Name_Dir"]
            $logFileName = Get-Most-Recent-Log-File -FolderPath ($initialPath + $machineName + $postMachineNameFolder)
            $fullPath = $initialPath + $machineName + $postMachineNameFolder + $logFileName
            return $fullPath
        
        }
        "ArcGIS_Data_Store" {


            $initialPath = $defaultLogLocations[$item]["Default_Log_Dir"]
            $machineName = Get-Machine-Name -FolderPath $initialPath
            
            if ($datastoreFolder -eq "" -or $datastoreFolder -notin $defaultLogLocations["ArcGIS_Data_Store"]["Post_Machine_Name_Dirs"]) {

                Write-Host "`nArcGIS Data Store: A valid datastore folder needs to be specified when accessing DataStore logs.`n"
                Write-Host "TIP: You can specify this in a non-interactive way by providing a -datastoreFolder parameter in the script arguments.`n"
                Write-Host "ArcGIS Data Store: Please enter the folder choice to view logs for:`n"
                Write-Host "[0] = couchlog`n"
                Write-Host "[1] = database`n"
                Write-Host "[2] = elasticlog`n"
                Write-Host "[3] = server`n"
                $choice = Read-Host "Please enter choice here: "
                $postMachineNameFolder = "\" + $defaultLogLocations["ArcGIS_Data_Store"]["Post_Machine_Name_Dirs"][$choice]+ "\"
           
            } else {

                Write-Host "Using $($datastoreFolder) as ArcGIS Data Store folder."
                $postMachineNameFolder = "\" + $datastoreFolder + "\"
           
            }
           
            $logFileName = Get-Most-Recent-Log-File -FolderPath ($initialPath + $machineName + $postMachineNameFolder)
            $fullpath = $initialPath + $machineName + $postMachineNameFolder + $logFileName
            return $fullPath
                    
      
        }
        Default {

            Write-Host "ERROR: A valid ArcGIS Enteprise Item is required to be supplied to the 'Get-Log-File-Path' function."
            return        
      
        }
    }
}



# Running the script based on parameters provided with Script.
if ($help) {
    Write-Host "
    
    ExtractLogFiles.ps1

    Written By: Rhys Walsh-Tindall

    Purpose: 
    - Dynamically locate logs for ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store running on the current machine.
    - Copies those logs to a specified directory, or default directory.
    - Creates a ZIP file of all logs copies.
    - Deletes copied log files.

    Parameter Usage:

        -help

        See a help message pretty much replicating this comment.

        -server

        Inlcude ArcGIS Server logs if specified.

        -portal

        Include Portal for ArcGIS logs if specified.

        -datastore

        Include ArcGIS DataStore logs if specified.
        Recommended to use -datastorefolder in combination with this parameter.

        -datastorefolder

        Only needed when -datastore is used.
        Specify the folder to grab logs from.
        If not specified, a prompt will appear asking user to select a folder using a number value.
        # Valid valuies - couchlog / database / elasticlog / server
        # Default - $null

        -destination

        Where the log files will be copied temporarily, and where the output ZIP file will be created.

    Example:

    ./ExtractLogFiles.ps1 -server -portal -datastore -datastorefolder 'server' -destination 'C:\temp'

        Will copy most recent log file for Server, Portal, and DataStore (from server folder) and add to an output ZIP file within the 'C:\temp' directory.

    ./ExtractLogFiles.ps1 -server -portal

        Will copy most recent log file for Server and Portal and add to an output ZIP file within the current directory.
            
    "
    return
}

$parameters = @{
    path = @()
}

if ($destination -eq "") {

    $destination = (Get-Item .).FullName
    Write-Host "`nDestination folder is: $($destination)."

}


if ($server) {

    $serverLog = Get-Log-File-Path -item "ArcGIS_Server"
    Write-Host "`nArcGIS Server log location determined to be $($serverLog)"
    $copiedFile = Copy-Item -Path $serverLog -Destination $destination -PassThru
    Write-Host "File has been copied temporarily to $($copiedFile)"
    $parameters.path += $copiedFile

}

if ($portal) {

    $portalLog = Get-Log-File-Path -item "Portal_For_ArcGIS"
    Write-Host "`nPortal for ArcGIS log location determined to be $($portalLog)"
    $copiedFile = Copy-Item -Path $portalLog -Destination $destination -PassThru
    Write-Host "File has been copied temporarily to $($copiedFile)"
    $parameters.path += $copiedFile

}

if ($datastore) {

    if ($datastorefolder -ne "") {
        $datastoreLog = Get-Log-File-Path -item "ArcGIS_Data_Store" -datastoreFolder $datastorefolder
    } else {
        $datastoreLog = Get-Log-File-Path -item "ArcGIS_Data_Store"
    }
    Write-Host "`nArcGIS Data Store log location determined to be $($datastoreLog)"
    $copiedFile = Copy-Item -Path $datastoreLog -Destination $destination -PassThru
    Write-Host "File has been copied temporarily to $($copiedFile)"
    $parameters.path += $copiedFile
}

if ($parameters.path.Count -gt 0) {

    $timestamp = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }
    $exportZipName = "\export_" + $timestamp + ".zip"
    $destinationPath = ($destination + $exportZipName)
    Write-Host "`nExport ZIP file will be created in $($destinationPath)"

    Write-Host "Adding log files to ZIP file"
    Get-ChildItem @parameters | Compress-Archive -DestinationPath $destinationPath

    Write-Host "Removing all temporary files."
    Remove-Item @parameters

} else {

    Write-Host "Please specify -server, -portal, or -datastore as an argument when running the script to create a ZIP file with logs."
    return
}

Write-Host "`nPress any key to continue..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") > $null
