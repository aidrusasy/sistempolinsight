# Launch completely detached background processes
Write-Host "1. Cleaning existing processes..."
Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force

$conns = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
foreach ($c in $conns) {
    if ($c.OwningProcess) {
        Write-Host "Stopping process PID $($c.OwningProcess)..."
        Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue
    }
}
Start-Sleep -Seconds 2

if (Test-Path "tunnel.log") { Remove-Item "tunnel.log" -Force }
if (Test-Path "server.log") { Remove-Item "server.log" -Force }

Write-Host "2. Spawning independent Dev Server via Win32_Process..."
$serverCmd = "cmd.exe /c ""c:\Users\choris satun nikmah\Downloads\sistemkomunikasi-main\sistemkomunikasi-main\run-server.bat"""
$srv = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = $serverCmd}
Write-Host "Detached Server Started with ProcessId: $($srv.ProcessId)"

Write-Host "Waiting for port 8080 to become ready..."
$ready = $false
for ($i = 0; $i -lt 25; $i++) {
    Start-Sleep -Seconds 1
    $check = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
    if ($check) {
        $ready = $true
        Write-Host "Port 8080 is listening (Owning PID: $($check.OwningProcess))"
        break
    }
}

if (-not $ready) {
    Write-Error "Server failed to start on port 8080."
    exit 1
}

Write-Host "3. Spawning independent Cloudflare Tunnel via Win32_Process..."
$tunnelCmd = "cmd.exe /c ""c:\Users\choris satun nikmah\Downloads\sistemkomunikasi-main\sistemkomunikasi-main\run-tunnel.bat"""
$tun = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = $tunnelCmd}
Write-Host "Detached Cloudflare Tunnel Started with ProcessId: $($tun.ProcessId)"

Write-Host "4. Waiting for public tunnel URL in tunnel.log..."
$url = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path "tunnel.log") {
        $content = Get-Content "tunnel.log" -Raw -ErrorAction SilentlyContinue
        if ($content -match 'https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com') {
            $url = $matches[0]
            break
        }
    }
}

if ($url) {
    Write-Host "FOUND_URL: $url"
    Write-Host "Verifying tunnel connectivity..."
    Start-Sleep -Seconds 3
    $status = $null
    for ($i = 0; $i -lt 10; $i++) {
        try {
            $res = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            $status = $res.StatusCode
            if ($status -eq 200) { break }
        } catch {
            Start-Sleep -Seconds 2
        }
    }
    Write-Host "URL: $url"
    Write-Host "STATUS_CODE: $status"
} else {
    Write-Host "Could not find URL. Log output:"
    if (Test-Path "tunnel.log") { Get-Content "tunnel.log" -Tail 15 }
}
