@echo off

echo  ---- Build Sumika ----

REM Ensure device metadata script dependencies are ready
if not exist "device-metadata-script\node_modules" (
    echo  ---- Installing device metadata script dependencies ----
    cd device-metadata-script
    call npm install
    cd ..
    echo  ---- Device metadata dependencies installed ----
)

if exist build rmdir /s /q build

go build -o build\sumika.exe ./server
if %errorlevel% neq 0 exit /b 1

echo  ---- Build complete, copy assets ----

xcopy /e /i /q server\assets build\assets
xcopy /e /i /q device-metadata-script build\device-metadata-script

echo { > build\meta.json
echo   "buildDate": "%date% %time%", >> build\meta.json
echo   "built from": "%computername%" >> build\meta.json
echo } >> build\meta.json

echo  ---- copy complete ----
