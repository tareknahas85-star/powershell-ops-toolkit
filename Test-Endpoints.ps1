<#
.SYNOPSIS
    Opens a list of web addresses and says which ones are down or slow.

.DESCRIPTION
    Sends a normal web request to each address and records the answer code
    and how long it took. Good as a simple check after a deployment, or
    every few minutes from a scheduled task.

    It only reads. It changes nothing.

.PARAMETER Url
    One or more addresses to test.

.PARAMETER UrlFile
    A text file with one address per line. Lines starting with # are ignored.

.PARAMETER TimeoutSeconds
    Give up on an address after this many seconds. Default is 10.

.PARAMETER SlowMilliseconds
    Mark an address as slow when it takes longer than this. Default is 2000.

.PARAMETER OutputPath
    Save the result as a CSV file.

.EXAMPLE
    .\Test-Endpoints.ps1 -Url "https://example.com"

.EXAMPLE
    .\Test-Endpoints.ps1 -UrlFile .\urls.txt -OutputPath "C:\Reports\uptime.csv"
#>

[CmdletBinding()]
param(
    [string[]]$Url,
    [string]$UrlFile,
    [int]$TimeoutSeconds = 10,
    [int]$SlowMilliseconds = 2000,
    [string]$OutputPath
)

$targets = [System.Collections.Generic.List[string]]::new()

if ($Url) {
    foreach ($u in $Url) { $targets.Add($u) }
}

if ($UrlFile) {
    if (-not (Test-Path $UrlFile)) {
        throw "File not found: $UrlFile"
    }
    Get-Content $UrlFile |
        Where-Object { $_.Trim() -ne '' -and -not $_.TrimStart().StartsWith('#') } |
        ForEach-Object { $targets.Add($_.Trim()) }
}

if ($targets.Count -eq 0) {
    throw "Give me something to test. Use -Url or -UrlFile."
}

$results = [System.Collections.Generic.List[object]]::new()

foreach ($target in $targets) {
    $address = $target
    if ($address -notmatch '^https?://') {
        $address = "https://$address"
    }

    $watch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $response = Invoke-WebRequest -Uri $address -TimeoutSec $TimeoutSeconds -UseBasicParsing -ErrorAction Stop
        $watch.Stop()

        $ms = $watch.ElapsedMilliseconds
        $status = if ($ms -gt $SlowMilliseconds) { 'SLOW' } else { 'OK' }

        $results.Add([pscustomobject]@{
            Address = $address
            Status  = $status
            Code    = $response.StatusCode
            Time_ms = $ms
            Note    = ''
        })
    }
    catch {
        $watch.Stop()

        # A 404 or 500 still answers, so read the code out of the error.
        $code = $null
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
        }

        $results.Add([pscustomobject]@{
            Address = $address
            Status  = 'DOWN'
            Code    = $code
            Time_ms = $watch.ElapsedMilliseconds
            Note    = $_.Exception.Message
        })
    }
}

$results | Format-Table -AutoSize

$bad = $results | Where-Object { $_.Status -ne 'OK' }

if ($bad.Count -eq 0) {
    Write-Host ""
    Write-Host "All $($results.Count) address(es) answered normally." -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "$($bad.Count) address(es) have a problem." -ForegroundColor Yellow
}

if ($OutputPath) {
    $folder = Split-Path -Path $OutputPath -Parent
    if ($folder -and -not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "Saved to $OutputPath" -ForegroundColor Cyan
}

if ($bad.Count -gt 0) { exit 1 } else { exit 0 }
