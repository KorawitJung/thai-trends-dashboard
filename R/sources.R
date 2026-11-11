# Data sources for the Thailand Google Trends dashboard.
# Shiny loads every file in R/ automatically; update_data.R sources this file.
#
#   1. Daily Search Trends RSS   https://trends.google.com/trending/rss?geo=TH
#      Today's trending searches with Google's approximate search counts (e.g. "2000+").
#   2. Year in Search, Thailand  https://trends.google.com/trends/yis/<year>/TH/
#      Google's official yearly lists of top trending searches (ranked, no counts).
#   3. Google Trends Explore     https://trends.google.com/trends/explore  (via gtrendsR)
#      Interest over time on a 0-100 relative index, used for the trend lines.

geo <- "TH"

# ---- 1. Daily RSS --------------------------------------------------------------

# "200+", "20K+", "1M+"  ->  200, 20000, 1000000
parse_traffic <- function(x) {
  x <- toupper(gsub("[+,]", "", x))
  mult <- ifelse(grepl("M$", x), 1e6, ifelse(grepl("K$", x), 1e3, 1))
  suppressWarnings(as.numeric(sub("[KM]$", "", x))) * mult
}

read_daily_rss <- function() {
  resp <- httr::GET(paste0("https://trends.google.com/trending/rss?geo=", geo),
                    httr::timeout(30), httr::user_agent("Mozilla/5.0"))
  httr::stop_for_status(resp)
  doc   <- xml2::read_xml(httr::content(resp, as = "raw"))
  items <- xml2::xml_find_all(doc, "//item")
  txt <- function(node, tag) {
    hit <- xml2::xml_find_first(node, paste0(".//*[local-name()='", tag, "']"))
    if (inherits(hit, "xml_missing")) NA_character_ else xml2::xml_text(hit)
  }
  out <- data.frame(
    rank         = seq_along(items),
    term         = vapply(items, txt, character(1), tag = "title"),
    traffic_text = vapply(items, txt, character(1), tag = "approx_traffic"),
    news_title   = vapply(items, txt, character(1), tag = "news_item_title"),
    news_url     = vapply(items, txt, character(1), tag = "news_item_url"),
    stringsAsFactors = FALSE
  )
  out$traffic <- parse_traffic(out$traffic_text)
  out
}

# Google's feed order is not by size, so rank the latest snapshot by approximate
# search count (ties keep Google's order) and keep Google's order as google_rank.
rank_by_volume <- function(snapshot) {
  snapshot <- snapshot[order(-snapshot$traffic, snapshot$rank), ]
  snapshot$google_rank <- snapshot$rank
  snapshot$rank <- seq_len(nrow(snapshot))
  rownames(snapshot) <- NULL
  snapshot
}

# ---- 2. Year in Search ---------------------------------------------------------

year_in_search_url <- function(year) sprintf("https://trends.google.com/trends/yis/%d/%s/", year, geo)

# All ranked lists on the Year in Search page: one row per (category, rank)
read_year_in_search <- function(year) {
  resp <- httr::GET(year_in_search_url(year), httr::timeout(60), httr::user_agent("Mozilla/5.0"))
  httr::stop_for_status(resp)
  doc   <- xml2::read_html(httr::content(resp, as = "raw"), encoding = "UTF-8")
  links <- xml2::xml_find_all(doc, "//li[contains(@class,'list-item')]//a[@data-searchterms]")
  if (length(links) == 0) stop("no Year in Search lists found for ", year)
  li <- lapply(links, function(a) xml2::xml_find_first(a, "ancestor::li[1]"))
  out <- data.frame(
    year     = year,
    category = trimws(xml2::xml_attr(links, "data-topic")),
    rank     = as.integer(vapply(li, xml2::xml_attr, character(1), attr = "value")),
    term     = trimws(xml2::xml_attr(links, "data-searchterms")),
    stringsAsFactors = FALSE
  )
  out <- out[!duplicated(out[c("category", "rank")]), ]   # the page repeats cards for mobile
  # keep the page's own category order, ranks ascending within each list
  out$page_order <- match(out$category, unique(out$category))
  out <- out[order(out$page_order, out$rank), ]
  rownames(out) <- NULL
  out
}

top_searches_label <- "คำค้นหายอดนิยม"  # "คำค้นหายอดนิยม"
news_label         <- "ข่าว"                                                          # "ข่าว"

