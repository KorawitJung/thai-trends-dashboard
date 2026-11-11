# Google Trends ประเทศไทย: วัน · สัปดาห์ · ปี · 5 ปี

> [!WARNING]
> **โปรเจกต์นี้จัดทำขึ้นเพื่อการศึกษาเท่านั้น** ไม่ได้มีเจตนาทำให้บุคคล องค์กร หรือแบรนด์ใดเสียหาย
> ข้อมูลทั้งหมดมาจาก Google Trends ซึ่งเป็นข้อมูลสาธารณะ และโปรเจกต์นี้ไม่ได้เกี่ยวข้องหรือได้รับการรับรองจาก Google
>
> **For educational purposes only.** This project is not intended to harm any person, organization or brand.
> All data comes from publicly available Google Trends data. This project is not affiliated with or endorsed by Google.

## คำอธิบาย (Description)

แดชบอร์ด R Shiny ที่แสดงว่าคนไทยค้นหาอะไรมากที่สุดบน Google ใน 4 ระดับเวลา: วัน, สัปดาห์, ปี และ 5 ปี
บอกว่าค้นหามากแค่ไหน แนวโน้มเพิ่มขึ้นหรือลดลง และแสดงเป็นกราฟเส้น พร้อมระบุแหล่งข้อมูลและเกณฑ์ที่ใช้ทุกขั้นตอน

An R Shiny dashboard showing what Thailand searched for most on Google at four time scales (day, week,
year, 5 years): how big each search was, whether it is rising or falling, and line charts of the trend.
Every number links back to its source and the rule used to rank it.

## วัตถุประสงค์ (Objectives)

1. **ศึกษาความสนใจของคนไทย** ผ่านข้อมูลการค้นหาบน Google ในหลายช่วงเวลา
   *Understand what Thai people care about, through Google search data across time scales.*
2. **ฝึกทักษะงาน Data Analyst ครบวงจร:** ดึงข้อมูลจาก API และเว็บ, เก็บข้อมูลอัตโนมัติ, ทำความสะอาด, วิเคราะห์แนวโน้ม และสร้างแดชบอร์ด
   *Practise the full data-analyst workflow: API and web data collection, scheduled updates, cleaning, trend analysis and dashboarding.*
3. **นำเสนอข้อมูลอย่างโปร่งใส:** ระบุแหล่งที่มา เกณฑ์การจัดอันดับ และข้อจำกัดของข้อมูลให้ผู้อ่านตรวจสอบได้
   *Present data transparently: sources, ranking criteria and limitations are stated so readers can check them.*

## Run

- **Dashboard:** double-click `run_dashboard.bat`, or open `app.R` in RStudio and click **Run App**.
- **Update data:** `Rscript update_data.R` from this folder, or the **Update data** button in the dashboard.
  Run it daily so the week view builds up 7 days of history. On Windows, `update_data.bat` does this and
  appends to `data/update.log`; schedule it with Task Scheduler.

R packages: `shiny`, `bslib`, `plotly`, `DT`, `httr`, `xml2`, `gtrendsR`.

The two `.bat` launchers assume R is installed at `C:\Program Files\R\R-4.5.1`. Edit the path if yours differs.

## Project structure

| File | Purpose |
|---|---|
| `app.R` | Shiny dashboard |
| `R/sources.R` | Data sources (RSS, Year in Search, Google Trends Explore) and trend rules |
| `R/update.R` | Fetches everything and caches it in `data/` |
| `R/about.R` | Disclaimer and project description shown in the dashboard |
| `update_data.R` / `update_data.bat` | Run an update from the command line or Task Scheduler |
| `data/` | Cached data, so the dashboard works right after cloning |

## Sources and criteria

| Level | Ranked list comes from | Ranking rule | Numbers shown | Trend line (Google Trends Explore) |
|---|---|---|---|---|
| Day | [Daily Search Trends RSS, TH](https://trends.google.com/trending/rss?geo=TH) | Approximate search count, high to low | Approximate count (e.g. `2000+`) and 0–100 index | `now 1-d`, about 8-minute points |
| Week | The RSS snapshots collected over the last 7 days | Highest approximate count, then times seen | Highest approximate count and 0–100 index | `now 7-d`, hourly |
| Year | [Year in Search Thailand](https://trends.google.com/trends/yis/2025/TH/) | Google's published rank in "คำค้นหายอดนิยม"; a year without that list falls back to the first "ข่าว" list | 0–100 index only | 1 Jan–31 Dec of that year, weekly |
| 5 years | Year in Search Thailand, one term per year | #1 of each year's list | 0–100 index only | 5 calendar years in one request, weekly |

**Trend direction:** compares the average of the last quarter of the window with the first quarter.
- **Rising:** +20% or more, and at least +1 index point
- **Falling:** −20% or more, and at least −1 index point
- **Stable:** everything else

## Limitations

- **The 0–100 index is relative, not a count.** 100 is the highest point of any term in the same chart, so values can't be compared across charts. Google publishes approximate counts only for current trending searches (day and week).
- **Year in Search ranks the biggest *rise* versus the previous year,** not all-time volume. All-time volume would always be generic words like "youtube" or "หวย".
- **Thailand 2023 has no overall "คำค้นหายอดนิยม" list,** so 2023 uses the "ข่าว" list.
- **Google Trends Explore rate-limits** (HTTP 429). Past years are fetched once and cached in `data/`. A failed refresh keeps the previous data.
- **The data sources are unofficial.** The Explore endpoint (via `gtrendsR`) and the Year in Search page layout are not public APIs and may change without notice.

## License

[MIT](LICENSE). Google Trends data belongs to Google and is subject to Google's terms.
