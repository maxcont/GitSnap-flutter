@echo off
echo GitSnap Flutter - Avvio applicazione
echo ========================================

REM Verifica Flutter
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Flutter non trovato!
    echo Installa Flutter da: https://docs.flutter.dev/get-started/install
    pause
    exit /b 1
)

REM Installa dipendenze se necessario
if not exist ".dart_tool" (
    echo Installazione dipendenze...
    flutter pub get
)

echo.
echo Avvio applicazione...
flutter run -d windows

pause
