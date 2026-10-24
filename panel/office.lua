-- 공문서 도구. 문서 내용은 로컬 메모리에서만 다루며 기록하거나 외부로 보내지 않습니다.
return function(M)
 local O={timers={}}
 local function later(fn,delay)
  for i=#O.timers,1,-1 do if not O.timers[i]:running() then table.remove(O.timers,i) end end
  local t=hs.timer.doAfter(delay or 0.15,fn);O.timers[#O.timers+1]=t;return t
 end
 local function guard(ctx)
  local a=hs.application.frontmostApplication()
  return ctx and ctx.app:isRunning() and a and a:pid()==ctx.pid and ctx.window and ctx.app:focusedWindow() and ctx.app:focusedWindow():id()==ctx.window:id()
 end
 local function find(e,predicate,depth)
  depth=depth or 0;if not e or depth>18 then return end
  if predicate(e) then return e end
  for _,c in ipairs(e:attributeValue("AXChildren") or {}) do local r=find(c,predicate,depth+1);if r then return r end end
 end
 local function root(ctx) return hs.axuielement.windowElement(ctx.window) end
 local function attr(e,k) return e and e:attributeValue(k) end
 local function label(e) local x=attr(e,"AXTitleUIElement");return x and (attr(x,"AXValue") or attr(x,"AXTitle")) end
 local function field(ctx,help) return find(root(ctx),function(e) return attr(e,"AXRole")=="AXTextField" and attr(e,"AXHelp")==help end) end
 local function radio(ctx,description,toolbar)
  return find(root(ctx),function(e) return attr(e,"AXRole")=="AXRadioButton" and attr(e,"AXDescription")==description and (not toolbar or (attr(e,"AXHelp") or ""):find("가립니다",1,true)) end)
 end
 local function press(e) if not e or attr(e,"AXEnabled")==false then return false end;e:performAction("AXPress");return true end
 local function setField(e,value)
  if not e or attr(e,"AXEnabled")==false or not e:isAttributeSettable("AXValue") then return false end
  e:setAttributeValue("AXFocused",true);e:setAttributeValue("AXValue",tostring(value));e:performAction("AXConfirm");return true
 end
 local function number(e) return tonumber(tostring(attr(e,"AXValue") or ""):match("([%-%d%.]+)")) end
 local function restore(ctx)
  return guard(ctx) and M.restoreSelection(ctx)
 end
 local function finish(ctx,ok,message) restore(ctx);M.completed(ok,message) end
 local function ready(ctx,query,done,message)
  local deadline=hs.timer.secondsSinceEpoch()+2.5
  local function poll()
   if not guard(ctx) then M.completed(false,"대상 문서로 돌아가 다시 실행하세요.");return end
   local value=query()
   if value then done(value)
   elseif hs.timer.secondsSinceEpoch()>deadline then finish(ctx,false,message)
   else later(poll,0.1) end
  end
  poll()
 end
 local function formatInspector(ctx,done)
  if not guard(ctx) then done(false);return end
  local f=radio(ctx,"포맷",true)
  if not f then done(false);return end
  if attr(f,"AXValue")~=1 then press(f) end
  later(function()
   if not guard(ctx) then done(false);return end
   local t=radio(ctx,"텍스트")
   if t and attr(t,"AXValue")~=1 then press(t) end
   later(function() done(guard(ctx)) end)
  end)
 end
 function O.prepareSpacing(ctx,done)
  formatInspector(ctx,function(ok)
   if not ok then done(false,"텍스트 서식 사이드바를 찾지 못했습니다.");return end
   local triangle=find(root(ctx),function(e) return attr(e,"AXRole")=="AXDisclosureTriangle" and label(e)=="간격" end)
   if triangle and attr(triangle,"AXValue")~=1 then press(triangle) end
   later(function()
    if not guard(ctx) then done(false,"대상 문서가 바뀌었습니다.");return end
    local fields={before=field(ctx,"단락 앞의 간격을 설정합니다."),after=field(ctx,"단락 뒤의 간격을 설정합니다."),line=field(ctx,"텍스트 줄 사이 간격을 설정합니다.")}
    local unit=find(root(ctx),function(e) return attr(e,"AXRole")=="AXPopUpButton" and attr(e,"AXDescription")=="선 간격" end)
    for _,e in pairs(fields) do if not e or attr(e,"AXEnabled")==false or not e:isAttributeSettable("AXValue") then done(false,"단락 간격을 조절할 수 있는 글을 선택하세요.");return end end
    if not fields.before or not fields.after or not fields.line or not unit then done(false,"단락 서식을 지원하는 글자를 선택하세요.");return end
    local function readyFields()
     fields.before=field(ctx,"단락 앞의 간격을 설정합니다.");fields.after=field(ctx,"단락 뒤의 간격을 설정합니다.");fields.line=field(ctx,"텍스트 줄 사이 간격을 설정합니다.")
     if attr(unit,"AXValue")~="줄" then done(false,"줄 간격 단위를 확인하지 못했습니다.");return end
     done(true,fields)
    end
    if attr(unit,"AXValue")=="줄" then readyFields();return end
    press(unit)
    later(function()
     local item=find(unit,function(e) return attr(e,"AXRole")=="AXMenuItem" and (attr(e,"AXTitle")=="줄" or attr(e,"AXDescription")=="줄") end)
     if not press(item) then hs.eventtap.keyStroke({},"escape",0,ctx.app);done(false,"줄 간격 단위를 바꾸지 못했습니다.");return end
     later(readyFields)
    end)
   end)
  end)
 end
 function O.spacing(ctx,p,done)
  O.prepareSpacing(ctx,function(ok,fields)
   if not ok then done(false,fields);return end
   local a,b,c=p.before or 0,p.after or 6,p.line or 1.3
   local changed=setField(fields.before,a.."pt") and setField(fields.after,b.."pt") and setField(fields.line,c)
   later(function()
    local verified=changed and guard(ctx) and math.abs((number(fields.before) or -1)-a)<0.01 and math.abs((number(fields.after) or -1)-b)<0.01 and math.abs((number(fields.line) or -1)-c)<0.01
    done(verified,verified and nil or "단락 간격의 적용 결과를 확인해 주세요.")
   end)
  end)
 end
 function O.applyStyle(ctx,p)
  if ctx.kind=="numbers" then M.completed(false,"셀 서식을 선택하세요.");return end
  M.busy=true
  O.prepareSpacing(ctx,function(ready,message)
   if not ready then M.completed(false,message);return end
   if not restore(ctx) then M.completed(false,"선택 영역을 복원하지 못했습니다.");return end
   M.setSize(ctx,p.size,function(ok,message)
    if not ok then M.completed(false,message);return end
    if not restore(ctx) then M.completed(false,"선택 영역을 복원하지 못했습니다.");return end
    local b=M.ensureBold(ctx,p.bold);local a=M.executeMenu(ctx,p.align,true)
    if not b or not a then M.completed(false,"크기는 적용됐으나 굵기·정렬을 확인해 주세요.");return end
    O.spacing(ctx,p,function(s,msg) finish(ctx,s,s and (p.name.." 적용 · 문구 유지") or (msg or "단락 간격을 확인해 주세요.")) end)
   end)
  end)
 end
 function O.paper(ctx)
  if ctx.kind~="pages" then M.completed(false,"여섯 여백 설정은 Pages 문서에서 사용하세요.");return end
  M.busy=true
  local d=radio(ctx,"문서",true)
  if not d then M.completed(false,"문서 설정 버튼을 찾지 못했습니다.");return end
  if attr(d,"AXValue")~=1 then press(d) end
  later(function()
   if not guard(ctx) then M.completed(false,"대상 문서가 바뀌었습니다.");return end
   local tab=radio(ctx,"문서");if tab and attr(tab,"AXValue")~=1 then press(tab) end
   later(function()
    local p=M.settings.office.paper
    local entries={{"header","머리말과 페이지 상단 사이의 간격을 설정합니다."},{"top","상단 여백을 설정합니다."},{"bottom","하단 여백을 설정합니다."},{"footer","꼬리말과 페이지 하단 사이의 간격을 설정합니다."},{"left","왼쪽 여백을 설정합니다."},{"right","오른쪽 여백을 설정합니다."}}
    local inputs={}
    for _,e in ipairs(entries) do local f=field(ctx,e[2]);if not f or attr(f,"AXEnabled")==false then finish(ctx,false,"머리말·꼬리말을 켠 일반 문서에서 사용하세요. 페이지 마주보기는 해제해 주세요.");return end;inputs[e[1]]=f end
    local function verify()
     local ok=guard(ctx);local result={}
     for _,e in ipairs(entries) do
      local value=tostring(attr(inputs[e[1]],"AXValue") or "");local n=number(inputs[e[1]])
      local mm=n and (value:find("cm",1,true) and n*10 or value:find("mm",1,true) and n or value:find("in",1,true) and n*25.4 or nil)
      result[e[1]]=mm;ok=ok and mm~=nil and math.abs(mm-p[e[1]])<0.2
     end
     O.lastPaper=result
     finish(ctx,ok,ok and "여백 10·15·10·15·20·20mm 적용" or "일부 여백이 자동 조정됐습니다. 문서 설정 값을 확인해 주세요.")
    end
    local index=1
    local function applyNext()
     if not guard(ctx) then M.completed(false,"대상 문서가 바뀌었습니다.");return end
     local entry=entries[index]
     if not entry then later(verify,0.25);return end
     local f=field(ctx,entry[2]);local current=tostring(attr(f,"AXValue") or "");local mm=p[entry[1]]
     local value=current:find("cm",1,true) and (mm/10).."cm" or current:find("mm",1,true) and mm.."mm" or current:find("in",1,true) and (mm/25.4).."in"
     if not value or not setField(f,value) then finish(ctx,false,"여백 단위 또는 입력을 확인하지 못했습니다.");return end
     index=index+1;later(applyNext)
    end
    applyNext()
   end)
  end)
 end
 local function utf16count(s)
  local n=0;for _,c in utf8.codes(s) do n=n+(c>0xFFFF and 2 or 1) end;return n
 end
 local function slice(s,location,length)
  local n=0;local first,last
  for byte,c in utf8.codes(s) do
   if n==location then first=byte end
   if n==location+length then last=byte;break end
   n=n+(c>0xFFFF and 2 or 1)
  end
  if n==location and not first then first=#s+1 end
  if n==location+length and not last then last=#s+1 end
  if not first or not last then return end
  return s:sub(first,last-1),first,last
 end
 function O.cleanEnters(ctx)
  local snap=ctx.selectionSnapshot
  if not snap or snap.range.length==0 then M.completed(false,"정리할 글자를 드래그해서 선택하세요.");return end
  local full=attr(snap.element,"AXValue")
  if type(full)~="string" then M.completed(false,"선택 글자를 읽지 못했습니다.");return end
  local text,first,last=slice(full,snap.range.location,snap.range.length)
  if not text or snap.range.length>1500 then M.completed(false,"1,500자 이하의 글자를 선택하세요.");return end
  local edits={};local removed=0
  for begin,run,ending in text:gmatch("()\n([ \t\n]*)\n()") do
   if run:find("\n",1,true) then
    local location=snap.range.location+utf16count(text:sub(1,begin))
    local length=utf16count(run)
    edits[#edits+1]={location=location,length=length};removed=removed+length
   end
  end
  if #edits==0 then M.completed(true,"줄일 연속 빈 줄이 없습니다.");return end
  M.busy=true
  local index=#edits;local expected=full
  local function step()
   if not guard(ctx) or not snap.element:isValid() or attr(snap.element,"AXValue")~=expected then M.completed(false,"문서나 선택 내용이 바뀌어 엔터 정리를 멈췄습니다.");return end
   local e=edits[index];local _,a,b=slice(expected,e.location,e.length)
   if not a then M.completed(false,"줄바꿈 위치를 확인하지 못했습니다.");return end
   expected=expected:sub(1,a-1)..expected:sub(b)
   snap.element:setAttributeValue("AXFocused",true);snap.element:setAttributeValue("AXSelectedTextRange",{location=e.location,length=e.length})
   local actual=attr(snap.element,"AXSelectedTextRange")
   if not actual or actual.location~=e.location or actual.length~=e.length then M.completed(false,"줄바꿈 선택을 확인하지 못했습니다.");return end
   hs.eventtap.keyStroke({},"delete",0,ctx.app)
   later(function()
    if not guard(ctx) or attr(snap.element,"AXValue")~=expected then M.completed(false,"일부 빈 줄의 삭제 결과를 확인하지 못했습니다.");return end
    index=index-1
    if index>0 then step() else snap.range.length=snap.range.length-removed;finish(ctx,true,"연속된 빈 줄을 한 줄로 정리했습니다.") end
   end,0.08)
  end
  step()
 end
 function O.insert(ctx,text)
  if ctx.focusRole~="AXTextArea" or (ctx.wholeTextItem and not ctx.selectionSnapshot) then M.completed(false,"글자를 넣을 위치에 커서를 놓거나 글자를 선택하세요.");return end
  if not restore(ctx) then M.completed(false,"선택을 복원하지 못했습니다.");return end
  local snap=ctx.selectionSnapshot or ctx.insertionSnapshot
  local e=snap and snap.element or ctx.focus
  local before=attr(e,"AXValue");local range=snap and snap.range or attr(e,"AXSelectedTextRange")
  if type(before)~="string" or not range then M.completed(false,"입력 위치를 확인하지 못했습니다.");return end
  local _,a,b=slice(before,range.location,range.length)
  if not a then M.completed(false,"입력할 글자 위치를 확인하지 못했습니다.");return end
  local expected=before:sub(1,a-1)..text..before:sub(b)
  M.busy=true;hs.eventtap.keyStrokes(text,ctx.app)
  later(function()
   if not guard(ctx) or attr(e,"AXValue")~=expected then M.completed(false,"문자 입력 결과를 확인해 주세요.");return end
   ctx.selectionSnapshot=nil
   ctx.insertionSnapshot={element=e,range={location=range.location+utf16count(text),length=0}}
   finish(ctx,true,"문자를 넣었습니다.")
  end)
 end
 function O.table(ctx,request,message)
  if request.action~="create" and request.action~="template" and not ctx.tableFocused and not M.cellsSelected(ctx) then M.completed(false,"표 안의 셀 범위를 먼저 선택하세요.");return end
  request.id=ctx.app:bundleID();request.window=ctx.window:title();request.tableTitle=ctx.tableTitle
  M.busy=true
  O.worker=hs.task.new("/usr/bin/osascript",function(code,out,err)
   if O.timeout then O.timeout:stop() end
   O.lastTable=code==0 and hs.json.decode(out) or nil
   M.completed(code==0,code==0 and message or (err:match("Error: ([^\n]+)") or "표 작업을 완료하지 못했습니다."))
  end,{"-l","JavaScript",M.root.."/table-tools.js",hs.json.encode(request)}):start()
  O.timeout=later(function() if O.worker:isRunning() then O.worker:terminate();M.completed(false,"표 작업의 응답 시간이 초과됐습니다. 적용 상태를 확인하세요.") end end,15)
 end
 function O.handles(id) return id=="cleanup" or id=="paper" or id=="cleanEnters" or id=="today" or id:match("^office:") or id:match("^symbol:") or id:match("^table:") end
 function O.run(id,ctx)
  if not guard(ctx) then M.completed(false,"대상 문서로 돌아가 다시 실행하세요.");return end
  if id=="paper" then O.paper(ctx)
  elseif id=="cleanup" then
   local p=M.profiles[ctx.kind].cleanup
   if ctx.tableFocused or M.cellsSelected(ctx) then O.table(ctx,{action="cleanup",size=p.size},"셀 정리 · 숫자는 오른쪽 · 값과 수식 유지") else O.applyStyle(ctx,p) end
  elseif id=="cleanEnters" then O.cleanEnters(ctx)
  elseif id=="today" then O.insert(ctx,os.date("%Y")..". "..tonumber(os.date("%m"))..". "..tonumber(os.date("%d"))..".")
  elseif id:match("^office:") then O.applyStyle(ctx,M.settings.office.styles[tonumber(id:match("%d+$"))])
  elseif id:match("^symbol:") then O.insert(ctx,id:sub(8))
  elseif id=="table:create" then
   local b,t=hs.dialog.textPrompt("표 만들기","행, 열을 입력하세요. 예: 4, 3\n행 1~100, 열 1~20","4, 3","만들기","취소")
   if b~="만들기" then return end
   local r,c=t:match("^%s*(%d+)%s*,%s*(%d+)%s*$");r,c=tonumber(r),tonumber(c)
   if not r or not c or r<1 or r>100 or c<1 or c>20 then M.completed(false,"행 1~100, 열 1~20을 ‘4, 3’처럼 입력하세요.");return end
   ctx.app:activate();ctx.window:focus();later(function() if guard(ctx) then restore(ctx);O.table(ctx,{action="create",rows=r,columns=c},"편집 가능한 새 표를 만들었습니다.") end end)
  elseif id:match("^table:fill:") then O.table(ctx,{action="fill",color=id:sub(12)},"선택 셀의 배경색 적용")
  elseif id:match("^table:align:") then O.table(ctx,{action="align",value=id:sub(13)},"선택 셀 가로 맞춤 적용")
  elseif id=="table:middle" then O.table(ctx,{action="vertical",value="center"},"선택 셀 세로 가운데 맞춤")
  elseif id=="table:oneLine" or id=="table:wrap" then O.table(ctx,{action="wrap",value=id=="table:wrap"},id=="table:wrap" and "셀 줄바꿈 켬" or "셀 줄바꿈 끔 · 기존 줄바꿈 문자는 유지")
  elseif id=="table:equalRows" or id=="table:equalColumns" then O.table(ctx,{action=id:sub(7)},"선택 행·열의 크기를 균등하게 맞췄습니다.")
  elseif id=="table:merge" or id=="table:unmerge" then O.table(ctx,{action=id:sub(7)},id=="table:merge" and "셀 병합 적용" or "셀 병합 해제 적용")
  elseif id:match("^table:border:") then O.border(ctx,id:sub(14))
  elseif id=="table:borders" then O.borderInspector(ctx)
  end
 end
 function O.borderInspector(ctx,done)
  if not ctx.tableFocused and not M.cellsSelected(ctx) then M.completed(false,"표 안의 셀을 먼저 선택하세요.");return end
  local f=radio(ctx,"포맷",true);if f and attr(f,"AXValue")~=1 then press(f) end
  later(function()
   if not guard(ctx) then M.completed(false,"대상 문서가 바뀌었습니다.");return end
   local cell=radio(ctx,"셀")
   if cell then
    if attr(cell,"AXValue")~=1 then press(cell) end
    if done then later(done) else M.completed(true,"셀 테두리 설정을 열었습니다.") end
   else M.completed(false,"셀 설정 탭을 찾지 못했습니다.") end
  end)
 end
 function O.border(ctx,mode)
  local names={all="전체선",outside="바깥선",none="선 없음"}
  if not names[mode] or (not ctx.tableFocused and not M.cellsSelected(ctx)) then M.completed(false,"표 안의 셀 범위를 먼저 선택하세요.");return end
  M.busy=true
  O.borderInspector(ctx,function()
   local help=mode=="outside" and "윤곽" or "모든 테두리"
   ready(ctx,function() return find(root(ctx),function(e) return attr(e,"AXRole")=="AXButton" and attr(e,"AXHelp")==help and attr(e,"AXEnabled")~=false end) end,function(scope)
    if not press(scope) then finish(ctx,false,"테두리 범위 선택기를 찾지 못했습니다.");return end
    local function pattern() return find(root(ctx),function(e) return attr(e,"AXRole")=="AXPopUpButton" and attr(e,"AXDescription")=="선 패턴" end) end
    local function width() return find(root(ctx),function(e) return attr(e,"AXRole")=="AXTextField" and attr(e,"AXDescription")=="선 너비" end) end
    ready(ctx,pattern,function(popup)
     if not press(popup) then finish(ctx,false,"테두리 선 패턴을 찾지 못했습니다.");return end
     local wanted=mode=="none" and "테두리 없음" or "단일 선"
     ready(ctx,function() return find(popup,function(e) return attr(e,"AXRole")=="AXMenuItem" and (attr(e,"AXTitle")==wanted or attr(e,"AXDescription")==wanted) end) end,function(item)
      if not press(item) then hs.eventtap.keyStroke({},"escape",0,ctx.app);finish(ctx,false,"테두리 패턴을 선택하지 못했습니다.");return end
      ready(ctx,function()
       local p=pattern();local w=width()
       return attr(p,"AXValue")==wanted and (mode=="none" or (w and attr(w,"AXEnabled")~=false and w:isAttributeSettable("AXValue")))
      end,function()
       if mode~="none" and not setField(width(),"1pt") then finish(ctx,false,"테두리 굵기를 설정하지 못했습니다.");return end
       ready(ctx,function() return attr(pattern(),"AXValue")==wanted and (mode=="none" or math.abs((number(width()) or -1)-1)<0.01) end,function()
        O.lastBorder={scope=mode,pattern=attr(pattern(),"AXValue"),width=number(width())}
        finish(ctx,true,names[mode]..(mode=="none" and " 적용" or " · 1pt 적용"))
       end,"테두리 적용 결과를 확인해 주세요.")
      end,"테두리 굵기 입력칸을 찾지 못했습니다.")
     end,"테두리 패턴 메뉴를 찾지 못했습니다.")
    end,"테두리 선 패턴을 찾지 못했습니다.")
   end,"테두리 범위 선택기를 찾지 못했습니다.")
  end)
 end
 function O.stop()
  for _,t in ipairs(O.timers) do t:stop() end
  if O.worker and O.worker:isRunning() then O.worker:terminate() end
 end
 return O
end
