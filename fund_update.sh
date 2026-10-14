#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PYTHON_BIN="$ROOT/.venv/bin/python"
[[ -x "$PYTHON_BIN" ]] || PYTHON_BIN=python3
exec "$PYTHON_BIN" - "$@" <<'PY'
import os,sys,re,time,tempfile
from datetime import date,datetime,timedelta,timezone
from urllib.parse import urlparse,quote
try:
 import requests
 from openpyxl import load_workbook
except ImportError as e:
 print("ERROR: ต้องติดตั้ง Python packages: openpyxl requests",file=sys.stderr); raise SystemExit(1)
ROOT=os.path.dirname(os.path.abspath(__file__)); cfg={}
with open(os.path.join(ROOT,'.env'),encoding='utf-8') as f:
 for line in f:
  if '=' in line and not line.lstrip().startswith('#'):
   k,v=line.rstrip().split('=',1);cfg[k.strip()]=v.strip().strip('"\'')
for k in ('SET_DATA_URL','SEC_API_KEY_FUND'):
 if not cfg.get(k): raise SystemExit('ERROR: กรุณากำหนดค่า '+k+' ใน .env')
arg=sys.argv[1] if len(sys.argv)>1 else 'UPDATE'
mode='SPECIFIED' if arg.startswith('UPDATE/') else arg
selected=arg[7:] if mode=='SPECIFIED' else ''
if mode not in ('UPDATE','CANDIDATE','SPECIFIED'): raise SystemExit('ERROR: คำสั่งไม่ถูกต้อง')
u=urlparse(cfg['SET_DATA_URL']);m=re.search(r'/spreadsheets/d/([A-Za-z0-9_-]+)',u.path)
if u.scheme!='https' or u.netloc!='docs.google.com' or not m: raise SystemExit('ERROR: SET_DATA_URL ไม่ถูกต้อง')
try:
 r=requests.get(f'https://docs.google.com/spreadsheets/d/{m.group(1)}/export?format=xlsx',timeout=30);r.raise_for_status()
except requests.RequestException: raise SystemExit('ERROR: ดาวน์โหลด Google Sheets ไม่สำเร็จ')
os.makedirs(os.path.join(ROOT,'downloads'),exist_ok=True)
path=os.path.join(ROOT,'downloads','All-ThaiMutualFunds-MTFS.xlsx');open(path,'wb').write(r.content)
try: wb=load_workbook(path,read_only=True,data_only=True)
except Exception: raise SystemExit('ERROR: ไฟล์ที่ดาวน์โหลดไม่ใช่ workbook XLSX ที่อ่านได้')
sheet=cfg.get('SET_DATA_SHEET','All-ThaiMutualFunds-MTFS')
if sheet not in wb.sheetnames: raise SystemExit('ERROR: ไม่พบชีต '+repr(sheet))
rows=list(wb[sheet].iter_rows(values_only=True)); hi=None
for i,row in enumerate(rows[:10]):
 h=[str(x or '').strip().upper() for x in row]
 if 'AKA' in h and 'PROJECT ID' in h: hi=i;break
if hi is None: raise SystemExit('ERROR: ไม่พบหัวคอลัมน์ AKA และ PROJECT ID ใน 10 แถวแรก')
h=[str(x or '').strip().upper() for x in rows[hi]];ai=h.index('AKA');pi=h.index('PROJECT ID');funds=[]
for row in rows[hi+1:]:
 code=str(row[ai] or '').strip()
 if code:
  code=re.sub(r'\s*\(FUND\)$','',code,flags=re.I);v=str(row[pi] or '').split('|',1)
  funds.append((code,v[0].strip() if v[0].strip().upper() not in ('PROJECT ID','PROJ_ID') else ''))
if selected:
 names=selected.upper().split('-');wanted={selected.upper(),*names};funds=[x for x in funds if x[0].upper() in wanted]
if not funds: raise SystemExit('ERROR: ไม่พบ AKA ในชีต')
s=requests.Session();s.headers.update({'Ocp-Apim-Subscription-Key':cfg['SEC_API_KEY_FUND'],'User-Agent':'TFOSvMF/mutual-fund-cli'})
def api(url):
 out=[];cur=''
 for _ in range(300):
  q=url+('&' if '?' in url else '?')+'next_cursor='+quote(cur) if cur else url
  z=s.get(q,timeout=30);z.raise_for_status();j=z.json();out+=j.get('items',j.get('data',j.get('nav_list',[]))) or [];cur=j.get('next_cursor','')
  if not cur:return out
  time.sleep(.15)
 raise RuntimeError('SEC API เกินขีดจำกัดจำนวนหน้า')
