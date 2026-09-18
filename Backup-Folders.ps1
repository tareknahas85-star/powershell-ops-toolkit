<#
.SYNOPSIS
    Copies folders to a backup place and keeps a log.

.DESCRIPTION
    Uses robocopy, which is built into Windows and is good at copying
    large folders. Each run goes into its own dated folder, so you keep
    history instead of overwriting the last copy.

    If you set -KeepDays, it deletes backup folders older than that.
    It ONLY deletes folders inside the backup place that match its own
    date naming. It never touches your source folders.

.PARAMETER Source
    One or more folders to copy.

.PARAMETER Destination
    The folder where backups are kept.

.PARAMETER KeepDays
    Delete backups older than this many days. Leave empty to delete nothing.

.PARAMETER LogPath
    Where to write the log file. Default is a 'logs' folder in the destination.

.EXAMPLE
    .\Backup-Folders.ps1 -Source "C:\Data" -Destination "D:\Backups"

.EXAMPLE
    .\Backup-Folders.ps1 -Source "C:\Data","C:\Config" -Destination "D:\Backups" -KeepDays 30 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Source,

    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [int]$KeepDays,

    [string]$LogPath
)

$ErrorActionPreference = 'Stop'

$stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
$runFolder = Join-Path $Destination "backup_$stamp"

if (-not $LogPath) {
    $LogPath = Join-Path $Destination 'logs'
}
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$logFile = Join-Path $LogPath "backup_$stamp.log"

# Named Write-BackupLog, not Write-Log, because PowerShell 6 and newer
# already ship a Write-Log command and overriding it causes confusion.
function Write-BackupLog {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Message"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Write-BackupLog "Backup started."
Write-BackupLog "Destination: $runFolder"

$failed = 0

foreach ($folder in $Source) {
    if (-not (Test-Path $folder)) {
        Write-BackupLog "SKIPPED. Folder not found: $folder"
        $failed++
        continue
    }

    $name = Split-Path -Path $folder -Leaf
    $target = Join-Path $runFolder $name

    if ($PSCmdlet.ShouldProcess($folder, "Copy to $target")) {
        Write-BackupLog "Copying $folder"

        # /E    include subfolders, even empty ones
        # /Z    can continue if the network drops
        # /R:2  retry twice on a locked file, instead of forever
        # /W:5  wait 5 seconds between tries
        # /NP   do not print a percent line for every file
        robocopy $folder $target /E /Z /R:2 /W:5 /NP /LOG+:$logFile | Out-Null

        # Robocopy uses exit codes 0 to 7 for success. 8 and above are real errors.
        if ($LASTEXITCODE -ge 8) {
            Write-BackupLog "FAILED with robocopy code $LASTEXITCODE : $folder"
            $failed++
        }
        else {
            Write-BackupLog "Done: $folder"
        }
    }
}

# --- Remove old backups ----------------------------------------------------
if ($PSBoundParameters.ContainsKey('KeepDays')) {
    $cutoff = (Get-Date).AddDays(-$KeepDays)
    Write-BackupLog "Looking for backups older than $KeepDays days."

    # Only folders this script made, matched by name pattern, are considered.
    $old = Get-ChildItem -Path $Destination -Directory |
        Where-Object { $_.Name -match '^backup_\d{4}-\d{2}-\d{2}_\d{4}$' -and $_.CreationTime -lt $cutoff }

    foreach ($dir in $old) {
        if ($PSCmdlet.ShouldProcess($dir.FullName, 'Delete old backup')) {
            Remove-Item -Path $dir.FullName -Recurse -Force
            Write-BackupLog "Deleted old backup: $($dir.Name)"
        }
    }

    if ($old.Count -eq 0) {
        Write-BackupLog "No old backups to delete."
    }
}

if ($failed -gt 0) {
    Write-BackupLog "Backup finished with $failed problem(s)."
    exit 1
}

Write-BackupLog "Backup finished with no problems."
exit 0
