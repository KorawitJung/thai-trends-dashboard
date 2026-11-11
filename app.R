# Thailand Google Trends dashboard: what Thais searched most, at day / week /
# year / 5-year level, how big it was, and whether it is rising or falling.
#
# Run: double-click run_dashboard.bat, or open this file in RStudio and click "Run App".
# Data comes from data/ (filled by update_data.R or the "Update data" button).
# R/sources.R and R/update.R are loaded automatically by Shiny.

library(shiny)
library(bslib)
library(plotly)
library(DT)
library(htmltools)

tz_th <- "Asia/Bangkok"
line_colors <- c("#bf4520", "#2e5aa8", "#7c8f6f", "#b8915a", "#6e6479")

direction_th <- c(Rising = "▲ เพิ่มขึ้น",   # ▲ เพิ่มขึ้น
                  Falling = "▼ ลดลง",                                    # ▼ ลดลง
                  Stable = "► คงที่")                                # ► คงที่

# ---- Helpers ------------------------------------------------------------------

# Line chart of 0-100 interest for up to 5 terms
interest_chart <- function(cache, local_time = FALSE) {
  d <- cache$data
  if (local_time) {
    # show Thai local time on the axis
    d$date <- as.POSIXct(format(d$date, tz = tz_th), tz = "UTC")
  }
  terms <- cache$terms
  p <- plot_ly()
  for (i in seq_along(terms)) {
    di <- d[d$term == terms[i], ]
    p <- add_lines(p, data = di, x = ~date, y = ~index, name = terms[i],
                   line = list(color = line_colors[i], width = if (i == 1) 3 else 1.8),
                   hovertemplate = paste0("<b>", htmlEscape(terms[i]), "</b><br>%{x}<br>index %{y}<extra></extra>"))
  }
  layout(p,
         xaxis = list(title = if (local_time) "เวลาประเทศไทย (UTC+7)" else ""),
         yaxis = list(title = "Google Trends index (0–100)", range = c(0, 105)),
         legend = list(orientation = "h", y = -0.2),
         hovermode = "x unified")
}

# Join the ranked list with trend statistics computed from the cached line data
with_trend <- function(list_df, cache) {
  tr <- summarise_trend(if (is.null(cache)) NULL else cache$data)
  if (is.null(tr)) {
    list_df$avg_index <- NA; list_df$peak_index <- NA; list_df$peak_date <- NA
    list_df$change_pct <- NA; list_df$direction <- NA
    return(list_df)
  }
  merge(list_df, tr, by = "term", all.x = TRUE, sort = FALSE)
}

trend_columns <- function(d, date_fmt) {
  data.frame(
    `ดัชนีเฉลี่ย (0–100)` = d$avg_index,                        # ดัชนีเฉลี่ย
    `ดัชนีสูงสุด` = d$peak_index,                                    # ดัชนีสูงสุด
    `ช่วงที่สูงสุด` =                                       # ช่วงที่สูงสุด
      ifelse(is.na(d$peak_date), "-", format(as.POSIXct(d$peak_date, origin = "1970-01-01", tz = "UTC"), date_fmt, tz = tz_th)),
    `เปลี่ยนแปลง %` = ifelse(is.infinite(d$change_pct), "new", d$change_pct), # เปลี่ยนแปลง %
    `แนวโน้ม` = ifelse(is.na(d$direction), "-", direction_th[d$direction]),             # แนวโน้ม
    check.names = FALSE
  )
}

no_data_msg <- "ยังไม่มีข้อมูลเส้นแนวโน้ม กด Update data หรือรัน update_data.R"
# "ยังไม่มีข้อมูลเส้นแนวโน้ม กด Update data หรือรัน update_data.R"

source_note <- function(...) div(class = "small text-muted mt-2", ...)

# ---- UI -----------------------------------------------------------------------

