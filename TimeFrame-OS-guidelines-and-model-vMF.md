# TFOSvMF model notes

โปรเจกต์นี้เป็น read-only CLI สำหรับข้อมูลกองทุนรวมไทย ไม่ใช่ระบบส่งคำสั่งซื้อขาย

## Data flow

1. โหลด `.env`
2. ดาวน์โหลด Google Sheets XLSX ใหม่ทุกครั้ง
3. อ่าน `AKA` และ `PROJECT ID` ด้วย `openpyxl`
4. เรียก SEC NAV API ย้อนหลังประมาณ 5 ปี
5. คำนวณ RSI และ MACD delta จาก NAV
6. เรียก SEC Factsheet statistics เพื่ออ่าน PTR
7. พิมพ์ Markdown report

Logic ทั้งหมดอยู่ใน [fund_update.sh](./fund_update.sh) ซึ่งเป็น Bash wrapper ที่ฝัง Python inline; ไม่มี source `.py` แยกและไม่มี Ruby runtime

## Timeframe labels

- `W`: bucket NAV ประมาณ 30 วัน ใช้ RSI และ MACD delta ระยะยาว
- `D`: label ของ setup
- `4H`: label ของ entry zone จากข้อมูล NAV รายวัน
- `1H`: RSI period สั้นกว่าเพื่อแสดง trigger

ชื่อ timeframe เป็น label เชิงโมเดล ไม่ได้หมายความว่า SEC มี NAV intraday

## ข้อจำกัด

ค่าทั้งหมดเป็น heuristic จาก NAV ไม่ใช่ OHLCV จริง ไม่ใช่คำแนะนำการลงทุน และไม่ควรใช้แทนข้อมูลทางการจาก บลจ. หรือ SEC
