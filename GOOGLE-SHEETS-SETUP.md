# Google Sheets setup

## ชีตอินพุต

กำหนดค่าใน `.env`:

```dotenv
SET_DATA_URL=https://docs.google.com/spreadsheets/d/<SHEET_ID>/edit
SET_DATA_SHEET=All-ThaiMutualFunds-MTFS
SEC_API_KEY_FUND=<SEC_API_KEY>
```

ชีตต้องเปิดให้ดาวน์โหลด XLSX ผ่านลิงก์ และมีหัวคอลัมน์ `AKA` กับ `PROJECT ID` ภายใน 10 แถวแรก

| AKA | PROJECT ID |
|---|---|
| B-INNOTECH | M0667_2559 |

## ติดตั้งและรัน

```bash
python3 -m venv .venv
.venv/bin/python -m pip install openpyxl requests
chmod +x update.sh candidate.sh fund_update.sh
./update.sh UPDATE/B-INNOTECH
```

สคริปต์ใช้ inline Python ภายใน [fund_update.sh](./fund_update.sh) ไม่มีไฟล์ `.py` แยก และไม่พิมพ์ secret จาก `.env` ออกในรายงาน

ทุกครั้งที่รันจะดาวน์โหลด snapshot ใหม่ หากดาวน์โหลดไม่สำเร็จ ระบบหยุดทันทีและไม่ใช้ไฟล์เก่า
