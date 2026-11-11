@echo off
REM Double-click to start the Thailand Google Trends dashboard in your browser.
cd /d "%~dp0"
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "shiny::runApp('.', launch.browser = TRUE)"
pause
