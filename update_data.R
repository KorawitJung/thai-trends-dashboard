# Fetch the latest data into data/ (run from the project root):
#   Rscript update_data.R
# Run it once a day (Task Scheduler or GitHub Actions) so the week view builds up.

source("R/sources.R")
source("R/update.R")
run_update()
