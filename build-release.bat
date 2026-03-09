@echo off
echo 🌊 Building WAVY for Android and Web...

echo.
echo 📱 Building Android APK...
flutter build apk --release
if %errorlevel% neq 0 (
    echo ❌ Android build failed
    pause
    exit /b 1
)

echo.
echo 🌐 Building Web...
flutter build web --release
if %errorlevel% neq 0 (
    echo ❌ Web build failed
    pause
    exit /b 1
)

echo.
echo ✅ Build completed successfully!
echo 📱 Android APK: build\app\outputs\flutter-apk\app-release.apk
echo 🌐 Web: build\web\

pause