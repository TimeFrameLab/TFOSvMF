# TimeFrame OS vMF guidelines

## 📋 สถานะและขอบเขต

TFOSvMF เป็น read-only CLI สำหรับข้อมูลกองทุนรวมไทย ไม่ใช่ระบบส่งคำสั่งซื้อขายและไม่ใช่คำแนะนำการลงทุน

แหล่งข้อมูลที่ใช้มีสองส่วน:

- Google Sheets เป็น Reference Sheet และ snapshot ล่าสุดของข้อมูลกองทุนกับ signals
- SEC Open API เป็นแหล่งข้อมูล NAV และ PTR จาก Factsheet

ระบบไม่เขียนกลับ Google Sheets ไม่ส่งคำสั่งซื้อขาย และไม่ใช้ snapshot เก่าแทน snapshot ที่ดาวน์โหลดไม่สำเร็จ

## 🔔 Runtime และคำสั่ง

Logic ทั้งหมดอยู่ใน [fund_update.sh](./fund_update.sh) ซึ่งเป็น Bash wrapper ที่ฝัง Python inline ไม่มี source `.py` แยกและไม่มี Ruby runtime

| คำสั่ง | วิธีใช้ | หน้าที่ |
|---|---|---|
| `START @README.md` | พิมพ์ในแชต | อ่าน README และ guideline ก่อนรอคำสั่ง |
| `UPDATE` | `./update.sh` | ดาวน์โหลด snapshot ใหม่ ดึง NAV/PTR และแสดงรายงานกองทุน |
| `UPDATE/<AKA>` | `./update.sh UPDATE/B-INNOTECH` | แสดงรายงานเฉพาะกองทุนที่ระบุ |
| `CANDIDATE` | `./candidate.sh` | คัดรายการตามเกณฑ์ CANDIDATE 7 ข้อจาก snapshot |
| `REVIEW` | พิมพ์ในแชต | ทบทวน guideline อีกครั้ง |

ทุกคำสั่งที่ใช้ข้อมูลต้องดาวน์โหลด Google Sheets XLSX ใหม่ก่อนทำงาน และหยุดเมื่อดาวน์โหลดหรืออ่าน workbook ไม่สำเร็จ

## 🔄 Data flow

### UPDATE และ UPDATE/<AKA>

1. โหลด `.env`
2. ดาวน์โหลด Google Sheets XLSX ใหม่
3. ตรวจพบคอลัมน์ `AKA` และ `PROJECT ID` ภายใน 10 แถวแรก
4. เลือกกองทุนทั้งหมดหรือเลือกตาม `UPDATE/<AKA>`
5. เรียก SEC NAV API ย้อนหลังประมาณ 5 ปีต่อ `PROJECT ID`
6. คำนวณ RSI และ MACD delta จาก NAV
7. ใช้ bucket NAV ประมาณ 30 วันเป็นชุดข้อมูล W
8. เรียก SEC Factsheet statistics เพื่ออ่าน `portfolio_turnover_ratio`
9. แสดง Markdown report ตาม schema ของคำสั่ง

### CANDIDATE

`CANDIDATE` ใช้ signal columns จาก snapshot ที่ดาวน์โหลดล่าสุด ไม่คำนวณ signal ใหม่จาก NAV API โดยตรง:

1. ตรวจว่ามีคอลัมน์สำหรับเกณฑ์ Candidate และ entry labels
2. ตรวจแต่ละแถวตามเกณฑ์ 7 ข้อ
3. เรียงผู้ผ่านตาม `MACD_HIST_DELTA(W)` จากมากไปน้อย
4. แสดงจำนวนผู้ผ่านทั้งหมด แต่แสดงตารางไม่เกิน 10 อันดับ
5. ใช้ `PROJECT ID` เป็นค่า `Tier`
6. เรียก SEC Factsheet statistics ล่าสุดเฉพาะรายการที่แสดง
7. แสดง `⚫ N/A` และคำเตือนเมื่อไม่มี PTR ที่ยืนยันได้

## 📐 เกณฑ์ CANDIDATE 7 ข้อ

รายการต้องผ่านทุกข้อดังนี้:

1. `TREND(W) = UP`
2. `TREND(D) = UP`
3. `RSI(W) > 50`
4. `MACD_HIST_DELTA(W) > 0`
5. `RSI(D) < 70`
6. `EMA9(W) > EMA21(W)`
7. `SIGNAL_VOLUME` เป็น `BUY` อย่างน้อยหนึ่ง timeframe ใน `W`, `D`, `4H` หรือ `1H`

หาก snapshot ขาดคอลัมน์ที่จำเป็น ระบบต้องหยุดและรายงานชื่อคอลัมน์ที่ขาด ห้ามคาดเดาหรือใช้ค่าเก่าทดแทน

## ⏱️ Timeframe labels

- `W`: timeframe ระยะยาวจากข้อมูลใน snapshot หรือ bucket NAV ประมาณ 30 วันใน UPDATE
- `D`: timeframe รายวันของ signal และ setup ใน snapshot
- `4H`: label ของ `ENTRY_ZONE(4H)` จาก snapshot
- `1H`: label ของ `ENTRY_TRIGGER(1H)` และ signal volume ใน snapshot

