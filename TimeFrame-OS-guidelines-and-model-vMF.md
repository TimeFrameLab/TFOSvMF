# TimeFrame OS vMF — แนวทางและแบบจำลองกองทุนรวมไทย

## ขอบเขต

TFOSvMF อ่านรายชื่อกองทุนจาก Google Sheets และ NAV ย้อนหลังจาก SEC Open API เพื่อสร้างรายงานสรุปใน Terminal เท่านั้น ไม่มีการส่งคำสั่งซื้อขายหรือเขียนข้อมูลกลับไปยังชีต

## Output Contract / ข้อกำหนดบังคับเรื่องการแสดงผล

- ใช้เฉพาะคำสั่งตามรูปแบบที่ระบุใน README: `./update.sh`, `./update.sh UPDATE/<AKA>,<AKA>,...` และ `./candidate.sh`
- รายงานทุกครั้งต้องเริ่มด้วยบล็อกสรุป AKA `B-INNOTECH` โดยใช้ค่าจาก snapshot ล่าสุดและรูปแบบที่แน่นอนดังนี้:

  ```text
  AKA         : B-INNOTECH 🔔
  LAST_CANDLE : <ค่าจาก LAST_CANDLE>
  UPDATED     : <ค่าจาก UPDATED>
  GROUP       : <ค่าจาก GROUP>
  ```

- หากไม่มี AKA `B-INNOTECH`, ไม่มีคอลัมน์ที่ต้องใช้ หรือค่า `LAST_CANDLE`, `UPDATED` หรือ `GROUP` ว่าง ให้แจ้งข้อผิดพลาดและหยุด ห้ามอนุมานหรือสร้างค่าขึ้นเอง
- คงลำดับกลุ่มและหัวตารางตาม contract ใน README: CANDIDATE แสดงกลุ่ม `🟢 พร้อมครบ W→D→4H — รอ ENTRY_TRIGGER(1H)` ก่อน `🟡 W→D ผ่านแล้ว แต่ 4H ยังไม่ยืนยันโซน`; ห้ามสลับกลุ่มหรือเปลี่ยน ละ หรือตัดหัวตารางของ UPDATE/CANDIDATE
- ใช้ลิงก์ Finnomena เท่านั้นในรูปแบบ `https://www.finnomena.com/fund/<AKA>/graph`
- ห้ามกล่าวว่าดาวน์โหลด ตรวจสอบ หรือทำงานสำเร็จ เว้นแต่มีหลักฐานจากผลการทำงานจริง
- ใช้เฉพาะ snapshot ที่เพิ่งดาวน์โหลดในรอบนั้น หากดึง snapshot ล่าสุดไม่ได้ ให้แจ้งข้อผิดพลาดและไม่ใช้ cache หรือข้อมูลเก่าแทน

## ข้อมูลที่ใช้

- `AKA`: ชื่อย่อกองทุนที่ใช้แสดงผลและสร้าง Finnomena link
- `PROJECT ID`: SEC project ID; รูปแบบ `project_id|class_hint` ใช้ระบุ share class เมื่อ endpoint คืนหลาย class
- NAV: ใช้ `last_val`/`lastVal` หรือ alias ที่ API ส่งกลับเป็นราคาปิด
- มูลค่าทรัพย์สินสุทธิ: ใช้ `net_asset`/`netAsset` เพื่อประมาณจำนวนหน่วยจาก `net_asset / NAV`

เก็บ `SEC_API_KEY_FUND` ใน `.env` เท่านั้น ห้ามบันทึกลง source, log, report หรือ Git และอย่าเผยแพร่ spreadsheet ที่มีข้อมูลส่วนตัว

## Timeframes

ตัวอย่างคำนวณ:

| TF | การสร้างแท่ง | การใช้งานใน model |
|---|---|---|
| W | bucket ประมาณ 30 วัน | BIAS ระยะยาว |
| D | bucket 7 วัน | SETUP |
| 4H | NAV รายวัน | ENTRY_ZONE |
| 1H | NAV รายวันชุดเดียวกับ 4H | ENTRY_TRIGGER ด้วย periods ที่สั้นกว่า |

ชื่อ W/D/4H/1H เป็นป้ายกำกับเชิงกลยุทธ์จาก Apps Script ไม่ใช่ข้อมูล NAV ในความถี่จริง โดยเฉพาะ 4H และ 1H ไม่ได้มีแท่ง intraday

## NAV และสัญญาณ

NAV จุดเดียวต่อวันถูกใช้เป็น close/high/low ของแท่ง สำหรับ `SIGNAL_VOLUME` ใช้ค่าสัมบูรณ์ของการเปลี่ยนแปลงจำนวนหน่วย (`net_asset / NAV`) เป็น proxy ของ fund flow ไม่ใช่ trade volume หรือเงินไหลเข้าสุทธิที่ยืนยันได้ ค่า proxy อาจเปลี่ยนจาก corporate action, การปรับข้อมูล หรือความแตกต่างของ share class

แบบจำลอง resample NAV แล้วคำนวณ trend, RSI, EMA/MACD, price structure และสรุป:

- `BIAS(W)`: ทิศทาง structure ระยะยาว
- `SETUP(D)`: READY, PULLBACK, RECOVERY, FAILED, EXTENDED หรือ WAIT
- `ENTRY_ZONE(4H)`: โครงสร้าง/การยืนยัน breakout หรือ retest
- `ENTRY_TRIGGER(1H)`: สัญญาณยืนยันระยะสั้น
- `ACTION`: เงื่อนไขรวมที่สอดคล้องกันจาก W→D→4H→1H

`CANDIDATE` แสดงกองทุนที่ BIAS เป็น BULLISH, SETUP ผ่าน และรอ trigger 1H หลัง zone 4H ยืนยัน รวมถึงกลุ่มที่ W→D ผ่านแต่ zone 4H ยังไม่ยืนยัน

## ข้อจำกัด

- Relative Strength กับ SET Index ไม่ได้ใช้เป็นค่าเริ่มต้น เพราะ benchmark ไม่เหมาะกับกองทุนทุกประเภท
- class selection อัตโนมัติทำได้เฉพาะเมื่อข้อมูลของ class แยกได้และมีผู้ชนะชัดเจน; ให้ระบุ `class_hint` เมื่อมีความกำกวม
- ตัวชี้วัดทางเทคนิคและ ACTION เป็น heuristic ไม่ได้คำนึงครบถ้วนถึงค่าธรรมเนียม, ภาษี, ความเสี่ยงสภาพคล่อง, นโยบายกองทุน หรือ suitability ของผู้ลงทุน
- ผลลัพธ์ไม่ใช่คำแนะนำการลงทุนและไม่ควรใช้แทนข้อมูลทางการจาก บลจ./SEC

ดูวิธีตั้งค่าชีตและเรียกใช้ที่ [GOOGLE-SHEETS-SETUP.md](./GOOGLE-SHEETS-SETUP.md)
