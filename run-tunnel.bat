@echo off
cd /d "c:\Users\choris satun nikmah\Downloads\sistemkomunikasi-main\sistemkomunikasi-main"
"C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --url http://127.0.0.1:8080 > tunnel.log 2>&1
