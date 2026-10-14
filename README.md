# TimeFrame OS vMF — Thai Mutual Fund

เครื่องมือแบบ read-only สำหรับทำงานกับข้อมูลกองทุนรวมไทยจาก Google Sheets และ SEC Open API:

- ดาวน์โหลด snapshot XLSX จาก Reference Sheet ที่กำหนดไว้
- ตรวจสอบโครงสร้างและข้อมูลกองทุนพื้นฐาน (`AKA`, `PROJECT ID`)
- ดึง NAV ย้อนหลังจาก SEC แล้วคำนวณสัญญาณ Multi-Timeframe สำหรับรายงาน `UPDATE` และ `CANDIDATE`
- แสดงรายงานใน Terminal เป็น Markdown พร้อมลิงก์ Finnomena
- เก็บ snapshot ที่ดาวน์โหลดไว้ใน `downloads/` เพื่อให้ตรวจสอบข้อมูลชุดที่ใช้ได้

> **สถานะ: อยู่ระหว่างพัฒนา — ห้ามใช้วิเคราะห์หรือตัดสินใจลงทุนในกองทุนจริง**
>
> ระบบยังไม่คำนวณ MPTM จาก OHLCV หรือสร้างรายงาน Excel; ข้อมูลจาก SEC ใช้สำหรับ NAV, fund profiles และสถิติที่รายงานใน Fund Factsheet แบบ read-only ไม่มีข้อมูล bid/ask หรือ order book และไม่มีการส่งคำสั่งซื้อขาย

## เริ่มต้นใช้งาน

1. ติดตั้ง Python 3.9+ และ dependencies:

   ```bash
   python3 -m pip install -r requirements.txt
   ```

2. คัดลอก `.env.example` เป็น `.env` แล้วกำหนด:

   ```dotenv
   SET_DATA_URL=https://docs.google.com/spreadsheets/d/<SHEET_ID>/edit
   SET_DATA_SHEET=All-ThaiMutualFunds-MTFS
   SEC_API_KEY_FUND=<SEC_API_KEY>
   ```

   เก็บ `.env` ไว้ในเครื่องเท่านั้น ห้ามใส่ API key ใน source code, Git หรือรายงาน

3. เตรียมชีตตาม [คู่มือตั้งค่าข้อมูล](./GOOGLE-SHEETS-SETUP.md)

ไฟล์ [FUND-Summary.gs](./examples/FUND-Summary.gs) เป็นตัวอย่าง Apps Script แบบเลือกใช้เอง เพื่อสร้างแท็บสรุป AKA, PROJECT ID และลิงก์ Finnomena โดยไม่แก้แท็บต้นทาง; CLI ด้านล่างยังคงไม่เขียนกลับ Google Sheets

## คำสั่ง

```bash
./update.sh
./update.sh UPDATE/1AM-DAILY,KF-GOLD
./update.sh "UPDATE/ASP-DAPP 3M5"
./candidate.sh
```

ใช้ comma คั่น AKA หลายรายการ เนื่องจาก AKA ของกองทุนอาจมีเครื่องหมายขีดกลางอยู่แล้ว; AKA ที่มีช่องว่างภายในให้ครอบคำสั่งด้วย quotes ตามตัวอย่าง `UPDATE` ประมวลผลทุกกองทุน ส่วน `CANDIDATE` แสดงกองทุนตามเกณฑ์ heuristic W→D และโซน 4H ในแบบจำลอง

ทุกครั้งที่รันคำสั่ง ระบบจะร้องขอ XLSX ใหม่จาก Google Sheets โดยป้องกัน HTTP cache และบันทึก snapshot ล่าสุดที่ `downloads/All-ThaiMutualFunds-MTFS.xlsx` ก่อนตรวจสอบและประมวลผล หากดาวน์โหลดไม่สำเร็จจะไม่ใช้ snapshot เก่าแทน ระบบไม่เขียนกลับชีตและไม่ใช้ผลลัพธ์จาก SEC ที่บันทึกค้างไว้ กองทุนที่ไม่มี `PROJECT ID` จะค้นหาใน SEC profiles; หากการจับคู่ชื่อกำกวมหรือกองทุนมีหลาย class ให้ระบุ project ID หรือ class hint ในชีต หลังคัดกองทุนตามคำสั่ง/เกณฑ์ Candidate แล้วจึงเรียก SEC Fund Factsheet statistics เฉพาะกองทุนที่จะอยู่ในรายงาน เพื่ออ่าน PTR ล่าสุด

