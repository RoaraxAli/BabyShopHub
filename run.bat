@echo off
echo === BabyShopHub Launcher ===

echo [1/3] Installing relay server dependencies...
cd server
call npm install --silent
echo [2/3] Starting SMTP relay server on port 3000...
start "BabyShopHub SMTP Relay" cmd /k "node index.js"
cd ..

echo [3/3] Waiting for relay server to initialize...
timeout /t 3 /nobreak >nul

echo Starting Flutter app...
flutter run -d chrome --web-port=5000
