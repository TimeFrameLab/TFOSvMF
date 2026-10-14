#!/usr/bin/env ruby
# Read-only Thai mutual-fund NAV reports. Uses macOS Ruby standard libraries,
# curl, and unzip; no Python runtime or third-party Ruby gems are required.
require 'json'
require 'rexml/document'
require 'rexml/xpath'
require 'uri'
require 'time'
require 'fileutils'
require 'tempfile'
require 'tmpdir'
require 'date'
require 'cgi'
Encoding.default_external = Encoding::UTF_8

module TFOSvMF
  ROOT = File.expand_path(__dir__)
  XLSX = File.join(ROOT, 'downloads', 'All-ThaiMutualFunds-MTFS.xlsx')
  SEC = 'https://api.sec.or.th/v2/fund'
  MAX_BYTES = 25 * 1024 * 1024
  TF = {'W'=>[30*86400,0], 'D'=>[7*86400,3*86400], '4H'=>[86400,0], '1H'=>[86400,0]}
  CFG = {
    'W'=>[14,4,9,21,12,26,9,35,75,4], 'D'=>[14,5,9,21,12,26,9,38,72,7],
    '4H'=>[14,10,9,21,12,26,9,40,70,20], '1H'=>[7,5,5,10,6,13,5,45,65,8]
  }
  CLASS_FIELDS = %w[fund_class_name fundClassName class_abbr_name classAbbrName class_name className unit_type unitType cls_abbr_name clsAbbrName fund_class fundClass proj_id_class class_id classId]

  class Error < StandardError; end

  def self.command(args)
    raise Error, 'Usage: ./update.sh [UPDATE/<AKA>-<AKA>-...]' if args.length > 1
    raw = args.first || 'UPDATE'
    return ['UPDATE', nil] if raw == 'UPDATE'
    return ['CANDIDATE', nil] if raw == 'CANDIDATE'
    raise Error, 'คำสั่งต้องเป็น UPDATE, UPDATE/<AKA>-<AKA>-... หรือ CANDIDATE' unless raw.start_with?('UPDATE/')
    names = raw.delete_prefix('UPDATE/').split('-', -1)
    raise Error, 'รูปแบบ AKA ในคำสั่งไม่ถูกต้อง' if names.empty? || names.any? { |s| s.empty? || s.length > 40 || s !~ /\A[A-Za-z0-9][A-Za-z0-9 ._&()\/#-]*\z/ }
    # Hyphens are legal inside fund AKAs. Resolve the joined command against
    # actual AKA values from the sheet using longest-match segmentation.
    ['UPDATE', names]
  end

  def self.config
    values = {}
    %w[SET_DATA_URL SET_DATA_SHEET SEC_API_KEY_FUND].each { |k| values[k] = ENV[k] if ENV[k] && !ENV[k].empty? }
    env_path = File.join(ROOT, '.env')
    raise Error, 'ไม่พบไฟล์ .env; กรุณาคัดลอก .env.example เป็น .env' unless File.file?(env_path) || values['SET_DATA_URL']
    if File.file?(env_path)
      File.foreach(env_path) do |line|
        line = line.strip
        next if line.empty? || line.start_with?('#') || !line.include?('=')
        k,v = line.split('=',2).map(&:strip)
        v = v[1...-1] if v && v.length >= 2 && %w[" '].include?(v[0]) && v[0] == v[-1]
        values[k] ||= v if %w[SET_DATA_URL SET_DATA_SHEET SEC_API_KEY_FUND].include?(k)
      end
    end
    missing = %w[SET_DATA_URL SEC_API_KEY_FUND].reject { |k| values[k] && !values[k].strip.empty? }
    raise Error, 'กรุณากำหนดค่าใน .env: ' + missing.join(', ') unless missing.empty?
    values['SET_DATA_SHEET'] ||= 'All-ThaiMutualFunds-MTFS'
    values
  end

  def self.get_bytes(url, headers=[])
    Tempfile.create('tfosvmf') do |f|
      args = ['-L','--silent','--show-error','--fail','--max-time','30']
      headers.each { |h| args += ['-H',h] }
      args += ['-o',f.path,url]
      IO.popen(['curl',*args], err: [:child,:out]) { |io| io.read }
      status = $?.exitstatus
      raise Error, 'ดาวน์โหลด Google Sheets ไม่สำเร็จ' unless status == 0
      raise Error, "ไฟล์ workbook มีขนาดเกิน #{MAX_BYTES / 1024 / 1024} MB" if File.size(f.path) > MAX_BYTES
      File.binread(f.path)
    end
  end

  def self.xlsx_rows(data, sheet_name)
    Dir.mktmpdir('tfosvmf-xlsx') do |dir|
      path = File.join(dir,'book.xlsx'); File.binwrite(path,data)
      ok = system('unzip','-q',path,'-d',dir, out: File::NULL, err: File::NULL)
      raise Error, 'ไฟล์ที่ดาวน์โหลดไม่ใช่ workbook XLSX ที่อ่านได้ (ต้องมี unzip)' unless ok
      wb = REXML::Document.new(File.read(File.join(dir,'xl','workbook.xml')))
      rel = REXML::Document.new(File.read(File.join(dir,'xl','_rels','workbook.xml.rels')))
      rels = {}; REXML::XPath.each(rel,'//*[local-name()="Relationship"]') { |n| rels[n.attributes['Id']] = n.attributes['Target'] }
      sheet = nil
      REXML::XPath.each(wb,'//*[local-name()="sheet"]') { |n| sheet=n if n.attributes['name']==sheet_name }
      raise Error, "ไม่พบชีต #{sheet_name.inspect} ใน workbook" unless sheet
      target = rels[sheet.attributes['r:id']]
      target = File.expand_path(target.start_with?('/') ? target[1..] : "xl/#{target}",dir)
      shared=[]; sp=File.join(dir,'xl','sharedStrings.xml')
      if File.file?(sp)
        File.read(sp).scan(/<si\b[^>]*>(.*?)<\/si>/m) do |match|
          shared << match[0].scan(/<t\b[^>]*>(.*?)<\/t>/m).flatten.map{|v|CGI.unescapeHTML(v)}.join
        end
      end
      # Sheet XML can contain millions of characters; scanning cell/row tags
      # is substantially lighter than building a full REXML node tree.
      xml=File.read(target); rows=[]
      xml.scan(/<row\b[^>]*>(.*?)<\/row>/m) do |row_match|
        vals=[]
        row_match[0].scan(/<c\b([^>]*)>(.*?)<\/c>/m) do |attrs,content|
          ref=attrs[/\br="([^"]+)"/,1].to_s; col=ref[/\A[A-Z]+/]; next unless col
          idx=col.chars.reduce(0){|a,ch|a*26+ch.ord-64}-1
          type=attrs[/\bt="([^"]+)"/,1]
          v=content[/<v\b[^>]*>(.*?)<\/v>/m,1]
          if type=='s' then v=shared[v.to_i]
          elsif type=='inlineStr' then v=content.scan(/<t\b[^>]*>(.*?)<\/t>/m).flatten.map{|x|CGI.unescapeHTML(x)}.join
          elsif v then v=CGI.unescapeHTML(v)
          end
          vals[idx]=v if idx>=0
        end
        rows<<vals
      end
      rows
    end
  rescue REXML::ParseException, Errno::ENOENT
    raise Error, 'ไฟล์ที่ดาวน์โหลดไม่ใช่ workbook XLSX ที่อ่านได้'
  end

  def self.rows_from_sheet(cfg, selected)
    uri=URI(cfg['SET_DATA_URL']); match=uri.path.match(%r{/spreadsheets/d/([A-Za-z0-9_-]+)(?:/|$)})
    raise Error, 'SET_DATA_URL ต้องเป็น URL ของ Google Sheets ที่เข้าถึงได้ด้วยลิงก์' unless uri.scheme=='https' && uri.host=='docs.google.com' && match
    url="https://docs.google.com/spreadsheets/d/#{match[1]}/export?format=xlsx"
    data=get_bytes(url,['User-Agent: TFOSvMF/mutual-fund-cli','Cache-Control: no-cache, no-store, max-age=0','Pragma: no-cache'])
    FileUtils.mkdir_p(File.dirname(XLSX)); Tempfile.create('.snapshot',File.dirname(XLSX)) { |f| f.binmode; f.write(data); f.close; File.rename(f.path,XLSX) }
    all=xlsx_rows(data,cfg['SET_DATA_SHEET']); header_idx=all.first(10).index{|r|Array(r).map{|x|x.to_s.strip.upcase}.include?('AKA')}
    raise Error, 'ไม่พบหัวคอลัมน์ AKA ใน 10 แถวแรก' unless header_idx
    headers=all[header_idx].map{|x|x.to_s.strip.upcase}; ai=headers.index('AKA'); pi=headers.index('PROJECT ID')
    raise Error,'ขาดคอลัมน์ PROJECT ID ในชีต' unless pi
    records=[]
    all.drop(header_idx+1).each_with_index do |r,i|
      code=(r[ai]||'').to_s.strip; next if code.empty?
      code=code.sub(/\s*\(FUND\)\z/i,'').strip
      raise Error,"แถว #{header_idx+i+2}: AKA มีรูปแบบไม่ถูกต้อง" unless code.length<=40 && code.match?(/\A[A-Za-z0-9][A-Za-z0-9 ._&()\/#-]*\z/)
      p=(r[pi]||'').to_s.strip.split('|',2); id=p[0].to_s.strip; id='' if %w[PROJECT ID PROJ_ID].include?(id.upcase)
      records << {'code'=>code,'id'=>id,'hint'=>p[1].to_s.strip,'row'=>header_idx+i+2}
    end
    dup=records.group_by{|r|r['code'].upcase}.find{|_,v|v.length>1}; raise Error,"AKA ซ้ำ (#{dup[0]})" if dup
    if selected
      # Match the requested dash-joined string against known sheet AKAs.
      raw=selected.join('-').upcase; candidates=records.map{|r|r['code']}.sort_by{|s|-s.length}
      chosen=[]; cursor=0
      while cursor<raw.length
        hit=candidates.find{|s|raw[cursor,s.length]==s.upcase && (cursor+s.length==raw.length || raw[cursor+s.length]=='-')}
        raise Error,"แยกรายชื่อ AKA ไม่ได้ใกล้ #{raw[cursor..]}" unless hit
        chosen << hit; cursor+=hit.length; cursor+=1 if raw[cursor]=='-'
      end
      raise Error,'มี AKA ซ้ำในคำสั่ง UPDATE' unless chosen.map(&:upcase).uniq.length==chosen.length
      missing=chosen.reject{|c|records.any?{|r|r['code'].upcase==c.upcase}}
      raise Error,'ไม่พบ AKA ในชีต: '+missing.join(', ') unless missing.empty?
      records.select!{|r|chosen.any?{|c|c.upcase==r['code'].upcase}}
    end
    raise Error,'ไม่พบแถวกองทุนที่มี AKA ในชีต' if records.empty?
    records
  end

  def self.sec(url,key)
    body,status=http_response(url,["Ocp-Apim-Subscription-Key: #{key}",'User-Agent: TFOSvMF/mutual-fund-cli'])
    return [status,nil] if status==204 || body.empty?
    raise Error,"SEC Open API ตอบกลับ HTTP #{status}" unless status==200
    [status,JSON.parse(body)]
  rescue JSON::ParserError
    raise Error,'SEC Open API ส่งข้อมูล JSON ไม่ถูกต้อง'
  end
  def self.http_response(url,headers=[])
    Tempfile.create('tfosvmf-http') do |f|
      args=['-L','--silent','--show-error','--max-time','30']; headers.each{|h|args+=['-H',h]}
      args+=['-o',f.path,'-w','%{http_code}',url]
      code=IO.popen(['curl',*args],err:[:child,:out]){|io|io.read}
      status=$?.exitstatus==0 ? code.to_i : 0
      raise Error,'เชื่อมต่อ SEC Open API ไม่สำเร็จ' if status==0
      [File.binread(f.path),status]
    end
  end
  def self.api_items(url,key,limit=300)
    all=[]; cursor=nil
    limit.times do
      u=cursor ? "#{url}#{url.include?('?') ? '&' : '?'}next_cursor=#{URI.encode_www_form_component(cursor)}" : url
      status,payload=sec(u,key); break if payload.nil? && status==204
      raise Error,'SEC Open API ไม่ส่งข้อมูล JSON object' unless payload.is_a?(Hash)
      list=payload['items']||payload['data']||payload['nav_list']||[]
      raise Error,'รูปแบบรายการจาก SEC ไม่ถูกต้อง' unless list.is_a?(Array)
      all.concat(list.select{|x|x.is_a?(Hash)}); cursor=payload['next_cursor']; cursor=nil if cursor.to_s.empty?; break unless cursor
      sleep 0.15
    end
    raise Error,'SEC API เกินขีดจำกัดจำนวนหน้า' if cursor
    all
  end
  def self.build_nav(row,key)
    to=Date.today; from=to-1825
    url="#{SEC}/daily-info/nav?#{URI.encode_www_form(proj_id:row['id'],start_nav_date:from.iso8601,end_nav_date:to.iso8601)}"
    items=api_items(url,key,60); raise Error,"#{row['code']}: SEC ไม่พบข้อมูล NAV" if items.empty?
    field=CLASS_FIELDS.find{|f|items[0].key?(f)&&items.map{|x|(x[f]||'').to_s.strip}.uniq.length>1}
    classes=field ? items.map{|x|(x[field]||'').to_s.strip}.uniq : []
    selected=items
    warn_class=''; class_name=''
    if classes.length>1
      if !row['hint'].empty?
        match=classes.select{|c|c.upcase.include?(row['hint'].upcase)||row['hint'].upcase.include?(c.upcase)}
        raise Error,"#{row['code']}: class hint matches multiple SEC classes" if match.length>1
        selected=items.select{|x|(x[field]||'').to_s.strip==match[0]} unless match.empty?
        raise Error,"#{row['code']}: class hint ไม่ตรงกับ SEC class" if match.empty?
      else
        sizes=classes.to_h{|c|[c,items.count{|x|(x[field]||'').to_s.strip==c}]}; standard=classes.reject{|c|c.upcase.match?(/(?:USD|SSF|RMF|UH|UHA|UHI|P|\(E\))\z/)}
        pool=standard.empty? ? classes : standard; max=pool.map{|c|sizes[c]}.max; winners=pool.select{|c|sizes[c]==max}
        raise Error,"#{row['code']}: SEC มีหลาย class; ระบุ class hint ใน PROJECT ID" if winners.length!=1
        selected=items.select{|x|(x[field]||'').to_s.strip==winners[0]}; warn_class="เลือก class #{winners[0]} อัตโนมัติจาก #{classes.length} classes"
      end
      class_name=(selected.first[field]||'').to_s.strip
    else
      class_name=(items.first[field]||'').to_s.strip if field
    end
    by={}
    selected.each do |x|
      d=(x['nav_date']||x['navDate']||x['date']||x['Date']).to_s[0,10]; next unless d.match?(/\A\d{4}-\d\d-\d\d\z/)
      price=Float((x['last_val']||x['lastVal']||x['nav']||x['NAV']||x['value']).to_s.gsub(',','')) rescue nil
      next unless price && price>0
      units=Float((x['net_asset']||x['netAsset']||x['NetAsset']).to_s.gsub(',','')) rescue nil
      by[d]=[Time.parse(d+' UTC').to_i,price,units ? units/price : Float::NAN]
    end
    vals=by.keys.sort.map{|d|by[d]}; raise Error,"#{row['code']}: NAV ไม่มีวันที่หรือราคาอ่านได้" if vals.empty?
    {'times'=>vals.map(&:first),'closes'=>vals.map{|x|x[1]},'units'=>vals.map{|x|x[2]},'class'=>class_name,'warning'=>warn_class}
  end
  def self.indicator(s,tf,reference)
    cfg=CFG[tf]; rsi_n,trend_n,fast_n,slow_n,mf,ms,signal_n,buy,sell,vol_n=cfg
    c=s['closes']; h=s['highs']; l=s['lows']; v=s['volumes']
    ef=ema(c,fast_n); es=ema(c,slow_n); mfv=ema(c,mf); msv=ema(c,ms); macd=mfv.zip(msv).map{|a,z|a&&z ? a-z : nil}
    first=macd.index{|x|!x.nil?}||macd.length; compact=ema(macd[first..].compact,signal_n); sig=Array.new(first)+compact; sig+=(Array.new(macd.length-sig.length) if sig.length<macd.length) || []
    hist=macd.zip(sig).map{|a,z|a&&z ? a-z : nil}; delta=hist.compact.length>=2 ? hist.compact[-1]-hist.compact[-2] : nil
    trend=c.length>=trend_n+1 ? (c[-1]>=c.last(trend_n).sum.to_f/trend_n ? 'UP':'DOWN') : nil
    rv=rsi(c,rsi_n); cross=''; cross='BUY' if ef.length>1&&ef[-2]&&es[-2]&&ef[-1]&&es[-1]&&ef[-2]<=es[-2]&&ef[-1]>es[-1];cross='SELL' if ef.length>1&&ef[-2]&&es[-2]&&ef[-1]&&es[-1]&&ef[-2]>=es[-2]&&ef[-1]<es[-1]
    macd_cross=''; macd_cross='BUY' if macd.length>1&&macd[-2]&&sig[-2]&&macd[-1]&&sig[-1]&&macd[-2]<=sig[-2]&&macd[-1]>sig[-1];macd_cross='SELL' if macd.length>1&&macd[-2]&&sig[-2]&&macd[-1]&&sig[-1]&&macd[-2]>=sig[-2]&&macd[-1]<sig[-1]
    volume_signal=nil; ix=v.length-2
    if v.length>=vol_n+2 && ix-vol_n>=0
      avg=v[(ix-vol_n)...ix].sum.to_f/vol_n
      if avg!=0
        volume_signal='BUY' if v[ix]>avg&&v[ix]>v[ix-1]
        volume_signal='SELL' if !volume_signal&&c[ix]<c[ix-1]&&delta&&delta<0&&cross=='SELL'&&v[ix]<avg*0.8
        volume_signal='HOLD' unless volume_signal
      end
    end
    st=structure(h,l,reference)
    {'trend'=>trend,'rsi'=>rv,'delta'=>delta,'cross'=>cross,'macd_cross'=>macd_cross,'volume'=>volume_signal,'structure'=>st,'close'=>c[-1],'closes'=>c}
  end
  def self.report(row,nav)
    flow=[0.0];(1...nav['units'].length).each{|i|a=nav['units'][i];b=nav['units'][i-1];flow<<((a.finite?&&b.finite?) ? (a-b).abs : 0.0)}
    series={}; TF.each do |name,(seconds,offset)|
      buckets={};nav['times'].each_with_index do |time,i|
        key=(time+offset)/seconds;v=buckets[key]||={'time'=>time,'high'=>nav['closes'][i],'low'=>nav['closes'][i],'close'=>nav['closes'][i],'volume'=>0.0}
        v['high']=[v['high'],nav['closes'][i]].max;v['low']=[v['low'],nav['closes'][i]].min;v['close']=nav['closes'][i];v['volume']+=flow[i]
      end
      a=buckets.keys.sort.map{|k|buckets[k]};series[name]={'times'=>a.map{|v|v['time']},'closes'=>a.map{|v|v['close']},'highs'=>a.map{|v|v['high']},'lows'=>a.map{|v|v['low']},'volumes'=>a.map{|v|v['volume']}}
    end
    tf={}; TF.each_key do |k|
      finer={'W'=>'D','D'=>'4H','4H'=>'1H'}[k];ref_series=finer&&series[finer]['closes'].length>=2 ? series[finer] : series[k]
      reference=ref_series['closes'][-2]||ref_series['closes'][-1];tf[k]=indicator(series[k],k,reference)
    end
    w=tf['W']['structure']; bias=w ? {'UP'=>'BULLISH','DOWN'=>'BEARISH','REVERSAL'=>'RECOVERY','DOWN_REV'=>'RECOVERY'}.fetch(w['state'],'NEUTRAL') : ''
    ds=tf['D']; setup=''; if ds['structure']; setup=ds['rsi']&&ds['rsi']>72 ? 'EXTENDED' : {'DOWN'=>'FAILED','DOWN_REV'=>'RECOVERY','UP'=>'READY','REVERSAL'=>'READY'}.fetch(ds['structure']['state'],'WAIT'); setup='PULLBACK' if setup=='READY'&&ds['rsi']&&ds['rsi']<=50;end
    zst=tf['4H']['structure']; zone=zst ? {'UP'=>(tf['4H']['close']>zst['high'] ? '🟢 BREAKOUT':'🟢 HH/HL'),'REVERSAL'=>'🟡 RETEST','DOWN_REV'=>'🟡 RETEST','UP_WEAK'=>'🟡 RANGE','DOWN'=>(tf['4H']['close']<zst['low'] ? '🔴 BREAKDOWN':'🔴 LH/LL')}.fetch(zst['state'],'🟡 RANGE') : ''
    t1=tf['1H']; one=t1['structure']; trigger=''; if one; bull=t1['cross']=='BUY'&&(t1['volume']=='BUY'||(t1['delta']&&t1['delta']>0)); bear=t1['cross']=='SELL'&&(t1['volume']=='SELL'||(t1['delta']&&t1['delta']<0)); trigger=['UP','REVERSAL'].include?(one['state']) ? (bull ? (t1['close']>one['high'] ? '🟢 BREAKOUT':'🟢 ENTRY'):'🟡 WAIT') : (['DOWN','UP_WEAK'].include?(one['state']) ? (bear ? '🔴 FAILED':'🟡 RETEST') : '🟡 WAIT');end
    action=''
    if bias=='BULLISH'&&%w[READY RECOVERY PULLBACK].include?(setup)
      action=zone.start_with?('🟢') ? (trigger.start_with?('🟢') ? 'BUY':'WAIT') : ''
    elsif bias=='BEARISH'&&setup=='FAILED'
      action=zone.start_with?('🔴') ? (trigger.start_with?('🔴') ? 'SELL':'WAIT') : ''
    end
    {'row'=>row,'nav'=>nav,'tf'=>tf,'bias'=>bias,'setup'=>setup,'zone'=>zone,'trigger'=>trigger,'action'=>action}
  end
  def self.ptr(report,key)
    row=report['row']; q={proj_id:row['id'],latest:'true',page_size:'100'};q[:fund_class_name]=report['nav']['class'] unless report['nav']['class'].empty?
    items=api_items("#{SEC}/factsheet/statistics?#{URI.encode_www_form(q)}",key,300)
    class_name=report['nav']['class'].empty? ? row['hint'] : report['nav']['class']
    if class_name.empty?
      classes=items.map{|x|(x['fund_class_name']||'').to_s.strip.upcase}.uniq
      raise Error,"project ID #{row['id']}: PTR มีหลาย share class แต่ไม่สามารถระบุ class ได้" if classes.length>1
    else
      items.select!{|x|(x['fund_class_name']||'').to_s.strip.upcase==class_name.upcase}
    end
    items.sort_by!{|x|[x['start_date'].to_s,x['last_upd_date'].to_s]}.reverse!
    if items.length>1 && items[0]['start_date'].to_s==items[1]['start_date'].to_s && items[0]['last_upd_date'].to_s==items[1]['last_upd_date'].to_s
      raise Error,"project ID #{row['id']}: SEC ส่ง PTR ล่าสุดซ้ำในงวดเดียวกัน"
    end
    x=items.first; x&&x['portfolio_turnover_ratio'] ? "#{x['portfolio_turnover_ratio']}#{x['start_date'] ? " (#{x['start_date']})" : ''}" : 'N/A'
  end
  def self.fmt(x,n=4); x.nil? ? '—' : format("%.#{n}f",x); end
  def self.render(reports,command,specified)
    if specified
      updated=Time.now.getlocal('+07:00').strftime('%d/%m/%Y %H:%M')
      reports.each{|r|puts "AKA         : #{r['row']['code']}\nLAST_CANDLE : #{Time.at(r['nav']['times'][-1]).getlocal('+07:00').strftime('%d/%m/%Y')} (NAV รายวัน)\nUPDATED     : #{updated}\nPROJECT ID  : #{r['row']['id']}\n\n"}
      puts "🔵 SPECIFIED FUND — #{reports.length} รายการ"
    else
      puts "สรุปข้อมูลกองทุน — #{reports.length} กองทุน"
    end
    headers=['AKA','PROJECT ID','RSI(W)',specified ? 'RSI(1H)':'RSI(D)','MACD Δ(W)','NAV','BIAS(W)','SETUP(D)','ENTRY_ZONE(4H)','ENTRY_TRIGGER(1H)','ACTION','PTR (latest Factsheet)']; puts '| '+headers.join(' | ')+' |';puts '|'+headers.map{'---'}.join('|')+'|'
    reports.each do |r|
      row=r['row'];tf=r['tf'];url="https://www.finnomena.com/fund/#{URI.encode_www_form_component(row['code'])}/graph";ptr=r['ptr']||'N/A'
      vals=["[#{row['code']}](#{url})",row['id'].empty? ? '—':row['id'],fmt(tf['W']['rsi'],2),fmt(tf[specified ? '1H':'D']['rsi'],2),fmt(tf['W']['delta'],5),fmt(r['nav']['closes'][-1],6),r['bias'].empty? ? 'WAIT':r['bias'],r['setup'].empty? ? 'WAIT':r['setup'],r['zone'].empty? ? 'WAIT':r['zone'],r['trigger'].empty? ? 'WAIT':r['trigger'],r['action']=='SELL' ? 'EXIT' : (r['action'].empty? ? '—':r['action']),ptr]
      puts '| '+vals.join(' | ')+' |'
    end
    warnings=reports.select{|r|!r['nav']['warning'].empty?}
    unless warnings.empty?
      puts "\nSEC class warnings:"
      warnings.each{|r|puts "- #{r['row']['code']}: #{r['nav']['warning']}"}
    end
  end

  def self.ema(a,n)
    out=Array.new(a.length); return out if a.length<n
    x=a.first(n).sum.to_f/n; out[n-1]=x; k=2.0/(n+1)
    (n...a.length).each{|i|x=(a[i]-x)*k+x;out[i]=x}; out
  end
  def self.rsi(a,n)
    return nil if a.length<n+1
    d=a.each_cons(2).map{|x,y|y-x}; g=d.first(n).sum{|x|[x,0].max}.to_f/n; l=d.first(n).sum{|x|[-x,0].max}.to_f/n
    d.drop(n).each{|x|g=(g*(n-1)+[x,0].max)/n;l=(l*(n-1)+[-x,0].max)/n}; l==0 ? 100.0 : 100-100.0/(1+g/l)
  end
  def self.structure(high,low,ref)
    piv=lambda{|a,is_hi| (2...a.length-2).select{|i| z=a[i-2,2]+a[i+1,2]; z.all?{|v|is_hi ? a[i]>v : a[i]<v}}.map{|i|a[i]}}
    h=piv.call(high,true); l=piv.call(low,false); return nil if h.length<3 || l.length<3
    cmp=lambda{|a,hi|return '' if a.length<2; x,y=a[-2],a[-1]; return 'EQ' if x!=0 && (y-x).abs/x.abs<=0.005; hi ? (y>x ? 'HH':'LH') : (y>x ? 'HL':'LL')}
    hs=cmp.call(h,true); ls=cmp.call(l,false); ph=cmp.call(h[0...-1],true); pl=cmp.call(l[0...-1],false); s='MIXED'
    s='UP' if hs=='HH'&&ls=='HL'&&ph=='HH'; s='REVERSAL' if hs=='HH'&&ls=='HL'&&ph=='LH'; s='DOWN' if hs=='LH'&&ls=='LL'
    s='DOWN_REV' if hs=='LH'&&ls=='HL'&&pl=='LL'; s='UP_WEAK' if hs=='LH'&&ls=='HL'&&ph=='HH'
    s={'UP'=>'UP_WEAK','REVERSAL'=>'MIXED','DOWN_REV'=>'DOWN','UP_WEAK'=>'DOWN'}.fetch(s,s) if ref<l[-1]
    {'state'=>s,'high'=>h[-1],'low'=>l[-1]}
  end
  def self.main(args)
    command,selected=command(args); cfg=config; rows=rows_from_sheet(cfg,selected)
    warn "✅ ดาวน์โหลดและตรวจสอบ snapshot: #{XLSX}"
    key=cfg['SEC_API_KEY_FUND']
    profiles=nil
    rows.each_with_index do |row,i|
      next unless row['id'].empty?
      unless profiles
        warn 'กำลังค้นหา PROJECT ID ที่ว่างจาก SEC profiles...'
        profiles=api_items("#{SEC}/general-info/profiles",key,300)
      end
      canon=lambda{|v|v.to_s.gsub(/\s+/,'').upcase}
      name=lambda{|x|%w[proj_abbr_name projAbbrName fund_abbr_name fundAbbrName abbr_name abbrName proj_name_en].map{|k|x[k].to_s.strip}.find{|v|!v.empty?}.to_s}
      pid=lambda{|x|(x['proj_id']||x['projId']||x['project_id']).to_s.strip}
      exact=profiles.select{|x|canon.call(name.call(x))==canon.call(row['code'])&&!pid.call(x).empty?}
      matches=exact.empty? ? profiles.select{|x|n=canon.call(name.call(x));!n.empty?&&!pid.call(x).empty?&&(n.start_with?(canon.call(row['code']))||canon.call(row['code']).start_with?(n))} : exact
      raise Error,"#{row['code']}: ชื่อย่อจับคู่ SEC ได้ #{matches.length} รายการ; ระบุ PROJECT ID ในชีต" unless matches.length==1
      row['id']=pid.call(matches[0])
    end
    reports=[];errors=[]
    rows.each_with_index do |row,i|
      warn "กำลังดึง NAV #{i+1}/#{rows.length}: #{row['code']}"
      begin
        nav=build_nav(row,key); reports<<report(row,nav)
      rescue Error=>e
        errors<<e.message
      end
      sleep 0.25 if i+1<rows.length
    end
    if command=='UPDATE'
      reports.each_with_index do |r,i|
        warn "กำลังดึง PTR #{i+1}/#{reports.length}: #{r['row']['code']}"
        begin;r['ptr']=ptr(r,key);rescue Error=>e;errors<<"#{r['row']['code']}: ดึง PTR จาก SEC ไม่สำเร็จ: #{e.message}";end
      end
      render(reports,command,!selected.nil?) unless reports.empty?
    else
      groups=candidate_groups(reports);selected_reports=groups.flatten
      selected_reports.each_with_index do |r,i|
        warn "กำลังดึง PTR #{i+1}/#{selected_reports.length}: #{r['row']['code']}"
        begin;r['ptr']=ptr(r,key);rescue Error=>e;errors<<"#{r['row']['code']}: ดึง PTR จาก SEC ไม่สำเร็จ: #{e.message}";end
      end
      render_candidates(groups) unless reports.empty?
    end
    errors.each{|e|warn "ERROR: #{e}"};return errors.empty? ? 0 : 1
  rescue Error => e
    warn "ERROR: #{e.message}"; 1
  rescue StandardError => e
    warn "ERROR: ประมวลผลไม่สำเร็จ: #{e.message}"; 1
  end

  def self.candidate_groups(reports)
    a=[];b=[];reports.each do |r|
      next unless r['bias']=='BULLISH'&&%w[READY RECOVERY PULLBACK].include?(r['setup'])
      if r['zone'].start_with?('🟢')&&r['trigger'].start_with?('🟡');a<<r
      elsif !r['zone'].start_with?('🟢')&&!r['trigger'].start_with?('🟢');b<<r;end
    end;[a,b]
  end
  def self.render_candidates(groups)
    [['🟢 พร้อมครบ W→D→4H — รอ ENTRY_TRIGGER(1H)',groups[0]],['🟡 W→D ผ่านแล้ว แต่ 4H ยังไม่ยืนยันโซน',groups[1]]].each do |title,items|
      puts "\n#{title} — #{items.length} กองทุน";h=['#','AKA','PROJECT ID','NAV','MACD Δ(W)','ENTRY_ZONE(4H)','ENTRY_TRIGGER(1H)','PTR (latest Factsheet)'];puts '| '+h.join(' | ')+' |';puts '|'+h.map{'---'}.join('|')+'|'
      if items.empty?;puts '| '+Array.new(h.length,'—').join(' | ')+' |';next;end
      sorted=items.sort_by{|r|[r['tf']['W']['delta'].nil? ? 1:0,-(r['tf']['W']['delta']||0)]}
      sorted.each_with_index do |r,i|
        code=r['row']['code'];url="https://www.finnomena.com/fund/#{URI.encode_www_form_component(code)}/graph";v=[(i+1).to_s,"[#{code}](#{url})",r['row']['id'].empty? ? '—':r['row']['id'],fmt(r['nav']['closes'][-1],6),fmt(r['tf']['W']['delta'],5),r['zone'].empty? ? 'WAIT':r['zone'],r['trigger'].empty? ? 'WAIT':r['trigger'],r['ptr']||'N/A'];puts '| '+v.join(' | ')+' |'
      end
    end
  end
end

exit TFOSvMF.main(ARGV)