## Output Contract / มาตรฐานการนำเสนอร่วมกัน

มาตรฐานนี้ใช้ร่วมกันกับ `UPDATE`, `UPDATE/<AKA>-...` และ `CANDIDATE` โดยกำหนดคุณภาพและความถูกต้องของการนำเสนอ ไม่ได้กำหนดให้ทุกคำสั่งใช้หัวข้อหรือตารางแบบเดียวกัน:

| หลักการ | ข้อกำหนด |
|---|---|
| Markdown ที่ render ได้จริง | เนื้อหารายงานต้องเป็น Markdown ที่ถูกต้อง โดยเฉพาะตารางต้องมีแถวหัวตารางและ separator ตามรูปแบบ Markdown; แสดงรายงานโดยตรง ไม่ครอบรายงานจริงด้วย code fence |
| แสดงผลครบ | แสดงหัวข้อ กลุ่ม metadata คอลัมน์ แถวข้อมูล และคำเตือนที่คำสั่งนั้นกำหนดให้ครบ ไม่ตัดทอน แบ่งละส่วน หรือซ่อนรายการ |
| ไม่ย่อหรือแต่งข้อมูล | แสดงค่าและข้อความตามข้อมูลที่ได้มา/คำนวณได้ ไม่ย่อความ เปลี่ยนความหมาย เติมข้อมูลที่ไม่มี หรือทำให้ค่าดูดีกว่าความจริง; ใช้รูปแบบตัวเลขหรือตัวแทนเมื่อไม่มีค่าเฉพาะที่ระบุไว้ในเอกสารนี้เท่านั้น |
| คำเตือนตามจริง | แสดงเฉพาะคำเตือนหรือข้อผิดพลาดที่เกิดขึ้นจริงและเกี่ยวข้องกับรอบประมวลผลนั้น ห้ามแต่งคำเตือน ละคำเตือนที่เกิดขึ้น หรืออ้างว่าทำงานสำเร็จเมื่อยังไม่มีผลยืนยัน |
| รูปแบบเฉพาะคำสั่ง | แต่ละคำสั่งคงหัวข้อ ลำดับกลุ่ม metadata และ schema ตารางของตนเองตามข้อกำหนดด้านล่าง ไม่บังคับให้ใช้หัวข้อหรือตารางเหมือนกันทุกคำสั่ง |

