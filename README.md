# TimeFrame OS vMF (Thai Mutual Fund)

## 📋 ภาพรวม

TimeFrame OS (vMF) เป็นเครื่องมือสำหรับทำงานกับข้อมูลกองทุนรวมไทยจาก Google Sheets และ SEC Open API:

- ดาวน์โหลด snapshot XLSX จาก Reference Sheet ที่กำหนดไว้
- ตรวจสอบโครงสร้างและข้อมูลพื้นฐานของ snapshot
- ค้นหาและประมวลผลกองทุนตามคำสั่ง `UPDATE` หรือ `UPDATE/<AKA>`
- ดึง NAV และข้อมูล PTR จาก SEC Open API แบบ read-only
- คำนวณ signals พื้นฐานและแสดงรายงานใน Terminal พร้อมลิงก์ Finnomena
- เก็บ snapshot ที่ดาวน์โหลดไว้ใน `downloads/` เพื่อให้ตรวจสอบข้อมูลชุดที่ใช้ได้

> **สถานะ: อยู่ระหว่างพัฒนา — ห้ามใช้วิเคราะห์หรือตัดสินใจลงทุนจริง**
>
> ระบบยังเป็น workflow แบบ read-only ไม่เขียนกลับ Google Sheets และไม่ส่งคำสั่งซื้อขาย

## 🔔 การเริ่มต้นใช้งาน

```bash
git clone https://github.com/TimeFrameLab/TFOSvMF.git
cd TFOSvMF
python3 -m venv .venv
.venv/bin/python -m pip install openpyxl requests
```

กำหนด URL ของ Google Sheets ชื่อแท็บ และ SEC API key ใน `.env`:

```dotenv
SET_DATA_URL=https://docs.google.com/spreadsheets/d/<SHEET_ID>/edit
SET_DATA_SHEET=All-ThaiMutualFunds-MTFS
SEC_API_KEY_FUND=<SEC_API_KEY>
```

ทุกครั้งที่รัน `UPDATE`, `UPDATE/<AKA>` หรือ `CANDIDATE` ระบบจะร้องขอ XLSX ใหม่จาก Google Sheets แล้วตรวจและบันทึก snapshot ที่ `downloads/All-ThaiMutualFunds-MTFS.xlsx`; หากดาวน์โหลดไม่สำเร็จจะไม่ใช้ snapshot เก่าแทน

URL ต้องอ่านได้โดยไม่ลงชื่อเข้าใช้ และ workbook ต้องมีคอลัมน์ `AKA` กับ `PROJECT ID` ภายใน 10 แถวแรก โดยกองทุนที่ต้องการประมวลผลต้องมี SEC project ID

## 🧭 คำสั่งหลัก

| คำสั่ง | วิธีใช้ | ผลลัพธ์ |
|---|---|---|
| `START @README.md` | พิมพ์ในแชต | อ่าน README และทบทวน guideline ก่อนรอคำสั่ง |
| `UPDATE` | `./update.sh` | ดาวน์โหลด snapshot ตรวจข้อมูล และแสดงรายงานกองทุน |
| `UPDATE/<AKA>` | `./update.sh UPDATE/B-INNOTECH` | แสดงรายงานเฉพาะกองทุนที่ระบุ |
| `CANDIDATE` | `./candidate.sh` | จุดเริ่มต้นสำหรับการพัฒนา Candidate ในอนาคต |
| `REVIEW` | พิมพ์ในแชต | ทบทวน guideline อีกครั้ง |

## 📌 ข้อมูลสำคัญ

หลังได้รับคำสั่ง `START @README.md` ให้ยึดรูปแบบคำสั่งในเอกสารนี้อย่างเคร่งครัด: `UPDATE` ใช้ `./update.sh`, `UPDATE/<AKA>` ใช้ `./update.sh UPDATE/<AKA>` และ `CANDIDATE` ใช้ `./candidate.sh` ห้ามเปลี่ยนรูปแบบคำสั่งหรือแทนที่ด้วยวิธีอื่นโดยพลการ

รายงานต้องใช้ข้อมูลจาก snapshot ที่เพิ่งดาวน์โหลดจริงเท่านั้น ห้ามคาดเดาผลลัพธ์ ห้ามใช้ snapshot เก่าแทน และเมื่อเกิดข้อผิดพลาดต้องรายงานข้อผิดพลาดตามจริง