ชื่อ timeframe เป็น label เชิงโมเดล ไม่ได้หมายความว่า SEC มี NAV intraday หรือข้อมูล OHLCV intraday ให้ระบบโดยตรง

## 📊 Output Contract

### UPDATE

ใช้ลิงก์ Finnomena และคอลัมน์ตามลำดับนี้:

`AKA | PROJECT ID | RSI(W) | RSI(D) | MACD Δ(W) | NAV | BIAS(W) | SETUP(D) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | ACTION | PTR (latest Factsheet)`

### UPDATE/<AKA>

ต้องแสดง metadata ของแต่ละ AKA ตามลำดับที่ขอ ก่อนตาราง:

```text
AKA         : <AKA>
LAST_CANDLE : <วันที่ NAV ล่าสุด> (NAV รายวัน)
UPDATED     : <เวลาประเทศไทย>
PROJECT ID  : <PROJECT ID>
```

จากนั้นแสดง `🔵 SPECIFIED FUND — n รายการ` และใช้ schema เดียวกับ UPDATE โดยคอลัมน์ RSI ระยะสั้นใช้ `RSI(1H)` ตาม output ของคำสั่ง

ชื่อกองทุนใน UPDATE และ UPDATE/<AKA> ต้องเป็นลิงก์รูปแบบ:

`https://www.finnomena.com/fund/<AKA>/graph`

### CANDIDATE

ต้องแสดงหัวข้อและคำอธิบายตามนี้:

```text
ผลการค้นหา CANDIDATE (PRE-ENTRY-Like Pattern) — n เหรียญ
ผ่านเกณฑ์ CANDIDATE 7 ข้อ เรียงตาม MACD Delta (W) สูงสุด — รอ 1H Trigger ยืนยัน
```

ตารางต้องใช้คอลัมน์ตามลำดับนี้และแสดงไม่เกิน 10 อันดับ:

`# | เหรียญ | Tier | ราคา (THB) | MACD Δ(W) | Entry Zone (4H) | 1H Trigger | Liquidity(PTR (latest Factsheet))`

- `n` คือจำนวนผู้ผ่านเกณฑ์ทั้งหมดก่อนจำกัด 10 อันดับ
- ชื่อรายการเป็นลิงก์ TradingView รูปแบบ `https://www.tradingview.com/symbols/<AKA>/`
- `Tier = PROJECT ID`
- `Liquidity(PTR (latest Factsheet))` ใช้ `portfolio_turnover_ratio` ล่าสุดจาก SEC Factsheet
- หากไม่มี PTR ที่ยืนยันได้ ให้แสดง `⚫ N/A` และคำเตือนท้ายรายงาน
- ห้ามเพิ่ม metadata `ADVANC` หรือกลุ่มรายงานของ UPDATE ใน CANDIDATE

## 💧 PTR และข้อผิดพลาดข้อมูล

PTR คือค่า `portfolio_turnover_ratio` จาก SEC Factsheet statistics แบบ read-only ไม่ใช่ระดับสภาพคล่องที่ระบบอนุมานเอง

- มีข้อมูล: แสดงค่าที่ SEC ส่งกลับ และวันที่เริ่มต้นของสถิติถ้ามี
- ไม่มีข้อมูลหรือเรียก API ไม่สำเร็จ: แสดง `⚫ N/A`
- ห้ามใช้ snapshot เก่าหรือคาดเดาค่า PTR
- หากมีรายการที่ PTR ไม่พร้อมใช้งาน ต้องแสดงคำเตือนท้ายรายงาน

เมื่อข้อมูลหลักไม่พร้อมใช้งาน เช่น ดาวน์โหลดไม่ได้, workbook อ่านไม่ได้, ไม่มีคอลัมน์จำเป็น, ไม่พบ AKA หรือ SEC ไม่พบ NAV ให้รายงานข้อผิดพลาดตามจริงและไม่แสดงรายงานสำเร็จแทน

## ⚠️ ข้อจำกัดของโมเดล

- ค่าทางเทคนิคเป็น heuristic และขึ้นกับคุณภาพของ snapshot หรือ NAV ที่ได้รับ
- `W`, `D`, `4H` และ `1H` เป็น labels ของ workflow ไม่ใช่การยืนยันว่ามีข้อมูล NAV intraday ครบทุก timeframe
- ราคาและ signals ใน CANDIDATE ใช้ค่าจาก snapshot ล่าสุด ไม่ใช่การประเมินราคาแบบ real-time
- PTR ไม่ใช่การจัดระดับ Liquidity แบบ HIGH/MEDIUM/LOW
- ระบบไม่รับรองความสดของ benchmark, timezone, ปฏิทินตลาด, corporate actions หรือความเหมาะสมของการลงทุน
- ห้ามเผยแพร่ `.env`, SEC API key หรือ workbook ที่มีข้อมูลส่วนตัว

เอกสารอ้างอิงหลักคือ [README.md](./README.md) และ implementation จริงคือ [fund_update.sh](./fund_update.sh)
