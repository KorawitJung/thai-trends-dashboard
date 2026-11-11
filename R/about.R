# Disclaimer and project description shown in the dashboard (Thai, with English).
# Keep in sync with README.md.

disclaimer_banner <- function() {
  div(
    class = "alert alert-warning py-2 px-3 mb-3 small",
    role = "note",
    tags$strong("⚠ คำเตือน / Disclaimer: "),
    "โปรเจกต์นี้จัดทำขึ้นเพื่อการศึกษาเท่านั้น ไม่ได้มีเจตนาทำให้บุคคล องค์กร หรือแบรนด์ใดเสียหาย ",
    "ข้อมูลมาจาก Google Trends ซึ่งเป็นข้อมูลสาธารณะ และโปรเจกต์นี้ไม่ได้เกี่ยวข้องหรือได้รับการรับรองจาก Google ",
    tags$span(class = "text-muted",
      "(For educational purposes only. Not intended to harm any person, organization or brand. ",
      "Not affiliated with or endorsed by Google.)")
  )
}

about_card <- function() {
  card(
    card_header("เกี่ยวกับโปรเจกต์ (About this project)"),
    p("แดชบอร์ดนี้แสดงว่าคนไทยค้นหาอะไรมากที่สุดบน Google ในระดับวัน สัปดาห์ ปี และ 5 ปี ",
      "ค้นหามากแค่ไหน และแนวโน้มเพิ่มขึ้นหรือลดลง พร้อมระบุแหล่งข้อมูลและเกณฑ์ที่ใช้ทุกขั้นตอน"),
    tags$h6("วัตถุประสงค์ (Objectives)"),
    tags$ol(
      tags$li("ศึกษาความสนใจของคนไทยผ่านข้อมูลการค้นหาบน Google ในหลายช่วงเวลา"),
      tags$li("ฝึกทักษะงาน Data Analyst ครบวงจร: ดึงข้อมูลจาก API และเว็บ, เก็บข้อมูลอัตโนมัติ, ทำความสะอาด, วิเคราะห์แนวโน้ม และสร้างแดชบอร์ด"),
      tags$li("นำเสนอข้อมูลอย่างโปร่งใส: ระบุแหล่งที่มา เกณฑ์การจัดอันดับ และข้อจำกัดของข้อมูลให้ผู้อ่านตรวจสอบได้")
    ),
    disclaimer_banner()
  )
}
