<#
.SYNOPSIS
    Tells you how many days are left before a website certificate expires.

.DESCRIPTION
    Opens a normal secure connection to each address, reads the certificate,
    and reports the expiry date. This is the same certificate a visitor's
    browser would see.

    It only reads. It changes nothing.

.PARAMETER Url
    One or more addresses. You can write them with or without https://.

.PARAMETER WarningDays
    Warn when fewer than this many days are left. Default is 30.

.PARAMETER OutputPath
    Save the result as a CSV file.

.EXAMPLE
    .\Get-CertificateExpiry.ps1 -Url "example.com"

.EXAMPLE
    .\Get-CertificateExpiry.ps1 -Url "example.com","shop.example.com" -WarningDays 45
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Url,

    [int]$WarningDays = 30,

    [string]$OutputPath
)

$results = [System.Collections.Generic.List[object]]::new()

foreach ($address in $Url) {
    # Accept "example.com" as well as "https://example.com/page".
    $clean = $address -replace '^https?://', '' -replace '/.*$', ''

    $host_ = $clean
    $port = 443

    if ($clean -match '^(.+):(\d+)$') {
        $host_ = $Matches[1]
        $port = [int]$Matches[2]
    }

    $tcp = $null
    $sslStream = $null

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect($host_, $port)

        # Accept any certificate here on purpose. We want to READ it and report,
        # even when it is expired or does not match. We are not trusting it.
        $sslStream = New-Object System.Net.Security.SslStream($tcp.GetStream(), $false, { $true })
        $sslStream.AuthenticateAsClient($host_)

        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]$sslStream.RemoteCertificate
        $daysLeft = [math]::Floor(($cert.NotAfter - (Get-Date)).TotalDays)

        $status = if ($daysLeft -lt 0) { 'EXPIRED' }
                  elseif ($daysLeft -lt $WarningDays) { 'WARN' }
                  else { 'OK' }

        $results.Add([pscustomobject]@{
            Address   = $clean
            Status    = $status
            DaysLeft  = $daysLeft
            ExpiresOn = $cert.NotAfter.ToString('yyyy-MM-dd')
            IssuedTo  = $cert.GetNameInfo('SimpleName', $false)
            IssuedBy  = $cert.GetNameInfo('SimpleName', $true)
        })
    }
    catch {
        $results.Add([pscustomobject]@{
            Address   = $clean
            Status    = 'ERROR'
            DaysLeft  = $null
            ExpiresOn = $null
            IssuedTo  = $null
            IssuedBy  = $_.Exception.Message
        })
    }
    finally {
        if ($sslStream) { $sslStream.Dispose() }
        if ($tcp) { $tcp.Dispose() }
    }
}

$results | Format-Table -AutoSize

$bad = $results | Where-Object { $_.Status -ne 'OK' }

if ($bad.Count -gt 0) {
    Write-Host ""
    Write-Host "$($bad.Count) address(es) need attention." -ForegroundColor Yellow
}
else {
    Write-Host ""
    Write-Host "All certificates are fine." -ForegroundColor Green
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
