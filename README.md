# TimeFrame OS vMF — Thai Mutual Fund

CLI แบบ read-only สำหรับอ่านรายชื่อกองทุนจาก Google Sheets, ดึง NAV ย้อนหลังจาก SEC Open API แล้วแสดงสรุป Multi-Timeframe ใน Terminal โดยไม่เขียนกลับชีตและไม่ส่งคำสั่งซื้อขาย

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

## คำสั่ง

```bash
./update.sh
./update.sh UPDATE/1AM-DAILY,KF-GOLD
./candidate.sh
```

ใช้ comma คั่น AKA หลายรายการ เนื่องจาก AKA ของกองทุนอาจมีเครื่องหมายขีดกลางอยู่แล้ว `UPDATE` ประมวลผลทุกกองทุน ส่วน `CANDIDATE` แสดงกองที่ผ่าน W→D และอยู่ในโซน 4H ตามตัวอย่าง Apps Script

CLI อ่าน XLSX snapshot ในหน่วยความจำ ไม่เก็บไฟล์ snapshot, ไม่แก้ไขชีต และไม่ใช้ข้อมูลเก่าหากดาวน์โหลดหรือเรียก SEC ไม่สำเร็จ กองทุนที่ไม่มี `PROJECT ID` จะค้นหาใน SEC profiles; หากการจับคู่ชื่อกำกวมหรือกองทุนมีหลาย class ให้ระบุ project ID หรือ class hint ในชีต

## Output Contract / ข้อกำหนดบังคับเรื่องการแสดงผล

- ใช้เฉพาะรูปแบบคำสั่งที่กำหนดไว้ในหัวข้อ [คำสั่ง](#คำสั่ง): `./update.sh`, `./update.sh UPDATE/<AKA>,<AKA>,...` หรือ `./candidate.sh` ห้ามเปลี่ยนรูปแบบหรืออ้างว่าได้รันคำสั่งอื่น
- รายงานต้องเริ่มด้วยบล็อกสรุปของ AKA `B-INNOTECH` ตามรูปแบบนี้ โดยค่าทุกช่องต้องมาจาก snapshot ล่าสุด:

  ```text
  AKA         : B-INNOTECH 🔔
  LAST_CANDLE : <ค่าจาก LAST_CANDLE>
  UPDATED     : <ค่าจาก UPDATED>
  GROUP       : <ค่าจาก GROUP>
  ```

- หากไม่พบ `B-INNOTECH` หรือไม่มีคอลัมน์/ค่า `LAST_CANDLE`, `UPDATED` หรือ `GROUP` ให้รายงานข้อผิดพลาดและหยุด ห้ามคาดเดาค่า เติมค่าแทน หรือแสดงรายงานเสมือนสำเร็จ
- ต้องคงลำดับกลุ่มและลำดับหัวตารางตามที่กำหนด ห้ามสลับ ละ หรือตั้งชื่อใหม่เอง:
  - CANDIDATE: `🟢 พร้อมครบ W→D→4H — รอ ENTRY_TRIGGER(1H)` ก่อน `🟡 W→D ผ่านแล้ว แต่ 4H ยังไม่ยืนยันโซน`
  - UPDATE: `AKA | NAV | NAV DATE | BIAS(W) | SETUP(D) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | ACTION | W | D | 4H | 1H | FINNOMENA`
  - ตาราง CANDIDATE: `AKA | BIAS(W) | SETUP(D) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | NAV | FINNOMENA`
- ลิงก์กองทุนต้องใช้ `https://www.finnomena.com/fund/<AKA>/graph`
- ห้ามสรุปว่าดาวน์โหลด ตรวจสอบ หรือประมวลผลสำเร็จ หากไม่มีผลลัพธ์ยืนยันจริง; เมื่อเกิดข้อผิดพลาดให้รายงานตามจริง
- ใช้ข้อมูลจาก snapshot ที่เพิ่งดาวน์โหลดในรอบคำสั่งนั้นเท่านั้น หากดาวน์โหลดไม่สำเร็จให้หยุดและแจ้งข้อผิดพลาด ห้ามใช้ cache หรือ snapshot เก่าแทน

## วิธีคำนวณและข้อจำกัด

- ใช้ NAV ย้อนหลังประมาณ 5 ปี; W ใช้ bucket ประมาณ 30 วัน, D ใช้ bucket 7 วัน, 4H และ 1H ใช้ NAV รายวันแต่ใช้ indicator periods ต่างกันตามตัวอย่าง
- เนื่องจากกองทุนไม่มีข้อมูล OHLCV รายวันใน endpoint นี้ โปรแกรมใช้ NAV เป็น close/high/low และใช้การเปลี่ยนแปลงของจำนวนหน่วย (`net_asset / NAV`) เป็น proxy สำหรับ `SIGNAL_VOLUME` ไม่ใช่ปริมาณซื้อขายจริง
- ไม่ใช้ benchmark สำหรับ Relative Strength โดยปริยาย เพราะ SET Index ไม่เหมาะกับกองทุนทุกประเภท (เช่น ตราสารหนี้และกองทุนต่างประเทศ)
- `CANDIDATE`, BUY/WAIT/EXIT เป็นผลจาก heuristic ของตัวอย่าง ไม่ใช่คำแนะนำการลงทุนหรือคำสั่งซื้อขาย; ตรวจสอบ share class, ค่าธรรมเนียม และข้อมูล NAV กับผู้ให้บริการก่อนตัดสินใจ
- ลิงก์กองทุนใช้ `https://www.finnomena.com/fund/<AKA>/graph`

ดู [แนวทางและแบบจำลอง vMF](./TimeFrame-OS-guidelines-and-model-vMF.md) สำหรับความหมายของสัญญาณและข้อควรระวัง
