@echo off
chcp 65001 >nul
echo ==========================================
echo Teenon Flutter Frontend - First Setup
echo ==========================================
echo.
echo 1. Checking Flutter...
flutter --version
if errorlevel 1 (
  echo.
  echo ERROR: Flutter was not found in PATH.
  echo Install Flutter and restart VS Code first.
  pause
  exit /b 1
)

echo.
echo 2. Generating Android project files...
flutter create . --platforms=android
if errorlevel 1 (
  echo Flutter create failed.
  pause
  exit /b 1
)

echo.
echo 3. Getting packages...
flutter pub get

echo.
echo Ready. Run: flutter run
pause
