# TFOSvMF — Thai Mutual Fund

CLI แบบ read-only สำหรับดาวน์โหลดข้อมูลกองทุนจาก Google Sheets, ดึง NAV/PTR จาก SEC Open API และแสดงผลเป็น Markdown ใน Terminal

## Runtime

- Bash และ `curl`
- Python 3
- Python packages: `openpyxl`, `requests`
- ไม่มีไฟล์ `.py` แยก: logic อยู่ใน [fund_update.sh](./fund_update.sh) แบบ inline Python heredoc

สร้าง environment ตามต้องการ:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install openpyxl requests
```

หากมี `.venv/` สคริปต์จะใช้ `.venv/bin/python` อัตโนมัติ

## ตั้งค่า

สร้าง `.env` และเก็บไว้ในเครื่องเท่านั้น:

```dotenv
SET_DATA_URL=https://docs.google.com/spreadsheets/d/<SHEET_ID>/edit
SET_DATA_SHEET=All-ThaiMutualFunds-MTFS
SEC_API_KEY_FUND=<SEC_API_KEY>
```

ชีตต้องมีคอลัมน์ `AKA` และ `PROJECT ID` ภายใน 10 แถวแรก และต้องระบุ SEC project ID ในทุกกองทุนที่ต้องการประมวลผล

## คำสั่ง

```bash
./update.sh
./update.sh UPDATE/B-INNOTECH
./update.sh "UPDATE/ASP-DAPP 3M5"
./candidate.sh
```

ทุกรอบดาวน์โหลด XLSX ใหม่และบันทึก snapshot ที่ `downloads/All-ThaiMutualFunds-MTFS.xlsx`; หากดาวน์โหลดไม่สำเร็จจะหยุดและไม่ใช้ snapshot เก่าแทน

## Output มาตรฐาน

`UPDATE/<AKA>` แสดง metadata ต่อกองทุนก่อนตาราง:

```text
AKA         : <AKA>
LAST_CANDLE : <วันที่ NAV ล่าสุด> (NAV รายวัน)
UPDATED     : <เวลาประเทศไทย>
PROJECT ID  : <PROJECT ID>

🔵 SPECIFIED FUND — <จำนวน> รายการ
```

ตารางใช้คอลัมน์ `AKA | PROJECT ID | RSI(W) | RSI(1H) | MACD Δ(W) | NAV | BIAS(W) | SETUP(D) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | ACTION | PTR (latest Factsheet)` และ AKA เป็นลิงก์ Finnomena

## ขอบเขตและข้อจำกัด

- NAV ใช้ข้อมูลรายวันจาก SEC ย้อนหลังประมาณ 5 ปี; W ใช้ bucket 30 วัน
- ค่าทางเทคนิคและ ACTION เป็น heuristic ไม่ใช่คำแนะนำการลงทุน
- ระบบไม่เขียนกลับ Google Sheets และไม่ส่งคำสั่งซื้อขาย
- PTR คือ `portfolio_turnover_ratio` จาก SEC Factsheet; หากอ่านไม่ได้แสดง `N/A`
- `CANDIDATE` เป็น entrypoint ที่สงวนไว้สำหรับการพัฒนาต่อ และไม่แสดงรายการกองทุนในรุ่นนี้