### ✅ มาตรฐานการแสดงผลสำหรับทุกคำสั่ง

ทุกครั้งที่เรียก `UPDATE`, `UPDATE/<AKA>` หรือ `CANDIDATE` ให้ใช้มาตรฐานการนำเสนอเดียวกัน แต่คงหัวข้อและคอลัมน์เฉพาะของแต่ละคำสั่งไว้

| ลำดับ | ส่วนรายงาน | มาตรฐานร่วม |
|---|---|---|
| 1 | หัวข้อและข้อมูลสรุป | แสดงเฉพาะ metadata ที่คำสั่งนั้นกำหนด และใช้ค่าจาก snapshot ล่าสุด |
| 2 | ผลลัพธ์ | แสดงหัวข้อ จำนวน และ Markdown table ตาม schema ของคำสั่งนั้น |
| 3 | ชื่อกองทุน | ใช้ Markdown link Finnomena ตามรูปแบบ `https://www.finnomena.com/fund/<AKA>/graph` |
| 4 | หมายเหตุและคำเตือน | แสดงท้ายรายงานตามข้อมูลจริง |

เมื่อนำผลคำสั่งมาแสดงในแชต ต้องแสดงเป็น Markdown ที่ render ได้จริง ไม่ครอบรายงานด้วย code fence ไม่ตัดแถวหรือคอลัมน์ และไม่เติมค่าที่ไม่มีใน output หากการรันผิดพลาดให้แสดงข้อผิดพลาดแทนรายงานสำเร็จ

## 🧩 แนวทางการแสดงผลแบบ TFOSvX สำหรับกองทุนรวมไทย

แนวทางนี้สืบทอดรูปแบบการแสดงผลของระบบ TimeFrame OS และปรับให้ใช้กับ NAV ของกองทุนรวมไทย โดยมุ่งให้ทุกครั้งที่แสดงผลมีรูปแบบเดียวกัน และไม่อนุมานผลใด ๆ หากไม่มีข้อมูลยืนยันจริง

| ส่วนของผลลัพธ์ | รูปแบบบังคับ | ตัวอย่าง/สาระสำคัญ |
|---|---|---|
| ส่วนสรุปรวม | `AKA / LAST_CANDLE / UPDATED / PROJECT ID` | ใช้ metadata จากข้อมูลที่ดาวน์โหลดและ SEC API ล่าสุด |
| ตารางรายงาน | Markdown table | ใช้หัวคอลัมน์ตามที่กำหนดแน่นอน |
| กองทุนทุกแถว | Markdown link Finnomena | ใช้ `https://www.finnomena.com/fund/<AKA>/graph` |
| Warning | ข้อความเตือนตามจริง | ระบุเมื่อดาวน์โหลดหรือดึงข้อมูล SEC ไม่สำเร็จ |

### 1) รูปแบบ `UPDATE`

```text
สรุปข้อมูลกองทุน — <จำนวน> กองทุน
| AKA | PROJECT ID | RSI(W) | RSI(D) | MACD Δ(W) | NAV | BIAS(W) | SETUP(D) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | ACTION | PTR (latest Factsheet) |
|---|---|---:|---:|---:|---:|---|---|---|---|---|---|
```

### 2) รูปแบบ `UPDATE/<AKA>`

```text
AKA         : <AKA>
LAST_CANDLE : <วันที่ NAV ล่าสุด> (NAV รายวัน)
UPDATED     : <เวลาประเทศไทย>
PROJECT ID  : <PROJECT ID>

🔵 SPECIFIED FUND — <จำนวน> รายการ
| AKA | PROJECT ID | RSI(W) | RSI(1H) | MACD Δ(W) | NAV | BIAS(W) | SETUP(D) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | ACTION | PTR (latest Factsheet) |
|---|---|---:|---:|---:|---:|---|---|---|---|---|---|
```

### 3) รูปแบบ `CANDIDATE`

ส่วนนี้ยังไม่มีเนื้อหาการคัด Candidate ที่ทำงานจริงในรุ่นปัจจุบัน

## ✅ ข้อกำหนดบังคับเรื่องการแสดงผล (Output Contract)

ก่อนแสดงผลทุกครั้ง ต้องยึดโครงสร้างร่วมและ schema เฉพาะคำสั่งให้ครบถ้วน:

