@echo off
REM Fetch the latest Google Trends data into data\, then commit and push it to GitHub.
REM Output is appended to data\update.log (not committed).
REM Windows Task Scheduler runs this daily at 9:00 and again at logon, unlock and wake
REM (task name: ThaiTrendsDailyUpdate), so a day missed while asleep is caught up.
REM data\last_success.txt (not committed) holds the date of the last good run; later
REM triggers that day exit at once, so the RSS history gets one snapshot per day.
cd /d "%~dp0"
if not exist data mkdir data
set LAST=
if exist data\last_success.txt set /p LAST=<data\last_success.txt
if "%LAST%"=="%date%" goto :eof
echo ===== %date% %time% =====>> data\update.log
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" update_data.R >> data\update.log 2>&1
if %errorlevel%==0 echo %date%> data\last_success.txt

REM ---- Publish the refreshed data (skipped when nothing changed) ----
set GIT="C:\Program Files\Git\cmd\git.exe"
%GIT% add data >> data\update.log 2>&1
%GIT% diff --cached --quiet
if %errorlevel%==0 (
  echo git: no data changes to push>> data\update.log
  goto :eof
)
%GIT% commit --quiet -m "data: daily update %date%" >> data\update.log 2>&1
%GIT% pull --rebase --autostash --quiet >> data\update.log 2>&1
%GIT% push --quiet >> data\update.log 2>&1
if %errorlevel%==0 (echo git: pushed>> data\update.log) else (echo git: PUSH FAILED>> data\update.log)
