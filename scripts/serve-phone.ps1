param(
    [int]$Port = 8766,
    [string]$Address = ''
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw '이 스크립트에는 PowerShell 7이 필요합니다. pwsh -File scripts/serve-phone.ps1로 실행해 주세요.'
}
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$webRoot = Join-Path $projectRoot 'build/web'
if (-not (Test-Path -LiteralPath (Join-Path $webRoot 'index.html'))) {
    throw '웹 빌드가 없습니다. Godot에서 Web 내보내기를 먼저 실행해 주세요.'
}

if (-not $Address) {
    $candidates = foreach ($adapter in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        if ($adapter.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up) { continue }
        $properties = $adapter.GetIPProperties()
        if (-not ($properties.GatewayAddresses | Where-Object { $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork })) { continue }
        foreach ($item in $properties.UnicastAddresses) {
            if ($item.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and -not [System.Net.IPAddress]::IsLoopback($item.Address)) {
                $item.Address.ToString()
            }
        }
    }
    if (-not $candidates) {
        throw '활성 IPv4 주소를 찾지 못했습니다. -Address 192.168.x.x 형식으로 지정해 주세요.'
    }
    $Address = @($candidates)[0]
}

$ip = [System.Net.IPAddress]::Parse($Address)
if ($ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
    throw 'IPv4 주소만 사용할 수 있습니다.'
}

$certDir = Join-Path $projectRoot 'build/devcert'
New-Item -ItemType Directory -Path $certDir -Force | Out-Null
$certPath = Join-Path $certDir 'cert.pem'
$keyPath = Join-Path $certDir 'key.pem'
$rsa = [System.Security.Cryptography.RSA]::Create(2048)
try {
    $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=Small Garden Local',
        $rsa,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
    )
    $names = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
    $names.AddIpAddress($ip)
    $names.AddIpAddress([System.Net.IPAddress]::Parse('127.0.0.1'))
    $names.AddDnsName('localhost')
    $request.CertificateExtensions.Add($names.Build())
    $certificate = $request.CreateSelfSigned((Get-Date).AddDays(-1), (Get-Date).AddDays(30))
    try {
        [System.IO.File]::WriteAllText($certPath, $certificate.ExportCertificatePem())
        [System.IO.File]::WriteAllText($keyPath, $rsa.ExportPkcs8PrivateKeyPem())
    } finally {
        $certificate.Dispose()
    }
} finally {
    $rsa.Dispose()
}

Write-Host "휴대폰에서 열 주소: https://${Address}:${Port}/"
Write-Host 'PC와 휴대폰을 같은 Wi-Fi에 연결하세요. 브라우저가 임시 인증서 경고를 보이면 고급에서 계속 진행하세요.'
Write-Host '테스트를 마치면 이 창에서 Ctrl+C로 서버를 종료하세요.'
& node (Join-Path $projectRoot 'scripts/serve.mjs') $webRoot $Port $Address $certPath $keyPath