- ใช้คำสั่งและรูปแบบสั่งงานตามที่ระบุในเอกสารนี้เท่านั้น
- `UPDATE` ใช้ schema รายงานกองทุนรวมไทยตามที่กำหนด
- `UPDATE/<AKA>` ต้องแสดง metadata ของกองทุนที่ร้องขอตามลำดับ ก่อนแสดงตาราง
- `CANDIDATE` ใช้ schema Candidate เท่านั้น เมื่อมีการพัฒนาการทำงานส่วนนี้
- รายงานที่แสดงในแชตต้องเป็น Markdown ที่ render ได้จริง โดยคงข้อมูลทุกแถว คอลัมน์ และคำเตือนตามผลคำสั่ง
- เมื่อไม่ได้รับข้อมูล credentials หรือดาวน์โหลดล้มเหลว ให้รายงานตามข้อเท็จจริงเท่านั้น ไม่อ้างว่าทำงานสำเร็จหรือใช้ข้อมูลเก่าแทน
- การรายงานต้องยึด snapshot ล่าสุดที่เพิ่งดาวน์โหลดได้เท่านั้น ห้ามใช้ HTTP cache หรือข้อมูลเก่ามาบิดเบือนผลลัพธ์

## 📊 รูปแบบรายงานและเกณฑ์

`UPDATE` ปกติแสดงตารางกองทุนทั้งหมดที่พบใน snapshot ตาม schema ของระบบ

`UPDATE/<AKA>` แสดง metadata ของแต่ละกองทุนตามลำดับที่ขอ แล้วแสดง `🔵 SPECIFIED FUND — n รายการ` พร้อมตาราง `AKA | PROJECT ID | RSI(W) | RSI(1H) | MACD Δ(W) | NAV | BIAS(W) | SETUP(D) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | ACTION | PTR (latest Factsheet)`

การคำนวณปัจจุบันใช้ข้อมูล NAV ย้อนหลังประมาณ 5 ปี, ใช้ bucket 30 วันเป็นชุดข้อมูล W, ใช้ RSI และ MACD delta เป็น signals พื้นฐาน และกำหนดสถานะรายงานตาม logic ใน [fund_update.sh](./fund_update.sh)

`CANDIDATE` ยังเป็น entrypoint ที่สงวนไว้สำหรับการพัฒนาต่อ และยังไม่แสดงรายการกองทุนในรุ่นนี้

## 💧 แหล่งข้อมูล PTR

PTR ใช้ค่า `portfolio_turnover_ratio` จาก SEC Factsheet ของกองทุนผ่าน SEC Open API แบบ read-only หากอ่านไม่ได้หรือไม่มีข้อมูลจะแสดง `N/A` โดยไม่ใช้ค่าจาก snapshot เก่ามาทดแทน

## 🛡️ ขอบเขตและข้อควรระวัง

- คอลัมน์หลักที่ใช้ ได้แก่ `AKA`, `PROJECT ID`, `NAV`, `RSI`, `MACD Δ(W)`, `BIAS(W)`, `SETUP(D)`, `ENTRY_ZONE(4H)` และ `ENTRY_TRIGGER(1H)` ตาม schema ของรายงาน
- ตัวตรวจเช็กรูปแบบและความครบถ้วนของข้อมูลไม่รับรองความสดของข้อมูล benchmark, timezone, ปฏิทินตลาด หรือความเหมาะสมของเกณฑ์การลงทุน
- ข้อมูลที่แสดงเป็น signals จาก NAV และข้อมูล read-only ไม่ใช่คำแนะนำการลงทุน
- ระบบไม่เขียนกลับ workbook ต้นทาง ไม่ส่งคำสั่งซื้อขาย และไม่รับประกันผลตอบแทน
- เก็บ `.env` ไว้ในเครื่องเท่านั้น และอย่าเผยแพร่ API key หรือ workbook ที่มีข้อมูลส่วนตัว

คู่มือการตั้งค่าเพิ่มเติมอยู่ที่ [GOOGLE-SHEETS-SETUP.md](./GOOGLE-SHEETS-SETUP.md) และแนวทางการทำงานอยู่ที่ [TimeFrame-OS-guidelines-and-model-vMF.md](./TimeFrame-OS-guidelines-and-model-vMF.md)
