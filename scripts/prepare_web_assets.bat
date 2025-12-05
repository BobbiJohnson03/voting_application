@echo off
REM ============================================
REM Prepare Web Assets for Mobile PWA Hosting
REM ============================================
REM This script copies the Flutter web build to assets/web
REM so that the Android APK can serve PWA to clients

echo [1/3] Building Flutter Web...
cd /d "%~dp0.."
call flutter build web --release

if errorlevel 1 (
    echo ERROR: Flutter web build failed!
    pause
    exit /b 1
)

echo [2/3] Copying web build to assets/web...

REM Clear existing assets/web (except .gitkeep)
if exist "assets\web" (
    for /f "delims=" %%f in ('dir /b /a-d "assets\web" 2^>nul ^| findstr /v ".gitkeep"') do del "assets\web\%%f"
    for /d %%d in ("assets\web\*") do rd /s /q "%%d"
)

REM Copy build/web to assets/web
xcopy "build\web\*" "assets\web\" /E /Y /I

if errorlevel 1 (
    echo ERROR: Failed to copy web build!
    pause
    exit /b 1
)

echo [3/3] Web assets prepared successfully!
echo.
echo Now you can build the APK:
echo   flutter build apk --release
echo.
pause