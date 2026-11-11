@echo off
REM Fetch the latest Google Trends data into data\ and append the output to data\update.log.
REM Windows Task Scheduler runs this daily (task name: ThaiTrendsDailyUpdate).
cd /d "%~dp0"
if not exist data mkdir data
echo ===== %date% %time% =====>> data\update.log
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" update_data.R >> data\update.log 2>&1
