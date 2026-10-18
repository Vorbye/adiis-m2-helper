@echo off
setlocal
cd /d "%~dp0"
where dotnet >nul 2>&1
if errorlevel 1 (
 echo .NET 8 SDK fehlt. Bitte installieren: https://dotnet.microsoft.com/download/dotnet/8.0
 pause
 exit /b 1
)
set "OUT=%~dp0Fertige-App"
set "STAGING=%~dp0_build-temp"
if exist "%STAGING%" rmdir /s /q "%STAGING%"
echo Erstelle kompakte Einzel-EXE...
dotnet publish "AHKManager.csproj" -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -o "%STAGING%"
if errorlevel 1 (
 echo Build fehlgeschlagen.
 pause
 exit /b 1
)
rem Runtime files must remain next to the EXE, outside the single-file bundle.
if not exist "%STAGING%\App" mkdir "%STAGING%\App"
for %%F in (server.ps1 index.html MetinWindows.cs icon.png) do (
 copy /Y "%~dp0%%F" "%STAGING%\App\%%F" >nul
 if errorlevel 1 (
  echo Fehler: %%F konnte nicht in den App-Ordner kopiert werden.
  pause
  exit /b 1
 )
 if not exist "%STAGING%\App\%%F" (
  echo Fehler: App\%%F fehlt nach dem Build.
  pause
  exit /b 1
 )
)
if not exist "%STAGING%\Adiis-m2-helper.exe" (
 echo Fehler: Die EXE fehlt nach dem Build.
 pause
 exit /b 1
)
if exist "%OUT%" (
 echo.
 echo Vorhandene Fertige-App gefunden. Sie bleibt als Backup erhalten.
 set "BACKUP=%~dp0Fertige-App-Backup-%RANDOM%%RANDOM%"
 move "%OUT%" "%BACKUP%" >nul
 if errorlevel 1 (
  echo Backup konnte nicht erstellt werden. Bitte die App schliessen und erneut versuchen.
  pause
  exit /b 1
 )
)
move "%STAGING%" "%OUT%" >nul
if errorlevel 1 (
 echo Konnte Fertige-App nicht erstellen.
 pause
 exit /b 1
)
if defined BACKUP if exist "%BACKUP%\Scripts" (
 xcopy "%BACKUP%\Scripts" "%OUT%\Scripts\" /E /I /Y >nul
)
if not exist "%OUT%\Scripts" mkdir "%OUT%\Scripts"
if not exist "%OUT%\App\AutoHotkey" mkdir "%OUT%\App\AutoHotkey"
if defined BACKUP if exist "%BACKUP%\App\AutoHotkey\AutoHotkey64.exe" if not exist "%OUT%\App\AutoHotkey\AutoHotkey64.exe" (
 copy /Y "%BACKUP%\App\AutoHotkey\AutoHotkey64.exe" "%OUT%\App\AutoHotkey\AutoHotkey64.exe" >nul
)
if not exist "%OUT%\App\AutoHotkey\AutoHotkey64.exe" (
 echo.
 echo Lade offizielle AutoHotkey v2 Portable-Laufzeit herunter...
 powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0AutoHotkey-Portable-einrichten.ps1" -Destination "%OUT%\App\AutoHotkey"
 if errorlevel 1 (
   echo AutoHotkey konnte nicht geladen werden. Die App erkennt eine lokal installierte Version weiterhin automatisch.
   echo Portable-Setup kann spaeter erneut ausgefuehrt werden.
 )
)
echo.
echo Fertig! Ordner: Fertige-App
 echo Enthalten: Adiis-m2-helper.exe, App-Ordner, Scripts-Ordner
 echo Alte Fertige-App wurde bei Bedarf als Backup behalten.
pause
