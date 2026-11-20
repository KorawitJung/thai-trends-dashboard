# Feed URLs and titles must never become markup in the news column.
# Run from the project root:  Rscript tests/test_escaping.R
suppressPackageStartupMessages(library(shiny))
env <- new.env()
for (f in c(list.files("R", full.names = TRUE), "app.R")) sys.source(f, envir = env)
news_link <- env$news_link

check <- function(ok, what) if (!isTRUE(ok)) stop("FAIL: ", what, call. = FALSE) else cat("ok:", what, "\n")

out <- news_link(
  url   = c('https://x.test/a" onmouseover="alert(1)', "javascript:alert(2)", "https://ok.test/x?a=1&b=2", NA, "https://ok.test/y"),
  title = c("quote", "script url", "<b>bold</b>", "no url", NA))

check(!grepl('" onmouseover=', out[1], fixed = TRUE) && grepl("&quot; onmouseover=&quot;", out[1], fixed = TRUE),
      "quote in URL cannot leave the href attribute")
check(out[2] == "script url", "javascript: URL is shown as plain text, not linked")
check(out[3] == '<a href="https://ok.test/x?a=1&amp;b=2" target="_blank" rel="noopener noreferrer">&lt;b&gt;bold&lt;/b&gt;</a>',
      "https link renders with escaped title")
check(out[4] == "no url", "missing URL shows the title only")
check(out[5] == "", "missing title shows nothing")
cat("all escaping checks passed\n")
