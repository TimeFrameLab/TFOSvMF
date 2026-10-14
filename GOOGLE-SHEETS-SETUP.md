# ตั้งค่า Google Sheets สำหรับ TFOSvMF

## การตั้งค่า

กำหนดในไฟล์ `.env` ซึ่งไม่ควร commit:

```dotenv
SET_DATA_URL=https://docs.google.com/spreadsheets/d/<SHEET_ID>/edit
SET_DATA_SHEET=All-ThaiMutualFunds-MTFS
SEC_API_KEY_FUND=<SEC_API_KEY>
```

ชีตต้องอนุญาตให้ดาวน์โหลด XLSX ผ่านลิงก์โดยไม่ลงชื่อเข้าใช้ หากมีข้อมูลพอร์ตหรือข้อมูลส่วนตัว ให้ใช้สำเนาที่ผ่านการลบข้อมูลดังกล่าวก่อนเปิดสิทธิ์

## รูปแบบชีต

- ชื่อแท็บเริ่มต้น: `All-ThaiMutualFunds-MTFS` (เปลี่ยนได้ด้วย `SET_DATA_SHEET`)
- วางหัวตารางภายใน 10 แถวแรก โดยต้องมีคอลัมน์ `AKA` และ `PROJECT ID`
- `AKA` คือชื่อย่อกองทุน เช่น `1AM-DAILY`, `ASP-DAPP 3M5`, `ASP-SC(UH)-UI` หรือ `B1/26`; รองรับรูปแบบ `AKA (FUND)` ด้วย
- `PROJECT ID` คือ SEC project ID; เพิ่ม class hint ได้เป็น `project_id|class_hint`
- แถวที่ไม่มี AKA จะถูกข้าม
- หากไม่มี project ID CLI จะค้นชื่อย่อจาก SEC profiles โดยอัตโนมัติ; ชื่อที่ไม่ชัดเจนหรือมีหลาย share class ต้องระบุ project ID และ class hint อย่างชัดเจน

## คำสั่ง

```bash
./update.sh
./update.sh UPDATE/1AM-DAILY,KF-GOLD
./update.sh "UPDATE/ASP-DAPP 3M5"
./candidate.sh
```

ใช้ comma คั่นหลาย AKA เพราะขีดกลางเป็นส่วนหนึ่งของชื่อกองทุนได้; ถ้า AKA มีช่องว่างให้ครอบ argument ด้วย quotes ตามตัวอย่าง ทุกคำสั่งดาวน์โหลด XLSX snapshot ล่าสุดโดยไม่ใช้ HTTP cache และบันทึกสำเนาไว้ที่ `downloads/All-ThaiMutualFunds-MTFS.xlsx`; ถ้าดาวน์โหลด XLSX ไม่สำเร็จจะแสดง error และไม่ใช้ไฟล์เก่าทดแทน หาก SEC API ใช้งานไม่ได้ ระบบจะรายงานข้อผิดพลาดของกองทุนนั้นและไม่ใช้ NAV เก่าทดแทน

`UPDATE` แสดงตารางสรุป `AKA`, `PROJECT ID`, `RSI(W)`, `RSI(D)`, `MACD Δ(W)`, NAV, BIAS/SETUP/ENTRY/ACTION และ `PTR (latest Factsheet)`; `UPDATE/<AKA>,...` เพิ่ม metadata รายกอง ได้แก่ AKA, วันที่ NAV ล่าสุด (`LAST_CANDLE`), เวลาสร้างรายงานตามเวลาไทย (`UPDATED`) และ PROJECT ID ก่อนตาราง `SPECIFIED FUND` ซึ่งแสดง RSI(W) และ RSI(1H) ส่วน `CANDIDATE` คงสองกลุ่มเดิมและเรียง MACD Δ(W) จากมากไปน้อยในแต่ละกลุ่ม ทั้งสามรูปแบบฝังลิงก์ Finnomena ใน AKA และไม่มีคอลัมน์ `FINNOMENA` แยก เป็นผลจาก heuristic ไม่ใช่คำแนะนำการลงทุน

## SEC Open API

- ใช้ `SEC_API_KEY_FUND` จาก `.env` ใน header `Ocp-Apim-Subscription-Key`
- ดึง NAV ย้อนหลังประมาณ 5 ปี พร้อมรองรับ pagination; จำกัดจำนวนหน้าเพื่อป้องกันการวนไม่สิ้นสุด
- ดึง fund profiles เมื่อแถวไม่มี `PROJECT ID` เพื่อจับคู่ชื่อย่อ โดยจะแจ้งข้อผิดพลาดหากชื่อกำกวมหรือไม่พบ
- ดึง Portfolio Turnover Ratio จาก `GET /v2/fund/factsheet/statistics` โดยใช้ `proj_id`, `fund_class_name` ที่เลือกจาก NAV และ `latest=true`; ใน CANDIDATE จะเรียกหลังคัดกลุ่มแล้วเท่านั้น
- หาก API ตอบ HTTP error, JSON ผิดรูปแบบ หรือไม่มีข้อมูล จะรายงาน error ตามจริง
- SEC API key ไม่ถูกแสดงใน output และไม่ถูกเก็บใน Git

PTR แสดงในคอลัมน์เดียวพร้อมวันที่เริ่มมีผลของ Factsheet (เมื่อ SEC ส่งค่า); หากไม่มี PTR จะแสดง `N/A` ส่วนความผิดพลาดในการเรียก endpoint จะแสดงเป็น error และทำให้คำสั่งคืนสถานะไม่สำเร็จ PTR เป็นสถิติที่ บลจ. รายงานใน Factsheet ไม่ใช่มูลค่าซื้อขายรายวันหรือ bid/ask liquidity

SEC ใช้สำหรับข้อมูล NAV/history, fund profiles และ Factsheet statistics แบบ read-only; ไม่ได้ใช้หรือสมมติข้อมูล bid/ask หรือ order book แบบตลาดหุ้น CLI ไม่แก้ไข Google Sheet และไม่ส่งคำสั่งซื้อขาย
