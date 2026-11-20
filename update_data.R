# Fetch the latest data into data/ (run from the project root):
#   Rscript update_data.R
# Run it once a day (Task Scheduler or GitHub Actions) so the week view builds up.

source("R/sources.R")
source("R/update.R")
status <- run_update()
# A non-zero exit tells update_data.bat the day's snapshot is missing, so the next trigger retries
if (!isTRUE(status$rss)) quit(status = 1)
