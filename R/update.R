# Fetch everything the dashboard shows and cache it under data/.
# Called by update_data.R (command line / scheduled) and by the dashboard's
# "Update data" button. Google Trends Explore rate-limits hard (HTTP 429), so:
#   - past years are fetched once and kept (they never change),
#   - day and week are refetched on every run,
#   - a failed fetch keeps the previous cached file instead of deleting it.

data_dir <- "data"
rss_file <- file.path(data_dir, "rss_history.csv")
yis_file <- file.path(data_dir, "year_in_search.csv")
interest_file <- function(key) file.path(data_dir, paste0("interest_", key, ".rds"))

yis_years <- function() {
  this_year <- as.integer(format(Sys.Date(), "%Y"))
  # Google publishes Year in Search in early December
  last <- if (as.integer(format(Sys.Date(), "%m")) == 12) this_year else this_year - 1
  (last - 4):last
}

now_utc <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

read_rss_history <- function() {
  if (!file.exists(rss_file)) return(NULL)
  utils::read.csv(rss_file, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

read_interest <- function(key) {
  f <- interest_file(key)
  if (file.exists(f)) readRDS(f) else NULL
}

# Fetch one trend-line set and cache it; on failure keep the old cache
cache_interest <- function(key, terms, window, label, log) {
  res <- tryCatch(fetch_interest(terms, window), error = function(e) e)
  if (inherits(res, "error")) {
    log(sprintf("  %-10s FAILED: %s (kept previous data)", key, conditionMessage(res)))
    return(FALSE)
  }
  saveRDS(list(key = key, label = label, window = window, terms = terms,
               fetched_at = now_utc(), data = res), interest_file(key))
  log(sprintf("  %-10s ok: %d points for %s", key, nrow(res), paste(terms, collapse = ", ")))
  TRUE
}

run_update <- function(log = function(msg) cat(msg, "\n"), pause = 8) {
  dir.create(data_dir, showWarnings = FALSE)
  status <- list()

  # 1. Daily RSS snapshot (appended, so the week view builds up over time)
  log("1/4 Daily trending searches (RSS)")
  rss <- tryCatch(read_daily_rss(), error = function(e) e)
  if (inherits(rss, "error")) {
    log(paste("  FAILED:", conditionMessage(rss)))
    status$rss <- FALSE
  } else {
    rss$fetched_at <- now_utc()
    utils::write.table(rss[c("fetched_at", "rank", "term", "traffic_text", "traffic", "news_title", "news_url")],
                       rss_file, sep = ",", row.names = FALSE, fileEncoding = "UTF-8",
                       col.names = !file.exists(rss_file), append = file.exists(rss_file), qmethod = "double")
    log(sprintf("  ok: %d terms, #1 = %s (%s)", nrow(rss), rss$term[1], rss$traffic_text[1]))
    status$rss <- TRUE
  }

  # 2. Year in Search lists (only years not cached yet)
  log("2/4 Year in Search lists")
  yis <- if (file.exists(yis_file)) utils::read.csv(yis_file, stringsAsFactors = FALSE, fileEncoding = "UTF-8") else NULL
  for (y in setdiff(yis_years(), unique(yis$year))) {
    r <- tryCatch(read_year_in_search(y), error = function(e) e)
    if (inherits(r, "error")) { log(sprintf("  %d FAILED: %s", y, conditionMessage(r))); next }
    yis <- rbind(yis, r)
    log(sprintf("  %d ok: %d lists", y, length(unique(r$category))))
  }
  if (!is.null(yis)) utils::write.csv(yis, yis_file, row.names = FALSE, fileEncoding = "UTF-8")

  # 3. Trend lines for day and week (refetched every run)
  log("3/4 Trend lines: day and week (Google Trends Explore)")
  rss_hist <- read_rss_history()
  if (!is.null(rss_hist)) {
    latest <- rss_hist[rss_hist$fetched_at == max(rss_hist$fetched_at), ]
    status$day <- cache_interest("day", head(rank_by_volume(latest)$term, 5),
                                 explore_windows[["day"]], "Past 24 hours", log)
    Sys.sleep(pause)
    wk <- top_from_rss(rss_hist, days = 7, n = 5)
    status$week <- cache_interest("week", wk$term, explore_windows[["week"]], "Past 7 days", log)
    Sys.sleep(pause)
  }

  # 4. Trend lines for each Year in Search year and the 5-year view (fetched once)
  log("4/4 Trend lines: years and 5 years")
  if (!is.null(yis)) {
    years <- sort(unique(yis$year))
    for (y in years) {
      if (!is.null(read_interest(paste0("year_", y)))) next
      terms <- head(yis_headline(yis, y)$term, 5)
      status[[paste0("year_", y)]] <- cache_interest(
        paste0("year_", y), terms, sprintf("%d-01-01 %d-12-31", y, y), paste("Calendar year", y), log)
      Sys.sleep(pause)
    }
    five_terms <- vapply(years, function(y) yis_headline(yis, y)$term[1], character(1))
    cached <- read_interest("five")
    if (is.null(cached) || !identical(cached$terms, unname(five_terms))) {
      status$five <- cache_interest("five", unname(five_terms),
        sprintf("%d-01-01 %d-12-31", min(years), max(years)),
        sprintf("%d to %d", min(years), max(years)), log)
    }
  }

  log("Done.")
  invisible(status)
}