period_tab <- function(id, title, intro, controls = NULL) {
  nav_panel(
    title = title,
    p(class = "lead mb-2", intro),
    controls,
    layout_columns(
      col_widths = c(5, 4, 3),
      value_box(title = "อันดับ 1", value = textOutput(paste0(id, "_top")), theme = "primary"),   # อันดับ 1
      value_box(title = textOutput(paste0(id, "_size_label")), value = textOutput(paste0(id, "_size")), theme = "info"),
      value_box(title = "แนวโน้มของอันดับ 1",   # แนวโน้มของอันดับ 1
                value = textOutput(paste0(id, "_dir")), theme = "secondary")
    ),
    card(
      full_screen = TRUE,
      card_header(textOutput(paste0(id, "_chart_title"), inline = TRUE)),
      plotlyOutput(paste0(id, "_chart"), height = "430px"),
      uiOutput(paste0(id, "_chart_note"))
    ),
    card(
      card_header("อันดับคำค้นหา"),   # อันดับคำค้นหา
      DTOutput(paste0(id, "_table")),
      uiOutput(paste0(id, "_source"))
    )
  )
}

ui <- page_navbar(
  title = "Google Trends ประเทศไทย",   # Google Trends ประเทศไทย
  theme = bs_theme(version = 5, bootswatch = "flatly",
                   base_font = font_google("Sarabun", local = FALSE),
                   heading_font = font_google("Sarabun", local = FALSE)),
  fillable = FALSE,
  header = div(class = "container-fluid pt-3", disclaimer_banner()),   # shown above every tab

  period_tab("day", "วัน",          # วัน
             "คำค้นหาที่มาแรงที่สุดในไทย 24 ชั่วโมงล่าสุด"),
             # คำค้นหาที่มาแรงที่สุดในไทย 24 ชั่วโมงล่าสุด
  period_tab("week", "สัปดาห์",   # สัปดาห์
             "คำค้นหาที่มาแรงที่สุดในไทย 7 วันล่าสุด"),
             # คำค้นหาที่มาแรงที่สุดในไทย 7 วันล่าสุด
  period_tab("year", "ปี",               # ปี
             "คำค้นหายอดนิยมประจำปีจาก Google Year in Search",
             # คำค้นหายอดนิยมประจำปีจาก Google Year in Search
             controls = layout_columns(
               col_widths = c(3, 9),
               selectInput("year_sel", "ปี", choices = NULL),
               selectInput("year_cat", "หมวดหมู่ (ตารางด้านล่าง)", choices = NULL)
               # หมวดหมู่ (ตารางด้านล่าง)
             )),
  period_tab("five", "5 ปี",             # 5 ปี
             "คำค้นหาอันดับ 1 ของแต่ละปี เทียบกันตลอด 5 ปี"),
             # คำค้นหาอันดับ 1 ของแต่ละปี เทียบกันตลอด 5 ปี

  nav_panel(
    title = "แหล่งข้อมูลและเกณฑ์",   # แหล่งข้อมูลและเกณฑ์
    about_card(),
    card(card_header("แหล่งข้อมูลและเกณฑ์ที่ใช้"),
         DTOutput("criteria_tbl")),
    card(card_header("สิ่งที่ควรรู้"),   # สิ่งที่ควรรู้
         uiOutput("caveats")),
    card(card_header("อัปเดตล่าสุด"),         # อัปเดตล่าสุด
         tableOutput("freshness"))
  ),

  nav_spacer(),
  nav_item(actionButton("update", "Update data", icon = icon("rotate"), class = "btn-sm btn-outline-light"))
)

# ---- Server -------------------------------------------------------------------

