<#
.SYNOPSIS
    Finds the biggest files and folders that are eating your disk.

.DESCRIPTION
    Walks a path, adds up the size of every folder, and shows you the
    largest ones. Then shows the largest single files. Use it when a disk
    is filling up and you do not know why.

    It only reads. It deletes nothing.

.PARAMETER Path
    Where to look. Default is C:\.

.PARAMETER Top
    How many rows to show in each list. Default is 15.

.PARAMETER MinimumSizeMB
    Ignore anything smaller than this. Default is 100.

.PARAMETER OutputPath
    Save the result as a CSV file.

.EXAMPLE
    .\Get-DiskCleanupReport.ps1

.EXAMPLE
    .\Get-DiskCleanupReport.ps1 -Path "D:\" -Top 25
#>

[CmdletBinding()]
param(
    [string]$Path = 'C:\',
    [int]$Top = 15,
    [int]$MinimumSizeMB = 100,
    [string]$OutputPath
)

if (-not (Test-Path $Path)) {
    throw "Path not found: $Path"
}

Write-Host "Looking through $Path. On a big disk this takes a few minutes." -ForegroundColor Cyan

$minBytes = $MinimumSizeMB * 1MB

# Some system folders cannot be read even as admin. Keep going instead of stopping.
$allFiles = Get-ChildItem -Path $Path -File -Recurse -Force -ErrorAction SilentlyContinue

# --- Biggest folders -------------------------------------------------------
Write-Host ""
Write-Host "Biggest folders" -ForegroundColor Cyan

$byFolder = $allFiles |
    Group-Object DirectoryName |
    ForEach-Object {
        $sum = ($_.Group | Measure-Object -Property Length -Sum).Sum
        [pscustomobject]@{
            Type    = 'Folder'
            Name    = $_.Name
            SizeMB  = [math]::Round($sum / 1MB, 1)
            Items   = $_.Count
        }
    } |
    Where-Object { $_.SizeMB * 1MB -ge $minBytes } |
    Sort-Object SizeMB -Descending |
    Select-Object -First $Top

$byFolder | Format-Table -AutoSize

# --- Biggest single files --------------------------------------------------
Write-Host ""
Write-Host "Biggest single files" -ForegroundColor Cyan

$byFile = $allFiles |
    Where-Object { $_.Length -ge $minBytes } |
    Sort-Object Length -Descending |
    Select-Object -First $Top |
    ForEach-Object {
        [pscustomobject]@{
            Type   = 'File'
            Name   = $_.FullName
            SizeMB = [math]::Round($_.Length / 1MB, 1)
            Items  = 1
        }
    }

$byFile | Format-Table -AutoSize

$total = ($allFiles | Measure-Object -Property Length -Sum).Sum
Write-Host ""
Write-Host "Total size under $Path is $([math]::Round($total / 1GB, 2)) GB across $($allFiles.Count) files." -ForegroundColor Cyan

if ($OutputPath) {
    $folder = Split-Path -Path $OutputPath -Parent
    if ($folder -and -not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    @($byFolder) + @($byFile) | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "Saved to $OutputPath" -ForegroundColor Cyan
}
