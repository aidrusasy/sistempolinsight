@echo off
echo Stopping Cloudflare Tunnel...
taskkill /F /IM cloudflared.exe >nul 2>&1

echo Stopping server on port 8080...
powershell -NoProfile -Command "$c = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue; if ($c) { Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue }"

echo Background processes stopped.
pause
