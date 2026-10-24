return function(M)
 local W={}
 function W.handles(id) return id:match('^extra:') or id:match('^table:style:') or id:match('^number:') or id:match('^image:') or id:match('^chart:') or id=='table:template' or id:match('^template:') end
 local function mediaSelection(ctx,action)
  local objects,elements={},{};local expected=action:match('^image:') and 'image' or 'chart';local errorMessage
  local function scan(e)
   local role=e:attributeValue('AXRole')
   if (role=='AXLayoutItem' or role=='AXTable') and e:attributeValue('AXSelected')==true then
    local rd=e:attributeValue('AXRoleDescription') or '';local desc=e:attributeValue('AXDescription') or ''
    local kind=(rd=='이미지' or rd=='image') and 'image' or ((desc:find('차트',1,true) or desc:lower():find('chart',1,true)) and 'chart' or 'other')
    if kind~=expected then errorMessage=expected=='image' and '이미지만 선택하세요.' or '차트만 선택하세요.';return end
    elements[#elements+1]=e
    if ctx.kind=='numbers' then
     local help=(e:attributeValue('AXHelp') or ''):gsub(',(%d%d%d)', '%1')
     local w=tonumber(help:match('너비 ([%d%.%-]+)포인트'));local h=tonumber(help:match('높이 ([%d%.%-]+)포인트'))
     local y=tonumber(help:match('위에서 ([%d%.%-]+)포인트'));local x=tonumber(help:match('왼쪽에서 ([%d%.%-]+)포인트'))
     if not (w and h and x and y) then errorMessage='선택 대상체의 크기·위치를 확인하지 못했습니다.';return end
     objects[#objects+1]={width=w,height=h,x=x,y=y}
    end
    return
   end
   for _,c in ipairs(e:attributeValue('AXChildren') or {})do scan(c)end
  end
  scan(hs.axuielement.windowElement(ctx.window));ctx.mediaElements=elements
  if #elements==0 then errorMessage='이미지 또는 차트를 먼저 선택하세요.' end
  return objects,errorMessage
 end
 local function restoreMedia(ctx)
  local elements=ctx.mediaElements or {}
  if #elements==0 then return end
  for _,e in ipairs(elements) do if not e:isValid() then return end end
  if #elements==1 then elements[1]:setAttributeValue('AXSelected',true) end
 end
 local function worker(ctx,action)
  local objects,errorMessage=mediaSelection(ctx,action);if errorMessage then M.completed(false,errorMessage);return end
  if ctx.kind=='numbers' and action:match('^chart:') then W.nativeResize(ctx,action,objects);return end
  M.busy=true
  W.worker=hs.task.new('/usr/bin/osascript',function(code,out,err)
   if W.timeout then W.timeout:stop() end
   W.lastMedia=code==0 and hs.json.decode(out) or nil
   local front=hs.application.frontmostApplication();if front and front:pid()==ctx.pid and ctx.app:focusedWindow() and ctx.app:focusedWindow():id()==ctx.window:id() then restoreMedia(ctx) end
   M.completed(code==0,code==0 and (#(ctx.mediaElements or {})>1 and '사진 여러 개 적용 · 다음 작업 전 다시 선택' or '선택한 대상체에 적용 · 비율 유지') or (err:match('Error: ([^\n]+)') or '대상체 선택을 확인하세요.'))
  end,{'-l','JavaScript',M.root..'/media-tools.js',hs.json.encode({id=ctx.app:bundleID(),window=ctx.window:title(),action=action,objects=objects})}):start()
  W.timeout=hs.timer.doAfter(15,function() if W.worker:isRunning() then W.worker:terminate();M.completed(false,'응답 시간이 초과됐습니다. 적용 결과를 확인하세요.') end end)
 end
 function W.run(id,ctx)
  if id=='table:template' then W.templates(ctx)
  elseif id:match('^template:') then M.office.table(ctx,{action='template',template=id:sub(10)},'새 표 양식을 추가했습니다. 기존 표는 유지합니다.')
  elseif id:match('^extra:') then
   local p=M.profiles[ctx.kind].extra[tonumber(id:match('%d+$'))]
   if p then M.applyPreset(ctx,nil,p) end
  elseif id:match('^table:style:') then
   local n=tonumber(id:match('%d+$'));local p=M.profiles.tableStyles[n];local label=M.profiles[ctx.kind].tableNames[n]
   if p then M.office.table(ctx,{action='preset',preset=p,size=ctx.kind=='keynote' and 24 or 12},label..' 표 서식 · 선택 첫 행을 머리글로 표시') end
  elseif id:match('^number:') then
   M.office.table(ctx,{action='format',value=id:sub(8)},'선택 셀 표시 형식 적용 · 값과 수식 유지')
  elseif id:match('^chart:style:') then W.chartStyle(ctx,tonumber(id:match('%d+$')))
  elseif id:match('^chart:new:') then
   W.insertChart(ctx,id:sub(11))
  else worker(ctx,id) end
 end
 function W.insertChart(ctx,kind)
  local labels={bar={'2D 세로형 막대','2D Column'},line={'2D 꺾은선','2D Line'},pie={'2D 원형','2D Pie'}}
  local choice=labels[kind];if not choice then return end
  local paths={{'삽입','차트',choice[1]},{'Insert','Chart',choice[2]}}
  for _,path in ipairs(paths) do
   local item=ctx.app:findMenuItem(path)
   if item and item.enabled then local ok=ctx.app:selectMenuItem(path);M.completed(ok~=nil,ok and '편집 가능한 차트 생성 · 데이터와 제목을 확인하세요.' or '차트를 추가하지 못했습니다.');return end
  end
  M.completed(false,'차트 종류 메뉴를 확인하지 못했습니다.')
 end
 local function find(e,pred,depth)
  if not e or (depth or 0)>22 then return nil end
  if pred(e) then return e end
  for _,c in ipairs(e:attributeValue('AXChildren') or {}) do local r=find(c,pred,(depth or 0)+1);if r then return r end end
 end
 function W.nativeResize(ctx,action,objects)
  if #objects~=1 or #(ctx.mediaElements or {})~=1 then M.completed(false,'크기를 바꿀 차트 하나를 선택하세요.');return end
  local original=objects[1];local width=action:match(':wide$') and 720 or 360;local height=original.height*width/original.width
  local element=ctx.mediaElements[1];local root=hs.axuielement.windowElement(ctx.window)
  local function active() local a=hs.application.frontmostApplication();return a and a:pid()==ctx.pid and ctx.app:focusedWindow() and ctx.app:focusedWindow():id()==ctx.window:id() and element:isValid() end
  local function radio(name) return find(root,function(e)return e:attributeValue('AXRole')=='AXRadioButton' and e:attributeValue('AXDescription')==name end) end
  M.busy=true;element:setAttributeValue('AXSelected',true)
  local format=radio('포맷');if format and format:attributeValue('AXValue')~=1 then format:performAction('AXPress') end
  W.resizeTimer=hs.timer.doAfter(.2,function()
   if not active() then M.completed(false,'대상 문서로 돌아가 다시 실행하세요.');return end
   local arrange=radio('정렬');if not arrange then M.completed(false,'대상체 정렬 설정을 찾지 못했습니다.');return end
   arrange:performAction('AXPress')
   W.resizeTimer=hs.timer.doAfter(.2,function()
    if not active() then M.completed(false,'대상 문서로 돌아가 다시 실행하세요.');return end
    local function field(name)
     return find(root,function(e)
      if e:attributeValue('AXRole')~='AXTextField' or e:attributeValue('AXEnabled')==false then return false end
      local label=e:attributeValue('AXTitleUIElement');local title=label and (label:attributeValue('AXValue') or label:attributeValue('AXTitle'))
      return e:attributeValue('AXDescription')==name or title==name or (e:attributeValue('AXHelp') or ''):find(name,1,true)~=nil
     end)
    end
    local w,h=field('너비'),field('높이')
    if not w or not h or not w:isAttributeSettable('AXValue') or not h:isAttributeSettable('AXValue') then M.completed(false,'차트의 크기 입력칸을 확인하지 못했습니다.');return end
    w:setAttributeValue('AXFocused',true);w:setAttributeValue('AXValue',width..'pt');w:performAction('AXConfirm')
    h:setAttributeValue('AXFocused',true);h:setAttributeValue('AXValue',string.format('%.3fpt',height));h:performAction('AXConfirm')
    W.resizeTimer=hs.timer.doAfter(.2,function()
     if not active() then M.completed(false,'적용 결과를 문서에서 확인해 주세요.');return end
     local help=(element:attributeValue('AXHelp') or ''):gsub(',(%d%d%d)','%1');local actualW=tonumber(help:match('너비 ([%d%.%-]+)포인트'));local actualH=tonumber(help:match('높이 ([%d%.%-]+)포인트'))
     local ok=actualW and actualH and math.abs(actualW-width)<.2 and math.abs(actualH-height)<.2
     W.lastMedia={objects={{type='chart',width=actualW,height=actualH}},inspector=true};restoreMedia(ctx)
     M.completed(ok==true,ok and '선택한 차트 크기 적용 · 비율 유지' or '차트가 크기를 제한했습니다. 적용 크기를 확인하세요.')
    end)
   end)
  end)
 end
 function W.chartStyle(ctx,index)
  local function active() local a=hs.application.frontmostApplication();local w=ctx.app:focusedWindow();return a and a:pid()==ctx.pid and w and w:id()==ctx.window:id() end
  M.busy=true
  local root=hs.axuielement.windowElement(ctx.window)
  local function radio(description)
   return find(root,function(e) return e:attributeValue('AXRole')=='AXRadioButton' and e:attributeValue('AXDescription')==description end)
  end
  local format=radio('포맷');if format and format:attributeValue('AXValue')~=1 then format:performAction('AXPress') end
  W.styleTimer=hs.timer.doAfter(0.2,function()
   if not active() then M.completed(false,'대상 문서로 돌아오세요.');return end
   local chart=radio('차트');if chart and chart:attributeValue('AXValue')~=1 then chart:performAction('AXPress') end
   W.styleTimer=hs.timer.doAfter(0.2,function()
    if not active() then M.completed(false,'대상 문서로 돌아오세요.');return end
    local group=find(root,function(e)
     if e:attributeValue('AXRole')~='AXRadioGroup' then return false end
     for _,b in ipairs(e:attributeValue('AXChildren') or {}) do local d=b:attributeValue('AXDescription') or '';if b:attributeValue('AXRole')=='AXButton' and (d:find('시리즈 1',1,true)==1 or d:find('Series 1',1,true)==1) then return true end end
     return false
    end)
    if not group then M.completed(false,'서식을 바꿀 차트를 먼저 선택하세요.');return end
    local buttons={};for _,e in ipairs(group:attributeValue('AXChildren') or {}) do if e:attributeValue('AXRole')=='AXButton' then buttons[#buttons+1]=e end end
    if not buttons[index] then M.completed(false,'이 차트의 스타일 프리셋을 확인하지 못했습니다.');return end
    local applied=buttons[index]:performAction('AXPress');if not applied then M.completed(false,'차트 스타일 버튼을 실행하지 못했습니다.');return end;W.lastChartStyle={index=index,description=buttons[index]:attributeValue('AXDescription') or buttons[index]:attributeValue('AXTitle')}
    M.completed(true,'차트 스타일 '..index..' 적용 · 차트 데이터 유지')
   end)
  end)
 end
 function W.templates(ctx)
  local options={pages={{'report','보고서'},{'comparison','비교표'},{'schedule','일정표'}},numbers={{'checklist','명단·체크리스트'},{'budget','예산·정산'},{'assessment','평가 기록'}},keynote={{'comparison','비교표'},{'metrics','핵심 지표'},{'steps','3단계 실습'}}}
  local choices={};for _,v in ipairs(options[ctx.kind]) do choices[#choices+1]={text=v[2],subText='편집 가능한 새 표로 추가',id='template:'..v[1]} end
  W.chooser=hs.chooser.new(function(c) if c then M.run(c.id,ctx) end end):choices(choices):placeholderText('새로 넣을 표 양식'):width(36):rows(4):show();hs.focus()
 end
 function W.symbols(ctx)
  if not ctx then return end
  local choices={};for _,v in ipairs({'□','■','○','●','※','★','✓','①','②','③','④','⑤','←','→','↑','↓','↔','「','」','㎡','℃','±','×','÷','≤','≥','≠'}) do choices[#choices+1]={text=v,id='symbol:'..v} end
  W.chooser=hs.chooser.new(function(c) if c then M.run(c.id,ctx) end end):choices(choices):placeholderText('넣을 기호 선택'):width(24):rows(9):show();hs.focus()
 end
 function W.editPresets(kind)
  kind=kind or (M.capture() and M.capture().kind) or 'pages'
  local options={}
  for i,p in ipairs(M.settings[kind]) do options[#options+1]={text=p.name,subText='빠른 프리셋 '..i,index=i,extra=false} end
  for i,p in ipairs(M.profiles[kind].extra) do options[#options+1]={text=p.name,subText='추가 프리셋',index=i,extra=true} end
  W.chooser=hs.chooser.new(function(c)
   if not c then return end
   local p=c.extra and M.profiles[kind].extra[c.index] or M.settings[kind][c.index]
   local fields={{'name','이름'},{'size','글자 크기'},{'bold','굵기'},{'align','정렬'}}
   if kind=='numbers' then fields[#fields+1]={'color','글자색 #RRGGBB'};fields[#fields+1]={'background','배경색 #RRGGBB'} end
   local choices={};for _,v in ipairs(fields) do choices[#choices+1]={text=v[2],subText=tostring(p[v[1]] or '유지'),field=v[1]} end
   W.properties=hs.chooser.new(function(f)
    if not f then return end
    local hints={name='프리셋 이름',size=kind=='freeform' and '10, 12, 14, 18, 24, 36, 48, 64, 72, 96, 144 중 하나' or '6~200 사이의 pt 값',bold='굵게 또는 보통',align='왼쪽, 가운데, 오른쪽 중 하나',color='#RRGGBB 형식. 예: #005A9E',background='#RRGGBB 형식. 예: #E5F1FB'}
    local current=f.field=='bold' and (p.bold and '굵게' or '보통') or f.field=='align' and ({left='왼쪽',center='가운데',right='오른쪽'})[p.align] or tostring(p[f.field] or '#FFFFFF')
    local button,value=hs.dialog.textPrompt(p.name..' · '..f.text,hints[f.field],current,'저장','취소')
    if button~='저장' then return end
    value=value:match('^%s*(.-)%s*$')
    if f.field=='size' then value=tonumber(value);if not value or value<6 or value>200 then M.completed(false,'6~200 사이의 크기를 입력하세요.');return end
    elseif f.field=='bold' then if value~='굵게' and value~='보통' then M.completed(false,'굵게 또는 보통을 입력하세요.');return end;value=value=='굵게'
    elseif f.field=='align' then value=({['왼쪽']='left',['가운데']='center',['오른쪽']='right'})[value];if not value then M.completed(false,'정렬을 확인하세요.');return end
    elseif f.field=='color' or f.field=='background' then if not value:match('^#%x%x%x%x%x%x$') then M.completed(false,'#RRGGBB 형식을 입력하세요.');return end
    elseif #value==0 or #value>100 then M.completed(false,'이름을 확인하세요.');return end
    if kind=='freeform' and f.field=='size' and not M.freeform.sizes[value] then M.completed(false,'Freeform 크기 목록에서 선택하세요.');return end
    p[f.field]=value
    local saved;if c.extra then saved=hs.json.write(M.profiles,M.root..'/user-profiles.json',true,true) else saved=M.saveSettings() end
    M.completed(saved,saved and '프리셋 저장 · 다음 클릭부터 적용' or '설정을 저장하지 못했습니다.')
    if M.panel then M.panel.render() end
   end):choices(choices):placeholderText('바꿀 항목을 고르세요'):width(36):rows(6):show();hs.focus()
  end):choices(options):placeholderText(kind..' · 프리셋 설정'):width(40):rows(8):show();hs.focus()
 end
 function W.stop()
  if W.resizeTimer then W.resizeTimer:stop() end
  if W.styleTimer then W.styleTimer:stop() end
  if W.chooser then W.chooser:delete() end
  if W.properties then W.properties:delete() end
  if W.timeout then W.timeout:stop() end
  if W.worker and W.worker:isRunning() then W.worker:terminate() end
 end
 return W
end