server <- function(input, output, session) {

  reload <- reactiveVal(0)

  observeEvent(input$update, {
    withProgress(message = "Updating from Google...", value = 0.1, {
      status <- run_update(log = function(m) incProgress(0.08, detail = m), pause = 5)
    })
    failed <- names(status)[!unlist(status)]
    if (length(failed) > 0) {
      showNotification(paste("Some sources failed (kept previous data):", paste(failed, collapse = ", ")),
                       type = "warning", duration = 10)
    } else {
      showNotification("Data updated", type = "message")
    }
    reload(reload() + 1)
  })

  rss_hist <- reactive({ reload(); read_rss_history() })
  yis      <- reactive({
    reload()
    if (file.exists(yis_file)) utils::read.csv(yis_file, stringsAsFactors = FALSE, fileEncoding = "UTF-8") else NULL
  })
  cache <- function(key) reactive({ reload(); read_interest(key) })
  day_cache  <- cache("day")
  week_cache <- cache("week")
  five_cache <- cache("five")
  year_cache <- reactive({ reload(); req(input$year_sel); read_interest(paste0("year_", input$year_sel)) })

  # Year selectors
  observe({
    y <- yis(); req(y)
    years <- sort(unique(y$year), decreasing = TRUE)
    sel <- isolate(input$year_sel)
    if (is.null(sel) || !(sel %in% years)) sel <- years[1]   # empty select starts as "" not NULL
    updateSelectInput(session, "year_sel", choices = years, selected = sel)
  })
  observe({
    y <- yis(); req(y, input$year_sel)
    yy <- y[y$year == input$year_sel, ]
    head_cat <- yis_headline_category(yy)
    updateSelectInput(session, "year_cat", choices = unique(yy$category), selected = head_cat)
  })

  # ---- Ranked lists per period ----
  lists <- list(
    day = reactive({
      h <- rss_hist(); req(h)
      latest <- rank_by_volume(h[h$fetched_at == max(h$fetched_at), ])
      latest[seq_len(min(10, nrow(latest))), ]
    }),
    week = reactive({ top_from_rss(rss_hist(), days = 7, n = 10) }),
    year = reactive({ y <- yis(); req(y, input$year_sel); yis_headline(y, as.integer(input$year_sel)) }),
    five = reactive({
      y <- yis(); req(y)
      do.call(rbind, lapply(sort(unique(y$year)), function(yr) {
        h <- yis_headline(y, yr)[1, ]
        data.frame(year = yr, term = h$term, category = h$category, stringsAsFactors = FALSE)
      }))
    })
  )
  caches <- list(day = day_cache, week = week_cache, year = year_cache, five = five_cache)

  for (id in names(lists)) local({
    pid <- id
    lst <- lists[[pid]]
    cch <- caches[[pid]]

    top_trend <- reactive({
      l <- lst(); c <- cch()
      if (is.null(c)) return(NULL)
      tr <- summarise_trend(c$data)
      tr[tr$term == l$term[1], ]
    })

    output[[paste0(pid, "_top")]] <- renderText({ l <- lst(); if (is.null(l) || nrow(l) == 0) "-" else l$term[1] })

    output[[paste0(pid, "_size_label")]] <- renderText({
      if (pid %in% c("day", "week")) "จำนวนการค้นหา (โดยประมาณ)"   # จำนวนการค้นหา (โดยประมาณ)
      else "ดัชนีเฉลี่ย (0–100)"                                                                                          # ดัชนีเฉลี่ย (0–100)
    })
    output[[paste0(pid, "_size")]] <- renderText({
      l <- lst()
      if (pid %in% c("day", "week")) {
        if (is.null(l) || nrow(l) == 0) "-" else paste(l$traffic_text[1], "ครั้ง")  # ครั้ง
      } else {
        t <- top_trend(); if (is.null(t) || nrow(t) == 0) "-" else t$avg_index
      }
    })
    output[[paste0(pid, "_dir")]] <- renderText({
      t <- top_trend(); if (is.null(t) || nrow(t) == 0) "-" else
        sprintf("%s (%s%%)", direction_th[[t$direction]], if (is.infinite(t$change_pct)) "new" else t$change_pct)
    })

    output[[paste0(pid, "_chart_title")]] <- renderText({
      c <- cch()
      if (is.null(c)) "เส้นแนวโน้ม" else   # เส้นแนวโน้ม
        sprintf("เส้นแนวโน้ม 5 คำแรก · %s", c$label)
    })
    output[[paste0(pid, "_chart")]] <- renderPlotly({
      c <- cch()
      validate(need(!is.null(c), no_data_msg))
      interest_chart(c, local_time = pid %in% c("day", "week"))
    })
    output[[paste0(pid, "_chart_note")]] <- renderUI({
      c <- cch(); req(c)
      source_note(sprintf(
        "Google Trends Explore · geo = TH · time = \"%s\" · ดึงข้อมูลเมื่อ %s (UTC) · ดัชนี 100 = จุดที่คนค้นมากที่สุดของทุกคำในกราฟนี้",
        c$window, sub("T", " ", sub("Z", "", c$fetched_at))))
      # ดึงข้อมูลเมื่อ ... · ดัชนี 100 = จุดที่คนค้นมากที่สุดของทุกคำในกราฟนี้
    })
  })

  # ---- Tables ----
  output$day_table <- renderDT({
    l <- lists$day(); d <- with_trend(l, day_cache())
    d <- d[order(d$rank), ]
    news <- ifelse(is.na(d$news_title), "",
                   sprintf('<a href="%s" target="_blank">%s</a>', htmlEscape(d$news_url), htmlEscape(d$news_title)))
    out <- cbind(data.frame(`อันดับ` = d$rank, `คำค้นหา` = htmlEscape(d$term),
                            `จำนวนการค้นหา` = d$traffic_text,
                            `ลำดับในฟีด Google` = d$google_rank,   # ลำดับในฟีด Google
                            check.names = FALSE),
                 trend_columns(d, "%d/%m %H:%M"),
                 data.frame(`ข่าวที่เกี่ยวข้อง` = news, check.names = FALSE))
    datatable(out, rownames = FALSE, escape = FALSE, options = list(dom = "t", pageLength = 10, ordering = FALSE))
  })
  output$day_source <- renderUI(source_note(
    HTML('รายการคำ: <a href="https://trends.google.com/trending/rss?geo=TH" target="_blank">Google Trends Daily Search Trends RSS (TH)</a> · เรียงตามจำนวนการค้นหาโดยประมาณ (เท่ากันใช้ลำดับในฟีด) · เส้นแนวโน้มแสดง 5 คำแรก')))
    # รายการคำ: ... · เรียงตามลำดับที่ Google จัด · เส้นแนวโน้มแสดง 5 คำแรก

  output$week_table <- renderDT({
    l <- lists$week()
    validate(need(!is.null(l), no_data_msg))
    d <- with_trend(l, week_cache()); d <- d[order(d$rank), ]
    out <- cbind(data.frame(`อันดับ` = d$rank, `คำค้นหา` = htmlEscape(d$term),
                            `จำนวนการค้นหา (สูงสุด)` = d$traffic_text,
                            `พบในการเก็บ (ครั้ง)` = d$times_seen, check.names = FALSE),
                 trend_columns(d, "%d/%m %H:%M"))
    datatable(out, rownames = FALSE, escape = FALSE, options = list(dom = "t", pageLength = 10, ordering = FALSE))
  })
  output$week_source <- renderUI({
    h <- rss_hist(); req(h)
    t <- as.POSIXct(h$fetched_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    w <- t > max(t) - 7 * 86400
    days <- as.numeric(difftime(max(t[w]), min(t[w]), units = "days"))
    source_note(HTML(sprintf(
      'รวมจาก RSS ที่เก็บไว้ %d ครั้งใน 7 วันล่าสุด (ครอบคลุม %.1f วัน) · เรียงตามจำนวนการค้นหาสูงสุดที่ Google รายงาน แล้วตามจำนวนครั้งที่พบ%s',
      length(unique(h$fetched_at[w])), days,
      if (days < 6) " · <b>ยังเก็บไม่ครบ 7 วัน รัน update_data.R ทุกวันเพื่อให้ครบ</b>" else "")))
    # รวมจาก RSS ที่เก็บไว้ N ครั้งใน 7 วันล่าสุด (ครอบคลุม X วัน) · เรียงตามจำนวนการค้นหาสูงสุดที่ Google รายงาน แล้วตามจำนวนครั้งที่พบ
    # · ยังเก็บไม่ครบ 7 วัน รัน update_data.R ทุกวันเพื่อให้ครบ
  })

  output$year_table <- renderDT({
    y <- yis(); req(y, input$year_sel, input$year_cat)
    l <- y[y$year == input$year_sel & y$category == input$year_cat, ]
    d <- with_trend(l, year_cache()); d <- d[order(d$rank), ]
    out <- cbind(data.frame(`อันดับ` = d$rank, `คำค้นหา` = htmlEscape(d$term), check.names = FALSE),
                 trend_columns(d, "%d/%m/%Y"))
    datatable(out, rownames = FALSE, escape = FALSE, options = list(dom = "t", pageLength = 10, ordering = FALSE))
  })
  output$year_source <- renderUI({
    y <- yis(); req(y, input$year_sel)
    yy <- y[y$year == input$year_sel, ]
    head_cat <- yis_headline_category(yy)
    note <- if (head_cat != top_searches_label)
      sprintf(" · <b>ปี %s Google ไม่มีหมวด \"%s\" จึงใช้หมวด \"%s\" แทน</b>",
              input$year_sel, top_searches_label, head_cat) else ""
      # ปี X Google ไม่มีหมวด "คำค้นหายอดนิยม" จึงใช้หมวด "..." แทน
    source_note(HTML(sprintf(
      'รายการคำ: <a href="%s" target="_blank">Google Year in Search %s · Thailand</a> · อันดับตามที่ Google เผยแพร่ (คำที่คนค้นเพิ่มขึ้นมากที่สุดเทียบกับปีก่อน) · เส้นแนวโน้มแสดง 5 คำแรกของหมวด "%s"%s',
      year_in_search_url(as.integer(input$year_sel)), input$year_sel, head_cat, note)))
    # รายการคำ: Google Year in Search ปี · Thailand · อันดับตามที่ Google เผยแพร่ (คำที่คนค้นเพิ่มขึ้นมากที่สุดเทียบกับปีก่อน) · เส้นแนวโน้มแสดง 5 คำแรกของหมวด "..."
  })

  output$five_table <- renderDT({
    l <- lists$five(); d <- with_trend(l, five_cache()); d <- d[order(d$year), ]
    out <- cbind(data.frame(`ปี` = d$year, `คำค้นหาอันดับ 1` = htmlEscape(d$term),
                            `หมวด` = d$category, check.names = FALSE),
                 trend_columns(d, "%m/%Y"))
    datatable(out, rownames = FALSE, escape = FALSE, options = list(dom = "t", ordering = FALSE))
  })
  output$five_source <- renderUI(source_note(HTML(
    'รายการคำ: อันดับ 1 จากหมวดหลักของ Google Year in Search Thailand แต่ละปี · ทั้ง 5 คำดึงในคำขอเดียวกัน จึงเทียบกันได้ตรงๆ')))
    # รายการคำ: อันดับ 1 จากหมวดหลักของ Google Year in Search Thailand แต่ละปี · ทั้ง 5 คำดึงในคำขอเดียวกัน จึงเทียบกันได้ตรงๆ

  # ---- Sources & criteria tab ----
  output$criteria_tbl <- renderDT({
    out <- data.frame(
      `ระดับ` = c("วัน", "สัปดาห์", "ปี", "5 ปี"),
      `รายการคำมาจาก` = c(
        '<a href="https://trends.google.com/trending/rss?geo=TH" target="_blank">Daily Search Trends RSS</a>',
        "RSS ที่เก็บสะสม 7 วัน",
        '<a href="https://trends.google.com/trends/yis/2025/TH/" target="_blank">Year in Search Thailand</a>',
        "Year in Search Thailand 5 ปี"),
      `เกณฑ์จัดอันดับ` = c(
        "จำนวนการค้นหาโดยประมาณ จากมากไปน้อย (10 คำในฟีด)",
        "จำนวนการค้นหาสูงสุด แล้วจำนวนครั้งที่พบ",
        "อันดับที่ Google เผยแพร่ หมวด คำค้นหายอดนิยม (ปีที่ไม่มี ใช้หมวด ข่าว)",
        "อันดับ 1 ของแต่ละปี"),
      `ตัวเลขที่แสดง` = c(
        "จำนวนการค้นหาโดยประมาณ (เช่น 1000+) + ดัชนี 0–100",
        "จำนวนการค้นหาโดยประมาณ (สูงสุด) + ดัชนี 0–100",
        "ดัชนี 0–100 เท่านั้น (Google ไม่เปิดเผยจำนวนจริง)",
        "ดัชนี 0–100 เท่านั้น"),
      `เส้นแนวโน้ม (Explore)` = c(
        "now 1-d · ทุก 8 นาที", "now 7-d · รายชั่วโมง",
        "1 ม.ค.–31 ธ.ค. ของปีนั้น · รายสัปดาห์",
        "5 ปีปฏิทิน · รายสัปดาห์"),
      check.names = FALSE)
    datatable(out, rownames = FALSE, escape = FALSE, options = list(dom = "t", ordering = FALSE))
  })

  output$caveats <- renderUI(tags$ul(
    tags$li(HTML("<b>ดัชนี 0–100</b> เป็นค่าสัมพัทธ์ ไม่ใช่จำนวนครั้ง: 100 คือจุดที่คนค้นมากที่สุดในกราฟเดียวกัน เทียบข้ามกราฟไม่ได้")),
    # ดัชนี 0–100 เป็นค่าสัมพัทธ์ ไม่ใช่จำนวนครั้ง: 100 คือจุดที่คนค้นมากที่สุดในกราฟเดียวกัน เทียบข้ามกราฟไม่ได้
    tags$li(HTML("<b>แนวโน้ม</b> = ค่าเฉลี่ย 1/4 ท้ายของช่วงเวลา เทียบกับ 1/4 แรก: เพิ่ม ≥ 20% = เพิ่มขึ้น, ลด ≥ 20% = ลดลง, นอกนั้น = คงที่ (ต้องต่างกันอย่างน้อย 1 จุดดัชนีด้วย)")),
    # แนวโน้ม = ค่าเฉลี่ย 1/4 ท้ายของช่วงเวลา เทียบกับ 1/4 แรก: เพิ่ม ≥ 20% = เพิ่มขึ้น, ลด ≥ 20% = ลดลง, นอกนั้น = คงที่
    tags$li(HTML("<b>Year in Search</b> จัดอันดับคำที่คนค้น<b>เพิ่มขึ้น</b>มากที่สุดเทียบกับปีก่อน ไม่ใช่คำที่คนค้นมากที่สุดตลอดกาล (ซึ่งจะเป็นคำทั่วไปเช่น \"youtube\" หรือ \"หวย\")")),
    # Year in Search จัดอันดับคำที่คนค้นเพิ่มขึ้นมากที่สุดเทียบกับปีก่อน ไม่ใช่คำที่คนค้นมากที่สุดตลอดกาล (ซึ่งจะเป็นคำทั่วไปเช่น "youtube" หรือ "หวย")
    tags$li(HTML("ปี 2023 Google ไม่มีหมวด คำค้นหายอดนิยม สำหรับไทย จึงใช้หมวด ข่าว แทน")),
    # ปี 2023 Google ไม่มีหมวด คำค้นหายอดนิยม สำหรับไทย จึงใช้หมวด ข่าว แทน
    tags$li(HTML("จำนวนการค้นหาจริงมีเฉพาะระดับวันและสัปดาห์ และเป็นช่วงหยาบ (100+, 200+, 1000+ ...) ตามที่ Google รายงาน"))
    # จำนวนการค้นหาจริงมีเฉพาะระดับวันและสัปดาห์ และเป็นช่วงหยาบ (100+, 200+, 1000+ ...) ตามที่ Google รายงาน
  ))

  output$freshness <- renderTable({
    reload()
    keys <- c("day", "week", paste0("year_", sort(unique(yis()$year))), "five")
    data.frame(
      `ข้อมูล` = c("RSS", keys),
      `ดึงล่าสุด (UTC)` = c(
        { h <- rss_hist(); if (is.null(h)) "-" else sub("T", " ", sub("Z", "", max(h$fetched_at))) },
        vapply(keys, function(k) { c <- read_interest(k); if (is.null(c)) "-" else sub("T", " ", sub("Z", "", c$fetched_at)) }, character(1))),
      check.names = FALSE)
  })
}

shinyApp(ui, server)