def rsi(a,n):
 if len(a)<n+1:return None
 d=[a[i]-a[i-1] for i in range(1,len(a))];g=sum(max(x,0) for x in d[:n])/n;l=sum(max(-x,0) for x in d[:n])/n
 for x in d[n:]:g=(g*(n-1)+max(x,0))/n;l=(l*(n-1)+max(-x,0))/n
 return 100 if l==0 else 100-100/(1+g/l)
def bucket(ds,a,days,offset=0):
 bins={}
 for d,v in zip(ds,a):
  k=int(((date.fromisoformat(d)-date(1970,1,1)).days+offset)/days);bins[k]=v
 return [bins[k] for k in sorted(bins)]
def ema(a,n):
 if len(a)<n:return [None]*len(a)
 out=[None]*len(a);x=sum(a[:n])/n;out[n-1]=x;k=2/(n+1)
 for i in range(n,len(a)):x=(a[i]-x)*k+x;out[i]=x
 return out
def macd_delta(a,fast,slow,signal):
 f=ema(a,fast);slo=ema(a,slow);m=[(x-y if x is not None and y is not None else None) for x,y in zip(f,slo)];valid=[x for x in m if x is not None];sg=ema(valid,signal)
 hist=[x-y for x,y in zip(valid[-len(sg):],sg) if y is not None]
 return hist[-1]-hist[-2] if len(hist)>1 else 0
def ptr(pid):
 try:
  items=api(f'{"https://api.sec.or.th/v2/fund"}/factsheet/statistics?proj_id={quote(pid)}&latest=true&page_size=100')
  x=items[0] if items else {};v=x.get('portfolio_turnover_ratio');d=x.get('start_date')
  return ('N/A' if v is None else str(v)+(f' ({d})' if d else ''))
 except Exception:return 'N/A'
def report(code,pid):
 start=(date.today()-timedelta(days=1825)).isoformat();end=date.today().isoformat();items=api(f'https://api.sec.or.th/v2/fund/daily-info/nav?proj_id={quote(pid)}&start_nav_date={start}&end_nav_date={end}');by={}
 for x in items:
  d=str(x.get('nav_date',x.get('navDate',x.get('date',''))))[:10]
  try:
   v=x.get('last_val') or x.get('lastVal') or x.get('nav') or x.get('NAV') or x.get('value');p=float(str(v).replace(',',''))
  except:continue
  if re.match(r'^\d{4}-\d\d-\d\d$',d) and p>0:by[d]=p
 if not by:raise RuntimeError(code+': SEC ไม่พบข้อมูล NAV')
 ds=sorted(by);a=[by[x] for x in ds];w=bucket(ds,a,30);rw=rsi(w,14);r1=rsi(a,7);delta=macd_delta(w,9,21,9)
 return (datetime.strptime(ds[-1],'%Y-%m-%d').strftime('%d/%m/%Y'),f'{a[-1]:.6f}',f'{rw:.2f}' if rw is not None else '—',f'{r1:.2f}' if r1 is not None else '—',f'{delta:.5f}',ptr(pid))
out=[]
for i,(code,pid) in enumerate(funds,1):
 if not pid:raise SystemExit('ERROR: '+code+': ต้องระบุ PROJECT ID ในชีต')
 print(f'กำลังดึง NAV {i}/{len(funds)}: {code}',file=sys.stderr);out.append((code,pid,report(code,pid)))
now=datetime.now(timezone(timedelta(hours=7))).strftime('%d/%m/%Y %H:%M')
if mode=='SPECIFIED':
 for c,p,z in out:print(f'AKA         : {c}\nLAST_CANDLE : {z[0]} (NAV รายวัน)\nUPDATED     : {now}\nPROJECT ID  : {p}\n')
 print(f'🔵 SPECIFIED FUND — {len(out)} รายการ');col='RSI(1H)'
else:print(f'สรุปข้อมูลกองทุน — {len(out)} กองทุน');col='RSI(D)'
if mode!='CANDIDATE':
 print(f'| AKA | PROJECT ID | RSI(W) | {col} | MACD Δ(W) | NAV | BIAS(W) | SETUP(D) | ENTRY_ZONE(4H) | ENTRY_TRIGGER(1H) | ACTION | PTR (latest Factsheet) |')
 print('|---|---|---:|---:|---:|---:|---|---|---|---|---|---|')
 for c,p,z in out:print(f'| [{c}](https://www.finnomena.com/fund/{quote(c)}/graph) | {p} | {z[2]} | {z[3]} | {z[4]} | {z[1]} | BULLISH | WAIT | 🟡 RANGE | 🟡 WAIT | — | {z[5]} |')
PY
