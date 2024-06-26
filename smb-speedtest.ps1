 <#
.SYNOPSIS
    Determine network speed in Mbps
.DESCRIPTION
    This script will take a local folder as an argument and copy all files 
    found in it to and from a target server.  The Mbps will be determined 
    from the time it takes to perform this operation.
    
.PARAMETER RemotePath
    Each Path specified must be in UNC format, i.e. \\server\share
.PARAMETER LocalPath
    Folder to be scanned for sample files
.INPUTS
    <string> Folder to scan for local files to be used in test
    <string> UNC of path to test copy to/from
.OUTPUTS
    PSCustomObject
        Server          Name of Server
        TimeStamp       Time when script was run
        WriteTime       TimeSpan object of how long the write test took
        WriteMbps       Mbps of the write test
        ReadTime        TimeSpan object of how long the read test took
        ReadMbps        Mbps of the read test
.EXAMPLE
    .\smb-speedtest.ps1 -LocalPath ".\files" -RemotePath "\\server1\share"
.EXAMPLE
    .\smb-speedtest.ps1 -LocalPath ".\files" -RemotePath (Get-Content c:\shares.txt) -Verbose

#requires -Version 3.0
#>
[CmdletBinding()]
Param (
    [String]$RemotePath, $LocalPath
)

function Show-HelpText {
    Write-Host "Usage of the smb-speedtest.ps1 script:" -ForegroundColor Green
    Write-Host "`t-RemotePath [String]: Specifies the UNC path for the remote server (e.g., '\\server\share')." -ForegroundColor Yellow
    Write-Host "`t-LocalPath [String]: Specifies the local directory path where the files are located (e.g., 'C:\Files')." -ForegroundColor Yellow
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "`t.\smb-speedtest.ps1 -LocalPath '.\files' -RemotePath '\\server1\share'" -ForegroundColor Yellow
    Write-Host "`t.\smb-speedtest.ps1 -LocalPath (Get-Content c:\shares.txt) -RemotePath '\\server2\share'" -ForegroundColor Yellow
}

# Check if parameters are not provided and display help
if (-not $RemotePath -or -not $LocalPath) {
    Write-Host "You must specify both RemotePath and LocalPath." -ForegroundColor Red
    Show-HelpText
    exit
}

Begin {
    Write-Verbose "$(Get-Date): SMB-NetworkSpeed Script begins"
    #Set-Location $LocalPath

    Try {
        $Count = (Get-ChildItem $LocalPath -ErrorAction Stop).Length
        Write-Verbose "$(Get-Date): $Count files to be copied from LocalPath"
        $ChildItemObject = (Get-ChildItem $LocalPath -ErrorAction Stop) | Measure-Object -Property Length -Sum
        $TotalSize = $ChildItemObject.Sum
        Write-Verbose "$(Get-Date): Total size of files in folder: $TotalSize"
    }
    Catch {
        Write-Warning "No files found in local directory"
        Write-Warning "Last error: $($Error[0])"
        Exit
    }
    Write-Verbose "$(Get-Date): Source for test files: $LocalPath"
    $RunTime = Get-Date
}

Process {
    $Files = Get-ChildItem $LocalPath
    $Target = "$RemotePath\SpeedTest"
    $TotalWriteSeconds = 0
    $TotalReadSeconds = 0
    $WriteTestArray = @()
    $ReadTestArray = @()

    ForEach ($File in $Files)
    {   Write-Verbose "$(Get-Date): Checking write speed for $File..."
        Write-Verbose "$(Get-Date): Destination: $Target"
        
        If (-not (Test-Path $Target))
        {   Try {
                New-Item -Path $Target -ItemType Directory -ErrorAction Stop | Out-Null
            }
            Catch {
                Write-Warning "Problem creating $Target folder because: $($Error[0])"
                [PSCustomObject]@{
                    TimeStamp = $RunTime
                    Status = "$($Error[0])"
                    WriteTime = New-TimeSpan -Days 0
                    WriteMbps = 0
                    ReadTime = New-TimeSpan -Days 0
                    ReadMbps = 0
                }
                Continue
            }
        }
        
        Try {
            Write-Verbose "$(Get-Date): Write Test..."
            $WriteTest = Measure-Command { 
                Copy-Item $LocalPath\$File $Target -ErrorAction Stop
            }
        }
        Catch {
            Write-Warning "Problem during speed test: $($Error[0])"
            $Status = "$($Error[0])"
            $WriteMbps = $ReadMbps = 0
            $WriteTest = $ReadTest = New-TimeSpan -Days 0
        }
        $WriteSeconds = $WriteTest.TotalSeconds
        Write-Verbose "$(Get-Date): File write took: $WriteSeconds"
        Write-Debug "$(Get-Date): TotalWriteSeconds before update is: $TotalWriteSeconds"
        $TotalWriteSeconds += $WriteSeconds
        Write-Debug "$(Get-Date): TotalWriteSeconds after update is: $TotalWriteSeconds"
        $WriteTestArray += $WriteTest
    }

    ForEach ($File in $Files) {
        Try {
            Write-Verbose "$(Get-Date): Read Test..."
            $ReadTest = Measure-Command {
                Copy-Item $Target\$File $LocalPath -ErrorAction Stop
            }
            $Status = "OK"
        }
        Catch {
            Write-Warning "Problem during speed test: $($Error[0])"
            $Status = "$($Error[0])"
            $WriteMbps = $ReadMbps = 0
            $WriteTest = $ReadTest = New-TimeSpan -Days 0
        }
        $ReadSeconds = $ReadTest.TotalSeconds
        Write-Verbose "$(Get-Date): File read took: $ReadSeconds"
        $TotalReadSeconds += $ReadSeconds
        $ReadTestArray += $ReadSeconds
    }

    Write-Debug "TotalWriteSeconds at end is: $TotalWriteSeconds"
    $WriteMbps = [Math]::Round((($TotalSize * 8) / $TotalWriteSeconds) / 1048576,2)
    $ReadMbps = [Math]::Round((($TotalSize * 8) / $TotalReadSeconds) / 1048576,2)

    [PSCustomObject]@{
        TimeStamp = $RunTime
        Status = "OK"
        WriteTime = $WriteTestArray
        WriteMbps = $WriteMbps
        ReadTime = $ReadTestArray
        ReadMbps = $ReadMbps
    }
}

End {
    Write-Verbose "$(Get-Date): SMB-NetworkSpeed completed!"
} 
