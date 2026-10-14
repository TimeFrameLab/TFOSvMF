# TimeFrame OS vMF — แนวทางและแบบจำลองกองทุนรวมไทย

## ขอบเขต

TFOSvMF อ่านรายชื่อกองทุนจาก Google Sheets และ NAV ย้อนหลังจาก SEC Open API เพื่อสร้างรายงานสรุปใน Terminal เท่านั้น ไม่มีการส่งคำสั่งซื้อขายหรือเขียนข้อมูลกลับไปยังชีต

## Output Contract / ข้อกำหนดบังคับเรื่องการแสดงผล

- ใช้เฉพาะคำสั่งตามรูปแบบที่ระบุใน README: `./update.sh`, `./update.sh UPDATE/<AKA>,<AKA>,...` และ `./candidate.sh`
- ชีตอินพุตใช้ `AKA` และ `PROJECT ID`; โปรแกรมดึง NAV/history และ fund profiles จาก SEC แล้วคำนวณค่าที่ใช้ในรายงาน ไม่ต้องมีคอลัมน์ `LAST_CANDLE` หรือ `UPDATED` ในชีต เพราะ metadata นี้คำนวณจาก NAV ล่าสุดและเวลาสร้างรายงาน
- คงกลุ่มและหัวตารางตาม contract ใน README: CANDIDATE แสดงกลุ่ม `🟢 พร้อมครบ W→D→4H — รอ ENTRY_TRIGGER(1H)` ก่อน `🟡 W→D ผ่านแล้ว แต่ 4H ยังไม่ยืนยันโซน`; ห้ามสลับกลุ่มหรือเปลี่ยน ละ หรือตัดหัวตารางของ UPDATE/CANDIDATE
- `UPDATE/<AKA>,...` แสดง metadata รายกองและตาราง `SPECIFIED FUND`; `LAST_CANDLE` เป็นวันที่ NAV ล่าสุดโดยไม่มีเวลาแท่ง intraday เพราะข้อมูล SEC เป็น NAV รายวัน ส่วน `UPDATED` ใช้เวลา Asia/Bangkok
- ตาราง UPDATE รวมแสดง RSI(W), RSI(D), MACD Δ(W), NAV และสรุป BIAS/SETUP/ENTRY/ACTION พร้อม PROJECT ID และ PTR; `SPECIFIED FUND` ใช้ RSI(W), RSI(1H) ในหัวตารางแทน RSI(D); CANDIDATE คงเกณฑ์/สองกลุ่มเดิม และเรียง MACD Δ(W) จากมากไปน้อยภายในกลุ่ม
- แสดง `PTR (latest Factsheet)` หนึ่งคอลัมน์ในทั้ง UPDATE และ CANDIDATE; คัดกองทุน Candidate ก่อนเรียก PTR และเรียกเฉพาะรายการที่แสดง ส่วน UPDATE เรียกเฉพาะกองทุนในรายงาน/AKA ที่ระบุ
- แสดง AKA เป็น Markdown link ไปยัง `https://www.finnomena.com/fund/<AKA>/graph` ภายในคอลัมน์ AKA; ห้ามแสดงคอลัมน์ `FINNOMENA` แยกในรายงาน UPDATE, UPDATE/<AKA> หรือ CANDIDATE
- ห้ามกล่าวว่าดาวน์โหลด ตรวจสอบ หรือทำงานสำเร็จ เว้นแต่มีหลักฐานจากผลการทำงานจริง
- ใช้เฉพาะ snapshot ที่เพิ่งดาวน์โหลดในรอบนั้น ซึ่งบันทึกไว้ที่ `downloads/All-ThaiMutualFunds-MTFS.xlsx`; หากดึง snapshot ล่าสุดไม่ได้ ให้แจ้งข้อผิดพลาดและไม่ใช้ cache หรือข้อมูลเก่าแทน

## ข้อมูลที่ใช้

- `AKA`: ชื่อย่อกองทุนที่ใช้แสดงผลและสร้าง Finnomena link
- `PROJECT ID`: SEC project ID; รูปแบบ `project_id|class_hint` ใช้ระบุ share class เมื่อ endpoint คืนหลาย class
- NAV: ใช้ `last_val`/`lastVal` หรือ alias ที่ API ส่งกลับเป็นราคาปิด
- มูลค่าทรัพย์สินสุทธิ: ใช้ `net_asset`/`netAsset` เพื่อประมาณจำนวนหน่วยจาก `net_asset / NAV`

เก็บ `SEC_API_KEY_FUND` ใน `.env` เท่านั้น ห้ามบันทึกลง source, log, report หรือ Git และอย่าเผยแพร่ spreadsheet ที่มีข้อมูลส่วนตัว

SEC Open API ใช้ NAV/history, fund profiles และ Factsheet statistics แบบ read-only; `portfolio_turnover_ratio` จาก Factsheet ใช้เป็น PTR ได้ แต่เป็นค่า turnover ของพอร์ตตามงวดรายงาน ไม่ใช่มูลค่าซื้อขายรายวันหรือ bid/ask liquidity

PTR ดึงจาก `GET /v2/fund/factsheet/statistics` ด้วย `proj_id`, `fund_class_name` ที่สัมพันธ์กับ share class ของ NAV และ `latest=true`; แสดง `start_date` ของ Factsheet กำกับเมื่อมี หากไม่มีค่าแสดง `N/A` และไม่คำนวณค่าทดแทน

## Timeframes

ตัวอย่างคำนวณ:

| TF | การสร้างแท่ง | การใช้งานใน model |
|---|---|---|
| W | bucket ประมาณ 30 วัน | BIAS ระยะยาว |
| D | bucket 7 วัน | SETUP |
| 4H | NAV รายวัน | ENTRY_ZONE |
| 1H | NAV รายวันชุดเดียวกับ 4H | ENTRY_TRIGGER ด้วย periods ที่สั้นกว่า |

ชื่อ W/D/4H/1H เป็นป้ายกำกับเชิงกลยุทธ์ของแบบจำลอง ไม่ใช่ข้อมูล NAV ในความถี่จริง โดยเฉพาะ 4H และ 1H ไม่ได้มีแท่ง intraday

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
