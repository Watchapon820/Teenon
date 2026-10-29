@echo off
rem เปิดอุโมงค์ให้เข้าถึง server (พอร์ต 5000) จากอินเทอร์เน็ต — ต้องรัน start_server.bat ไว้ก่อน
rem ลิงก์ https://....trycloudflare.com จะแสดงในหน้าต่างนี้ (เปลี่ยนใหม่ทุกครั้งที่เปิด ต้อง build แอปใหม่ให้ชี้ลิงก์ใหม่)
cd /d "%~dp0"
echo Starting public tunnel to http://localhost:5000 ...
tools\cloudflared\cloudflared.exe tunnel --no-autoupdate --url http://localhost:5000
pause
