<#
.SYNOPSIS
    Checks the health of a Windows server and says what is wrong.

.DESCRIPTION
    Looks at disk space, memory, how long the machine has been up, and
    whether important services are running. Prints a table, and can also
    save an HTML report.

    It only reads. It changes nothing.

.PARAMETER ComputerName
    The machine to check. Leave it empty to check this machine.

.PARAMETER Services
    Names of services that must be running.

.PARAMETER DiskWarningPercent
    Warn when free disk space falls under this percent. Default is 15.

.PARAMETER MemoryWarningPercent
    Warn when free memory falls under this percent. Default is 10.

.PARAMETER OutputPath
    Save an HTML report to this file.

.EXAMPLE
    .\Get-ServerHealth.ps1

.EXAMPLE
    .\Get-ServerHealth.ps1 -Services "W3SVC","MSSQLSERVER" -OutputPath "C:\Reports\health.html"
#>

[CmdletBinding()]
param(
    [string]$ComputerName = $env:COMPUTERNAME,
    [string[]]$Services = @(),
    [int]$DiskWarningPercent = 15,
    [int]$MemoryWarningPercent = 10,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param($Area, $Item, $Value, $Status, $Note)
    $results.Add([pscustomobject]@{
        Area   = $Area
        Item   = $Item
        Value  = $Value
        Status = $Status
        Note   = $Note
    })
}

Write-Host "Checking $ComputerName ..." -ForegroundColor Cyan

# --- How long the machine has been up -------------------------------------
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $ComputerName
    $upSince = $os.LastBootUpTime
    $upDays = [math]::Round(((Get-Date) - $upSince).TotalDays, 1)

    # A machine that has not restarted in months usually has updates waiting.
    $status = if ($upDays -gt 90) { 'WARN' } else { 'OK' }
    $note = if ($upDays -gt 90) { 'Not restarted for a long time. Updates may be waiting.' } else { '' }

    Add-Result 'System' 'Uptime' "$upDays days" $status $note
}
catch {
    Add-Result 'System' 'Uptime' 'unknown' 'ERROR' $_.Exception.Message
}

# --- Memory ----------------------------------------------------------------
try {
    $totalMb = [math]::Round($os.TotalVisibleMemorySize / 1KB, 0)
    $freeMb  = [math]::Round($os.FreePhysicalMemory / 1KB, 0)
    $freePct = [math]::Round(($freeMb / $totalMb) * 100, 1)

    $status = if ($freePct -lt $MemoryWarningPercent) { 'WARN' } else { 'OK' }
    $note = if ($freePct -lt $MemoryWarningPercent) { 'Very little free memory.' } else { '' }

    Add-Result 'Memory' 'Free memory' "$freeMb MB of $totalMb MB ($freePct%)" $status $note
}
catch {
    Add-Result 'Memory' 'Free memory' 'unknown' 'ERROR' $_.Exception.Message
}

# --- Disks -----------------------------------------------------------------
try {
    # DriveType 3 means a fixed local disk, not a USB stick or a network drive.
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk -ComputerName $ComputerName -Filter 'DriveType = 3'

    foreach ($disk in $disks) {
        $totalGb = [math]::Round($disk.Size / 1GB, 1)
        $freeGb  = [math]::Round($disk.FreeSpace / 1GB, 1)

        if ($totalGb -eq 0) { continue }

        $freePct = [math]::Round(($freeGb / $totalGb) * 100, 1)
        $status = if ($freePct -lt $DiskWarningPercent) { 'WARN' } else { 'OK' }
        $note = if ($freePct -lt $DiskWarningPercent) { 'Disk is nearly full.' } else { '' }

        Add-Result 'Disk' $disk.DeviceID "$freeGb GB free of $totalGb GB ($freePct%)" $status $note
    }
}
catch {
    Add-Result 'Disk' 'all' 'unknown' 'ERROR' $_.Exception.Message
}

# --- Services --------------------------------------------------------------
foreach ($name in $Services) {
    try {
        $svc = Get-Service -Name $name -ComputerName $ComputerName
        $status = if ($svc.Status -eq 'Running') { 'OK' } else { 'WARN' }
        $note = if ($svc.Status -ne 'Running') { 'This service should be running.' } else { '' }

        Add-Result 'Service' $svc.DisplayName $svc.Status $status $note
    }
    catch {
        Add-Result 'Service' $name 'not found' 'ERROR' 'No service with this name.'
    }
}

# --- Show the result -------------------------------------------------------
$results | Format-Table -AutoSize

$problems = $results | Where-Object { $_.Status -ne 'OK' }

if ($problems.Count -eq 0) {
    Write-Host ""
    Write-Host "Everything looks fine." -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Found $($problems.Count) thing(s) to look at:" -ForegroundColor Yellow
    foreach ($p in $problems) {
        Write-Host "  - $($p.Area) / $($p.Item): $($p.Value)  $($p.Note)" -ForegroundColor Yellow
    }
}

# --- Save the report -------------------------------------------------------
if ($OutputPath) {
    $style = @'
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; color: #24292f; }
h1 { font-size: 20px; }
table { border-collapse: collapse; width: 100%; margin-top: 12px; }
th, td { border: 1px solid #d0d7de; padding: 8px 10px; text-align: left; font-size: 14px; }
th { background: #f6f8fa; }
</style>
'@

    $title = "Server health: $ComputerName - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

    $folder = Split-Path -Path $OutputPath -Parent
    if ($folder -and -not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    $results |
        ConvertTo-Html -Title $title -PreContent "<h1>$title</h1>" -Head $style |
        Out-File -FilePath $OutputPath -Encoding utf8

    Write-Host ""
    Write-Host "Report saved to $OutputPath" -ForegroundColor Cyan
}

# Exit code 1 if something is wrong, so a scheduled task can notice.
if ($problems.Count -gt 0) { exit 1 } else { exit 0 }