# The list used to represent a year:
#   1. "คำค้นหายอดนิยม" (Top searches), Google's overall list, when the year has one
#   2. otherwise the first list whose name contains "ข่าว" (News), the broadest one left
#      (Thailand 2023 has no overall list)
#   3. otherwise the first list on the page
yis_headline_category <- function(yis) {
  cats <- unique(yis$category)
  if (top_searches_label %in% cats) return(top_searches_label)
  news <- cats[grepl(news_label, cats, fixed = TRUE)]
  if (length(news) > 0) return(news[1])
  cats[1]
}

yis_headline <- function(yis_all, year) {
  y <- yis_all[yis_all$year == year, ]
  y[y$category == yis_headline_category(y), ]
}

# ---- Week list from collected RSS snapshots --------------------------------------

# Top terms over the last `days` days of collected RSS snapshots, ranked by the
# highest approximate search count Google reported, then by how often they appeared.
top_from_rss <- function(rss_hist, days = 7, n = 10) {
  if (is.null(rss_hist) || nrow(rss_hist) == 0) return(NULL)
  t <- as.POSIXct(rss_hist$fetched_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  w <- rss_hist[t > max(t) - days * 86400, ]
  w$key <- tolower(trimws(w$term))
  agg <- do.call(rbind, lapply(split(w, w$key), function(d) data.frame(
    term         = d$term[1],
    traffic      = max(d$traffic, na.rm = TRUE),
    traffic_text = d$traffic_text[which.max(d$traffic)],
    times_seen   = length(unique(d$fetched_at)),
    first_seen   = min(d$fetched_at),
    last_seen    = max(d$fetched_at),
    stringsAsFactors = FALSE)))
  agg <- agg[order(-agg$traffic, -agg$times_seen), ]
  agg$rank <- seq_len(nrow(agg))
  rownames(agg) <- NULL
  head(agg, n)
}

# ---- 3. Explore: interest over time ---------------------------------------------

# Google Trends Explore time windows
explore_windows <- c(
  day   = "now 1-d",      # past 24 hours, ~8-minute points
  week  = "now 7-d",      # past 7 days, hourly points
  year  = "today 12-m",   # past 12 months, weekly points
  five  = "today+5-y"     # past 5 years, weekly/monthly points
)

# Up to 5 terms per request: Google scales them together, so they are comparable
fetch_interest <- function(terms, window) {
  terms <- unique(terms)[seq_len(min(5, length(unique(terms))))]
  res <- gtrendsR::gtrends(keyword = terms, geo = geo, time = window, onlyInterest = TRUE)
  iot <- res$interest_over_time
  if (is.null(iot) || nrow(iot) == 0) stop("Google returned no interest data")
  hits <- suppressWarnings(as.numeric(ifelse(iot$hits == "<1", "0.5", iot$hits)))
  data.frame(date = as.POSIXct(iot$date, tz = "UTC"), term = iot$keyword, index = hits,
             stringsAsFactors = FALSE)
}

# ---- Trend direction (criteria shown in the dashboard) ---------------------------

# Compare the average of the last quarter of the window with the first quarter.
#   Rising  : change >= +20% AND at least +1 index point
#   Falling : change <= -20% AND at least -1 index point
#   Stable  : everything else (near-zero lines don't swing on tiny noise)
# The % uses max(first, 1) as the base so a term starting at 0 doesn't divide by zero.
summarise_trend <- function(iot) {
  if (is.null(iot) || nrow(iot) == 0) return(NULL)
  do.call(rbind, lapply(split(iot, iot$term), function(d) {
    d <- d[order(d$date), ]
    n <- nrow(d); q <- max(1, floor(n / 4))
    first <- mean(d$index[seq_len(q)], na.rm = TRUE)
    last  <- mean(d$index[(n - q + 1):n], na.rm = TRUE)
    change <- (last - first) / max(first, 1) * 100
    diff   <- last - first
    data.frame(
      term       = d$term[1],
      avg_index  = round(mean(d$index, na.rm = TRUE), 1),
      peak_index = max(d$index, na.rm = TRUE),
      peak_date  = d$date[which.max(d$index)],
      change_pct = round(change, 1),
      direction  = if (change >= 20 && diff >= 1) "Rising" else if (change <= -20 && diff <= -1) "Falling" else "Stable",
      stringsAsFactors = FALSE
    )
  }))
}
