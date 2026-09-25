@echo off
setlocal
cd /d "%~dp0"

REM ============================================================
REM  workbuddy2api-panel - the only script you need.
REM  Gateway: http://127.0.0.1:7863   Panel: /panel/
REM ============================================================

set "TASKNAME=workbuddy2api-panel"
set "SHIM_SRC=%~dp0startup-shim.vbs"
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SHIM=%STARTUP%\workbuddy2api-panel.vbs"
set "PORT=7863"

:menu
cls
echo.
echo   workbuddy2api-panel     http://127.0.0.1:%PORT%/panel/
echo   -------------------------------------------------------
echo.
echo    1  Start  (no window)
echo    2  Stop
echo    3  Status
echo.
echo    4  Enable autostart at logon   (no admin needed)
echo    5  Disable autostart
echo.
echo    6  Allow LAN access            (needs admin)
echo    0  Exit
echo.
echo   Log: data\wb2api.log
echo.
set "CH="
set /p "CH=  Choice: "
if "%CH%"=="1" goto start
if "%CH%"=="2" goto stop
if "%CH%"=="3" goto status
if "%CH%"=="4" goto auto_on
if "%CH%"=="5" goto auto_off
if "%CH%"=="6" goto firewall
if "%CH%"=="0" goto end
goto menu


:start
cls
echo Starting ...
call :launch
call :wait
pause
goto menu

:stop
cls
echo Stopping ...
schtasks /End /TN "%TASKNAME%" >nul 2>&1
timeout /t 2 /nobreak >nul
REM Kill only the PID holding the port - never "taskkill /IM",
REM which would also kill instances started deliberately elsewhere.
set "KILLED="
for /f "tokens=5" %%P in ('netstat -ano ^| findstr LISTENING ^| findstr ":%PORT%"') do (
    taskkill /PID %%P /F >nul 2>&1
    set "KILLED=1"
)
if defined KILLED (echo   [OK] stopped.) else (echo   [INFO] was not running.)
echo.
pause
goto menu

:status
cls
echo   Process : & (tasklist /FI "IMAGENAME eq wb2api.exe" 2>nul | find /I "wb2api.exe" >nul && echo running || echo NOT running)
set "PL=not listening"
for /f "delims=" %%L in ('netstat -ano ^| findstr LISTENING ^| findstr ":%PORT%"') do set "PL=LISTENING"
echo   Port    : %PL%
if exist "%SHIM%" (echo   Autostart: ON  ^(Startup folder^)) else (echo   Autostart: off)
echo.
echo   Key     :
for /f "tokens=2 delims=:," %%K in ('findstr /R /C:"\"api_key\"" config.json') do (
    for /f "tokens=* delims= " %%V in ("%%K") do echo     %%V
    goto :keydone
)
:keydone
echo.
echo   Local IP:
echo     http://127.0.0.1:%PORT%/v1
for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr /R /C:"IPv4"') do (
    for /f "tokens=* delims= " %%B in ("%%A") do echo     http://%%B:%PORT%/v1
)
echo.
echo   Health  : & curl -s --max-time 8 http://127.0.0.1:%PORT%/healthz
echo.
pause
goto menu

:auto_on
cls
if not exist "%SHIM_SRC%" (
    echo   [FAIL] startup-shim.vbs is missing next to this script.
    echo.
    pause
    goto menu
)
copy /Y "%SHIM_SRC%" "%SHIM%" >nul
if exist "%SHIM%" (
    echo   [OK] autostart enabled - starts silently at every logon.
    echo        No administrator rights required.
) else (
    echo   [FAIL] could not write to the Startup folder.
)
echo.
echo   Starting it now ...
call :launch
call :wait
pause
goto menu

:auto_off
cls
if exist "%SHIM%" (
    del /F /Q "%SHIM%"
    if exist "%SHIM%" (echo   [FAIL] delete it by hand: %SHIM%) else (echo   [OK] autostart disabled.)
) else (
    echo   [INFO] autostart was already off.
)
echo.
pause
goto menu

:firewall
cls
echo   Adding inbound rule for TCP %PORT% ^(private/domain only^) ...
echo.
netsh advfirewall firewall delete rule name="workbuddy2api panel LAN" >nul 2>&1
netsh advfirewall firewall add rule name="workbuddy2api panel LAN" dir=in action=allow protocol=TCP localport=%PORT% profile=private,domain
if errorlevel 1 (
    echo.
    echo   [FAIL] needs administrator rights.
    echo          Close this window, then RIGHT-CLICK this file and
    echo          choose "Run as administrator".
) else (
    echo.
    echo   [OK] LAN devices can now reach port %PORT%.
    echo        Public networks are NOT opened.
)
echo.
pause
goto menu


:launch
REM Hidden launch - same code path as the autostart entry.
cscript //nologo "%~dp0startup-shim.vbs"
goto :eof

:wait
echo   waiting for port %PORT% ...
set "N=0"
:waitloop
set /a N+=1
timeout /t 1 /nobreak >nul
for /f "delims=" %%L in ('netstat -ano ^| findstr LISTENING ^| findstr ":%PORT%"') do goto up
if %N% lss 15 goto waitloop
echo   [WARN] not listening after %N%s - check data\wb2api.log
goto :eof
:up
echo   [OK] up.
curl -s --max-time 8 http://127.0.0.1:%PORT%/healthz
echo.
goto :eof

:end
endlocal