- ใช้เฉพาะรูปแบบคำสั่งที่กำหนดไว้ในหัวข้อ [คำสั่ง](#คำสั่ง): `./update.sh`, `./update.sh UPDATE/<AKA>,<AKA>,...` หรือ `./candidate.sh` ห้ามเปลี่ยนรูปแบบหรืออ้างว่าได้รันคำสั่งอื่น
- ชีตอินพุตต้องมีคอลัมน์ `AKA` และ `PROJECT ID`; โปรแกรมดึง NAV จาก SEC และคำนวณตัวชี้วัด/สัญญาณเอง ไม่ได้อ่าน PRICE, RSI, TREND, MACD หรือ ACTION ที่คำนวณไว้ในชีต
- คงลำดับกลุ่มและลำดับหัวตารางของแต่ละคำสั่งตามที่กำหนด ห้ามสลับ ละ หรือตั้งชื่อใหม่เอง:
  - CANDIDATE: `🟢 พร้อมครบ W→D→4H — รอ ENTRY_TRIGGER(1H)` ก่อน `🟡 W→D ผ่านแล้ว แต่ 4H ยังไม่ยืนยันโซน`
  - `UPDATE/<AKA>,<AKA>,...`: แสดง metadata `AKA`, `LAST_CANDLE`, `UPDATED`, `PROJECT ID` แยกรายกอง แล้วแสดงหัวข้อ `🔵 SPECIFIED FUND — <จำนวน> รายการ`
  - ตาราง UPDATE รวม: `AKA | PROJECT ID | RSI(W) | RSI(D) | MACD Δ(W) | NAV | BIAS(W) | SETUP(D) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | ACTION | PTR (latest Factsheet)`
  - ตาราง SPECIFIED FUND: `AKA | PROJECT ID | RSI(W) | RSI(1H) | MACD Δ(W) | NAV | BIAS(W) | SETUP(D) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | ACTION | PTR (latest Factsheet)`
  - ตาราง CANDIDATE: `# | AKA | PROJECT ID | NAV | MACD Δ(W) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | PTR (latest Factsheet)`; เรียง MACD Δ(W) มากไปน้อยภายในแต่ละกลุ่ม โดยไม่เปลี่ยนเกณฑ์หรือกลุ่มเดิม
- `LAST_CANDLE` ของกองทุนระบุวันที่ NAV ล่าสุดเท่านั้น เนื่องจาก SEC ให้ NAV รายวัน ไม่แสดงเวลาแท่ง intraday ที่ไม่มีในข้อมูล; `UPDATED` คือเวลาสร้างรายงานตามเวลาไทย (Asia/Bangkok)
- ลิงก์กองทุนต้องใช้ `https://www.finnomena.com/fund/<AKA>/graph`
- แสดง AKA เป็น Markdown link ไปยัง Finnomena ภายในคอลัมน์ AKA; ห้ามเพิ่มคอลัมน์ `FINNOMENA` แยกในรายงาน UPDATE, UPDATE/<AKA> หรือ CANDIDATE
- `PTR (latest Factsheet)` คือค่า `portfolio_turnover_ratio` จาก SEC Factsheet statistics พร้อมวันที่เริ่มมีผลของ Factsheet เมื่อมี; ไม่ใช่ turnover รายวันหรือ bid/ask liquidity หากไม่มีค่าจะแสดง `N/A` และหาก SEC เรียกไม่สำเร็จจะแจ้งข้อผิดพลาดและคืนสถานะไม่สำเร็จ
- `CANDIDATE` ต้องคัดเลือกกลุ่มตามเกณฑ์ก่อน แล้วจึงเรียก PTR เฉพาะกองทุนที่แสดงในกลุ่ม Candidate; `UPDATE` เรียก PTR สำหรับกองทุนที่ผ่าน NAV processing ทั้งหมด หรือเฉพาะ AKA ที่ระบุใน `UPDATE/<AKA>,...`
- ห้ามสรุปว่าดาวน์โหลด ตรวจสอบ หรือประมวลผลสำเร็จ หากไม่มีผลลัพธ์ยืนยันจริง; เมื่อเกิดข้อผิดพลาดให้รายงานตามจริง
- ใช้ข้อมูลจาก snapshot ที่เพิ่งดาวน์โหลดในรอบคำสั่งนั้นเท่านั้น หากดาวน์โหลดไม่สำเร็จให้หยุดและแจ้งข้อผิดพลาด ห้ามใช้ cache หรือ snapshot เก่าแทน แม้ไฟล์เก่าจะยังอยู่ใน `downloads/`

## 🧩 แนวทางการแสดงผลแบบ TFOSvMF สำหรับกองทุนไทย

ตัวอย่างด้านล่างแสดงรูปแบบรายงานที่ CLI ใช้จริง โดยค่าที่อยู่ในวงเล็บเหลี่ยมเป็น placeholder ไม่ใช่ผลการดึงข้อมูลจริง ใช้ลิงก์ Finnomena ในคอลัมน์ AKA และไม่เพิ่มคอลัมน์ `FINNOMENA` แยก; ไม่ใช้คอลัมน์ `VOL`, `TREND`, `CMB` แบบรายงานหุ้น เพราะ vMF ไม่ได้คำนวณคะแนนเหล่านั้น

### `UPDATE/<AKA>,<AKA>,...` — กองทุนที่ระบุ

แสดง metadata ของแต่ละกองทุนก่อนตารางสรุป:

```text
AKA         : FUND-A
LAST_CANDLE : [วัน/เดือน/ปี] (NAV รายวัน)
UPDATED     : [วัน/เดือน/ปี ชั่วโมง:นาที]
PROJECT ID  : [PROJECT ID]

AKA         : FUND-B
LAST_CANDLE : [วัน/เดือน/ปี] (NAV รายวัน)
UPDATED     : [วัน/เดือน/ปี ชั่วโมง:นาที]
PROJECT ID  : [PROJECT ID]

🔵 SPECIFIED FUND — 2 รายการ
```

จากนั้นแสดงตารางตามลำดับคอลัมน์นี้:

| AKA | PROJECT ID | RSI(W) | RSI(1H) | MACD Δ(W) | NAV | BIAS(W) | SETUP(D) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | ACTION | PTR (latest Factsheet) |
|---|---|---:|---:|---:|---:|---|---|---|---|---|---|
| [FUND-A](https://www.finnomena.com/fund/FUND-A/graph) | [PROJECT ID] | [ค่า] | [ค่า] | [ค่า] | [ค่า NAV] | [ค่า] | [ค่า] | [ค่า] | [ค่า] | [ค่า] | [ค่า PTR หรือ N/A] |
| [FUND-B](https://www.finnomena.com/fund/FUND-B/graph) | [PROJECT ID] | [ค่า] | [ค่า] | [ค่า] | [ค่า NAV] | [ค่า] | [ค่า] | [ค่า] | [ค่า] | [ค่า] | [ค่า PTR หรือ N/A] |

`LAST_CANDLE` ระบุวันที่ NAV ล่าสุดเท่านั้น ไม่ระบุเวลา `UPDATED` เป็นเวลาที่สร้างรายงานตามเวลาไทย

### `UPDATE` — สรุปกองทุนทั้งหมด

```text
สรุปข้อมูลกองทุน — [จำนวน] กองทุน
```

| AKA | PROJECT ID | RSI(W) | RSI(D) | MACD Δ(W) | NAV | BIAS(W) | SETUP(D) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | ACTION | PTR (latest Factsheet) |
|---|---|---:|---:|---:|---:|---:|---:|---|---|---|---|
| [FUND-A](https://www.finnomena.com/fund/FUND-A/graph) | [PROJECT ID] | [ค่า] | [ค่า] | [ค่า] | [ค่า NAV] | [ค่า] | [ค่า] | [ค่า] | [ค่า] | [ค่า] | [ค่า PTR หรือ N/A] |

### `CANDIDATE` — กองทุนที่ผ่านเกณฑ์

คงลำดับสองกลุ่มเดิมของ vMF; เรียง MACD Δ(W) มากไปน้อยภายในแต่ละกลุ่ม และแสดง `—` เมื่อไม่มีกองทุนในกลุ่ม

```text
🟢 พร้อมครบ W→D→4H — รอ ENTRY_TRIGGER(1H) — [จำนวน] กองทุน
```

| # | AKA | PROJECT ID | NAV | MACD Δ(W) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | PTR (latest Factsheet) |
|---:|---|---|---:|---:|---|---|---|
| 1 | [FUND-A](https://www.finnomena.com/fund/FUND-A/graph) | [PROJECT ID] | [ค่า NAV] | [ค่า] | [ค่า] | [ค่า] | [ค่า PTR หรือ N/A] |

```text
🟡 W→D ผ่านแล้ว แต่ 4H ยังไม่ยืนยันโซน — [จำนวน] กองทุน
```

ใช้หัวตารางเดียวกันกับกลุ่มสีเขียวด้านบน; แต่ละกลุ่มจัดอันดับแยกจากกัน

## วิธีคำนวณและข้อจำกัด

- ใช้ NAV ย้อนหลังประมาณ 5 ปี; W ใช้ bucket ประมาณ 30 วัน, D ใช้ bucket 7 วัน, 4H และ 1H ใช้ NAV รายวันแต่ใช้ indicator periods ต่างกันตามตัวอย่าง
- เนื่องจาก SEC NAV endpoint ไม่มีข้อมูล OHLCV รายวัน โปรแกรมใช้ NAV เป็น close/high/low และใช้การเปลี่ยนแปลงของจำนวนหน่วย (`net_asset / NAV`) เป็น proxy สำหรับ `SIGNAL_VOLUME` ไม่ใช่ปริมาณซื้อขายจริง
- PTR มาจาก Factsheet statistics ของ SEC (`/v2/fund/factsheet/statistics`) และเป็นอัตราหมุนเวียนการลงทุนในพอร์ตที่ บลจ. รายงานในแต่ละงวด Factsheet; ไม่ใช่มูลค่าซื้อขายย้อนหลังรายวัน ค่าจาก Factsheet ล่าสุดอาจไม่ตรงกับวัน NAV ล่าสุด
- ไม่ใช้ benchmark สำหรับ Relative Strength โดยปริยาย เพราะ SET Index ไม่เหมาะกับกองทุนทุกประเภท (เช่น ตราสารหนี้และกองทุนต่างประเทศ)
- `CANDIDATE`, BUY/WAIT/EXIT เป็นผลจาก heuristic ของตัวอย่าง ไม่ใช่คำแนะนำการลงทุนหรือคำสั่งซื้อขาย; ตรวจสอบ share class, ค่าธรรมเนียม และข้อมูล NAV กับผู้ให้บริการก่อนตัดสินใจ
- ลิงก์กองทุนใช้ `https://www.finnomena.com/fund/<AKA>/graph`

ดู [แนวทางและแบบจำลอง vMF](./TimeFrame-OS-guidelines-and-model-vMF.md) สำหรับความหมายของสัญญาณและข้อควรระวัง
