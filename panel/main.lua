-- 개인용 Hammerspoon 설정. 문서 내용·클립보드는 수집하거나 기록하지 않습니다.
if _G.iWorkEdit and _G.iWorkEdit.stop then _G.iWorkEdit.stop() end
local M={hotkeys={},appKeys={},commands={},conflicts={},enhancedPids={}}
M.root=debug.getinfo(1,"S").source:sub(2):match("^(.*)/[^/]+$")
M.log=hs.logger.new("iWorkEdit","warning")
_G.iWorkEdit=M
local mods={"ctrl","alt"}
local names={pages="Pages",keynote="Keynote",numbers="Numbers",freeform="Freeform"}
local function appInfo(bundle)
 local path=hs.application.pathForBundleID(bundle)
 return path and (hs.plist.read(path.."/Contents/Info.plist") or hs.application.infoForBundleID(bundle)) or nil
end
M.appVariants={};M.appLabels={}
for key,label in pairs(names) do
 local current=key=="freeform" and "com.apple.freeform" or "com.apple."..label;local classic=key=="freeform" and current or "com.apple.iWork."..label
 M.appVariants[key]={current=current,classic=classic,currentInfo=appInfo(current),classicInfo=appInfo(classic)}
end
function M.launchApp(key,classic)
 local variant=M.appVariants[key];if not variant then return false end
 variant.currentInfo=appInfo(variant.current)
 local bundle=classic and variant.classic or (variant.currentInfo and variant.current or variant.classic)
 return hs.application.launchOrFocusByBundleID(bundle)
end
function M.appLabel(ctx)
 if not ctx then return nil end
 if M.appLabels[ctx.pid] then return M.appLabels[ctx.pid] end
 local info=hs.plist.read(ctx.app:path().."/Contents/Info.plist")
 local version=info and info.CFBundleShortVersionString
 local label=names[ctx.kind]..(version and (" · "..version) or "")
 M.appLabels[ctx.pid]=label;return label
end
local function kind(app)
 if not app or app:pid()<1 then return nil end
 local id=app:bundleID() or ""
 if not id:match("^com%.apple%.") then return nil end
 if id=="com.apple.freeform" then return "freeform" end
 if id=="com.apple.Pages" or id=="com.apple.iWork.Pages" then return "pages" end
 if id=="com.apple.Keynote" or id=="com.apple.iWork.Keynote" then return "keynote" end
 if id=="com.apple.Numbers" or id=="com.apple.iWork.Numbers" then return "numbers" end
end
M.kind=kind
local function alert(s) hs.alert.show(s,2.5) end
local function loadSettings()
 local defaults=hs.json.read(M.root.."/defaults.json")
 local customPath=M.root.."/user-settings.json"
 local custom=hs.fs.attributes(customPath) and hs.json.read(customPath) or nil
 if type(custom)=="table" then
  for _,k in ipairs({"pages","keynote","numbers","freeform","shortcuts","office"}) do
   if type(custom[k])=="table" then defaults[k]=custom[k] end
  end
 end
 return defaults
end
M.settings=loadSettings()
M.profiles=hs.json.read(M.root.."/profiles.json")
local profileFile=M.root.."/user-profiles.json"
if hs.fs.attributes(profileFile) then local custom=hs.json.read(profileFile);if type(custom)=="table" then for _,k in ipairs({"pages","numbers","keynote","freeform"}) do if type(custom[k])=="table" and type(custom[k].extra)=="table" then M.profiles[k].extra=custom[k].extra;if type(custom[k].cleanup)=='table' then M.profiles[k].cleanup=custom[k].cleanup end end end end end
local function saveSettings()
 local p=M.root.."/user-settings.json"
 if hs.fs.attributes(p) then
  local f=io.open(p,"rb");local bytes=f:read("*a");f:close()
  local b=io.open(p..".previous","wb");b:write(bytes);b:close()
 end
 return hs.json.write(M.settings,p,true,true)
end
M.saveSettings=saveSettings
local function capture()
 local a=hs.application.frontmostApplication()
 if not kind(a) then return nil end
 if not M.enhancedPids[a:pid()] then
  local ax=hs.axuielement.applicationElement(a)
  if ax:isAttributeSettable("AXEnhancedUserInterface") then ax:setAttributeValue("AXEnhancedUserInterface",true) end
  M.enhancedPids[a:pid()]=ax:attributeValue("AXEnhancedUserInterface")==true
 end
 local window=a:focusedWindow();if not window then return nil end
 return {app=a,pid=a:pid(),kind=kind(a),window=window}
end
M.capture=capture
local function valid(ctx)
 local a=hs.application.frontmostApplication()
 return ctx and ctx.app:isRunning() and a and a:pid()==ctx.pid and ctx.window and ctx.app:focusedWindow() and ctx.app:focusedWindow():id()==ctx.window:id()
end
local function selectedContent(window)
 local tables,objects,texts={},{},{}
 local count=0
 local function scan(e,d)
  count=count+1;if d>24 or count>3000 then return end
  local role=e:attributeValue("AXRole")
  if role=="AXTable" and e:attributeValue("AXSelected")==true then tables[#tables+1]=e
  elseif role=="AXLayoutItem" and e:attributeValue("AXSelected")==true then objects[#objects+1]=e
  elseif role=="AXTextArea" and e:attributeValue("AXSelected")==true then
   local r=e:attributeValue("AXSelectedTextRange");if r and r.length>0 then texts[#texts+1]=e end
  end
  for _,c in ipairs(e:attributeValue("AXChildren") or {}) do scan(c,d+1) end
 end
 scan(hs.axuielement.windowElement(window),0)
 if #tables==1 then return tables[1] end
 if #objects==1 then return objects[1] end
 if #texts==1 then return texts[1] end
end
function M.snapshotSelection(ctx)
 if not ctx then return nil end
 local focus=hs.axuielement.applicationElement(ctx.pid):attributeValue("AXFocusedUIElement")
 if not focus or focus:attributeValue("AXRole")=="AXWindow" then
  local systemFocus=hs.axuielement.systemWideElement():attributeValue("AXFocusedUIElement")
  if systemFocus and systemFocus:pid()==ctx.pid and systemFocus:attributeValue("AXRole")~="AXWindow" then focus=systemFocus end
 end
 if focus and focus:attributeValue("AXRole")=="AXWindow" and ctx.window then focus=selectedContent(ctx.window) or focus end
 ctx.focus=focus;ctx.focusRole=focus and focus:attributeValue("AXRole")
 ctx.selectionCaptured=true;ctx.tableFocused=false
 ctx.selectionSnapshot=nil;ctx.insertionSnapshot=nil;ctx.objectElement=nil;ctx.wholeTextItem=false;ctx.textCaret=false
 local ancestor=focus
 for _=1,8 do
  if not ancestor then break end
  if ancestor:attributeValue("AXRole")=="AXTable" or (ctx.kind=="freeform" and ancestor:attributeValue("AXRole")=="AXLayoutItem" and ancestor:attributeValue("AXDescription")=="표") then
   ctx.tableFocused=true;ctx.tableElement=ancestor;ctx.tableTitle=ancestor:attributeValue("AXTitle");break
  end
  ancestor=ancestor:attributeValue("AXParent")
 end
 if ctx.kind=="freeform" then
  local selected=0
  local function scan(e,d)
   if d>22 then return end
   local role=e:attributeValue('AXRole')
   if (role=='AXLayoutItem' or role=='AXImage') and e:attributeValue('AXSelected')==true then selected=selected+1;return end
   for _,c in ipairs(e:attributeValue('AXChildren') or {}) do scan(c,d+1) end
  end
  scan(hs.axuielement.windowElement(ctx.window),0);ctx.multipleSelection=selected>1
  if ctx.multipleSelection or ctx.tableFocused then return ctx end
  if ctx.focusRole=='AXLayoutItem' then
   for _,c in ipairs(focus:attributeValue('AXChildren') or {}) do
    if c:attributeValue('AXRole')=='AXTextArea' then
     local r=c:attributeValue('AXSelectedTextRange')
     if r and r.length>0 then ctx.focus=c;ctx.focusRole='AXTextArea';ctx.selectionSnapshot={element=c,range=r};return ctx end
    end
   end
  end
 end
 if ctx.focusRole=="AXLayoutItem" then
  for _,c in ipairs(focus:attributeValue("AXChildren") or {}) do
   if c:attributeValue("AXRole")=="AXTextArea" then ctx.objectElement=focus;ctx.wholeTextItem=true;break end
  end
 elseif ctx.focusRole=="AXTextArea" then
  local range=focus:attributeValue("AXSelectedTextRange")
  if range and range.length and range.length>0 then
   ctx.selectionSnapshot={element=focus,range={location=range.location,length=range.length}}
  elseif range and range.length==0 then
   ctx.textCaret=true;ctx.insertionSnapshot={element=focus,range={location=range.location,length=0}}
  end
 end
 return ctx
end
function M.restoreSelection(ctx)
 if not ctx then return false end
 if ctx.kind=="freeform" and ctx.multipleSelection then return true end
 if ctx.objectElement then
  if not ctx.objectElement:isValid() then return false end
  ctx.objectElement:performAction("AXPress")
  if ctx.objectElement:isAttributeSettable("AXFocused") then ctx.objectElement:setAttributeValue("AXFocused",true) end
  return ctx.objectElement:attributeValue("AXSelected")==true
 end
 local snap=ctx.selectionSnapshot or ctx.insertionSnapshot
 if snap then
  if not snap.element:isValid() then return false end
  snap.element:setAttributeValue("AXFocused",true);snap.element:setAttributeValue("AXSelectedTextRange",snap.range)
  local actual=snap.element:attributeValue("AXSelectedTextRange")
  return actual and actual.location==snap.range.location and actual.length==snap.range.length
 end
 -- AXTable에 초점을 강제로 주면 Pages가 셀 선택을 표 전체로 넓힙니다.
 -- 앱 창 활성화만으로 기존 셀 범위를 유지하고, 실행 시 주소를 고정합니다.
 return true
end
local function menuPaths(ko,en) return {ko,en} end
local paths={
 undo=menuPaths({"편집","실행 취소"},{"Edit","Undo"}),
 left=menuPaths({"포맷","텍스트","왼쪽 정렬"},{"Format","Text","Align Left"}),
 center=menuPaths({"포맷","텍스트","가운데 정렬"},{"Format","Text","Center"}),
 right=menuPaths({"포맷","텍스트","오른쪽 정렬"},{"Format","Text","Align Right"}),
 justify=menuPaths({"포맷","텍스트","좌우 정렬"},{"Format","Text","Justify"}),
 bold=menuPaths({"포맷","서체","볼드체"},{"Format","Font","Bold"}),
 underline=menuPaths({"포맷","서체","밑줄체"},{"Format","Font","Underline"}),
 strike=menuPaths({"포맷","서체","취소선"},{"Format","Font","Strikethrough"}),
 grow=menuPaths({"포맷","서체","크게"},{"Format","Font","Bigger"}),
 shrink=menuPaths({"포맷","서체","작게"},{"Format","Font","Smaller"}),
 fonts=menuPaths({"포맷","서체","서체 보기"},{"Format","Font","Show Fonts"}),
 copyStyle=menuPaths({"포맷","스타일 복사하기"},{"Format","Copy Style"}),
 pasteStyle=menuPaths({"포맷","스타일 붙여넣기"},{"Format","Paste Style"}),
 pasteMatch=menuPaths({"편집","붙여넣고 스타일 일치"},{"Edit","Paste and Match Style"}),
 duplicate=menuPaths({"편집","선택 부분 복제"},{"Edit","Duplicate Selection"}),
 group=menuPaths({"정렬","그룹화"},{"Arrange","Group"}),
 ungroup=menuPaths({"정렬","그룹화 해제"},{"Arrange","Ungroup"}),
 front=menuPaths({"정렬","맨 앞으로 가져오기"},{"Arrange","Bring to Front"}),
 back=menuPaths({"정렬","맨 뒤로 보내기"},{"Arrange","Send to Back"}),
 objectLeft=menuPaths({"정렬","대상체 정렬","왼쪽"},{"Arrange","Align Objects","Left"}),
 objectCenter=menuPaths({"정렬","대상체 정렬","가운데"},{"Arrange","Align Objects","Center"}),
 objectMiddle=menuPaths({"정렬","대상체 정렬","중앙"},{"Arrange","Align Objects","Middle"}),
 distributeH=menuPaths({"정렬","대상체 배열","가로 방향"},{"Arrange","Distribute Objects","Horizontally"}),
 distributeV=menuPaths({"정렬","대상체 배열","세로 방향"},{"Arrange","Distribute Objects","Vertically"}),
 textBox=menuPaths({"삽입","텍스트 상자"},{"Insert","Text Box"}),
 rowBelow=menuPaths({"표","아래에 행 추가"},{"Table","Add Row Below"}),
 columnAfter=menuPaths({"표","뒤에 열 추가"},{"Table","Add Column After"}),
 fitRows=menuPaths({"표","콘텐츠에 맞게 행 크기 변경"},{"Table","Resize Rows to Fit Content"}),
 fitColumns=menuPaths({"표","콘텐츠에 맞게 열 크기 변경"},{"Table","Resize Columns to Fit Content"}),
 wrap=menuPaths({"표","텍스트 줄바꿈"},{"Table","Wrap Text"}),
}
table.insert(paths.fonts,{'포맷','서체','서체 가리기'});table.insert(paths.fonts,{'Format','Font','Hide Fonts'})
table.insert(paths.textBox,{"삽입","텍스트"});table.insert(paths.textBox,{"Insert","Text"})
-- Numbers는 머리말·꼬리말 및 여러 셀 선택에 따라 삽입 메뉴 이름을 바꿉니다.
for _,title in ipairs({"아래에 여러 행 추가","아래에 머리말 행 추가","아래에 여러 머리말 행 추가","아래에 꼬리말 행 추가","아래에 여러 꼬리말 행 추가"}) do
 table.insert(paths.rowBelow,{"표",title})
end
for _,title in ipairs({"뒤에 여러 열 추가","뒤에 머리말 열 추가","뒤에 여러 머리말 열 추가"}) do
 table.insert(paths.columnAfter,{"표",title})
end
-- Pages·Keynote는 표 메뉴를 ‘포맷’ 아래에 둡니다.
for _,id in ipairs({"rowBelow","columnAfter","fitRows","fitColumns","wrap"}) do
 local extra={}
 for _,p in ipairs(paths[id]) do
  local nested={p[1]=="표" and "포맷" or "Format"};for _,part in ipairs(p) do nested[#nested+1]=part end
  extra[#extra+1]=nested
 end
 for _,p in ipairs(extra) do paths[id][#paths[id]+1]=p end
end
local function findMenu(app,id)
 local fallback,path
 for _,p in ipairs(paths[id] or {}) do
  local item=app:findMenuItem(p)
  if item then if item.enabled then return item,p end;fallback,path=fallback or item,path or p end
 end
 return fallback,path
end
function M.cellsSelected(ctx)
 if not valid(ctx) then return false end
 local item=findMenu(ctx.app,"rowBelow")
 return item and item.enabled==true or false
end
local function executeMenu(ctx,id,quiet)
 if not valid(ctx) then if not quiet then alert("대상 앱으로 돌아온 뒤 다시 실행하세요.") end;return false end
 local item,p=findMenu(ctx.app,id)
 if not item or not item.enabled then if not quiet then alert("현재 선택에서는 사용할 수 없습니다. 글자·셀·도형을 먼저 선택하세요.") end;return false end
 local ok=ctx.app:selectMenuItem(p)
 if not ok and not quiet then alert("메뉴를 실행하지 못했습니다.") end
 return ok~=nil
end
local function ensureBold(ctx,wanted)
 local item=findMenu(ctx.app,"bold")
 if not item or not item.enabled then return false end
 if (item.ticked==true)~=wanted then return executeMenu(ctx,"bold",true) end
 return true
end
local function setSize(ctx,size,done)
 if not valid(ctx) then done(false,"대상 앱이 바뀌었습니다.");return end
 local payload={id=ctx.app:bundleID(),size=size,window=ctx.window and ctx.window:title() or "",cells=ctx.tableFocused or M.cellsSelected(ctx),tableTitle=ctx.tableTitle}
 if ctx.kind=="numbers" and not payload.cells then done(false,"Numbers 크기 프리셋은 셀 범위에 적용합니다. 글상자는 A+·A− 또는 서체 창을 쓰세요.");return end
 if not ctx.selectionCaptured then M.snapshotSelection(ctx) end
 payload.caret=ctx.textCaret==true
 if ctx.selectionSnapshot then
  local snap=ctx.selectionSnapshot
  local value=snap.element:attributeValue("AXValue")
  if type(value)~="string" then done(false,"선택한 글자를 다시 선택해 주세요.");return end
  payload.range=snap.range;payload.text=value;payload.caret=false
 end
 M.textWorker=hs.task.new("/usr/bin/osascript",function(code,out,err)
  if M.textTimeout then M.textTimeout:stop() end
  if code==0 then done(true) else done(false,err:match("Error: ([^\n]+)") or "글자 크기를 바꾸지 못했습니다. 선택 영역과 자동화 권한을 확인하세요.") end
 end,{"-l","JavaScript",M.root.."/text-size.js"})
 M.textWorker:setInput(hs.json.encode(payload)):start()
 M.textTimeout=hs.timer.doAfter(15,function()
  if M.textWorker:isRunning() then M.textWorker:terminate();done(false,"응답 시간이 초과됐습니다. 적용 상태를 확인해 주세요.") end
 end)
end
M.setSize=setSize
local function completed(ok,message)
 M.busy=false;M.dispatchPending=false;M.resultSequence=(M.resultSequence or 0)+1;M.lastResult={ok=ok,message=message,time=os.date("%Y-%m-%d %H:%M:%S")}
 alert(message)
end
M.completed=completed
M.executeMenu=executeMenu
M.ensureBold=ensureBold
local function applyPreset(ctx,index,custom,attempt)
 local p=custom or M.settings[ctx.kind][index]
 if M.busy then alert("앞선 서식을 적용 중입니다.");return end
 if not p then return end
 if not valid(ctx) then completed(false,"대상 앱을 다시 선택하세요.");return end
 if ctx.tableFocused or M.cellsSelected(ctx) then
  local canCells=findMenu(ctx.app,"rowBelow")
  if not canCells or not canCells.enabled then completed(false,"Esc를 누르고, 서식을 바꿀 셀 범위를 먼저 선택하세요.");return end
  M.busy=true
  local payload=hs.json.encode({id=ctx.app:bundleID(),window=ctx.window:title(),tableTitle=ctx.tableTitle,preset=p})
  M.worker=hs.task.new("/usr/bin/osascript",function(code,out,err)
   if M.workerTimeout then M.workerTimeout:stop() end
   if code~=0 then
    local message=err:match("Error: ([^\n]+)") or "셀을 선택하고 다시 실행하세요. 자동화 권한도 확인해 주세요."
    completed(false,message);return
   end
   local okBold=valid(ctx) and ensureBold(ctx,p.bold)
   completed(okBold,p.name..(okBold and " 적용 · 셀 값과 수식 유지" or " 크기·색·정렬 적용 / 굵기는 확인해 주세요."))
  end,{"-l","JavaScript",M.root.."/cell-preset.js",payload})
  M.worker:start()
  M.workerTimeout=hs.timer.doAfter(15,function()
   if M.worker:isRunning() then M.worker:terminate();completed(false,"응답 시간이 초과됐습니다. 적용 상태를 확인한 뒤 다시 실행하세요.") end
  end)
  return
 end
 local canSize=findMenu(ctx.app,"grow")
 local canBold=findMenu(ctx.app,"bold")
 local canAlign=findMenu(ctx.app,p.align)
 if not canSize or not canSize.enabled or not canBold or not canBold.enabled or not canAlign or not canAlign.enabled then
  if (attempt or 0)<3 then M.dispatchPending=true;M.presetRetry=hs.timer.doAfter(0.2,function() M.dispatchPending=false;applyPreset(ctx,index,custom,(attempt or 0)+1) end);return end
  completed(false,"글자 또는 글이 들어 있는 글상자를 먼저 선택하세요.");return
 end
 M.busy=true
 setSize(ctx,p.size,function(ok,message)
  if not ok then completed(false,message);return end
  if not M.restoreSelection(ctx) then completed(false,"크기는 적용됐으나 선택 복원을 확인하지 못했습니다. 글자를 다시 선택해 주세요.");return end
  local bold=ensureBold(ctx,p.bold)
  local aligned=executeMenu(ctx,p.align,true)
  completed(bold and aligned,p.name..(bold and aligned and " 적용" or " · 일부 서식은 직접 확인해 주세요."))
 end)
end
M.applyPreset=applyPreset
local function add(id,title,sub,scope)
 table.insert(M.commands,{id=id,title=title,sub=sub or "",scope=scope})
end
for _,r in ipairs({
 {"left","텍스트 왼쪽 정렬","⌃⌥L"},{"center","텍스트 가운데 정렬","⌃⌥E"},{"right","텍스트 오른쪽 정렬","⌃⌥R"},
 {"justify","텍스트 양쪽 정렬"},{"bold","굵게 켜기 / 끄기","⌃⌥B"},{"underline","밑줄 켜기 / 끄기"},{"strike","취소선 켜기 / 끄기"},
 {"grow","글자 크게","⌃⌥="},{"shrink","글자 작게","⌃⌥−"},{"fonts","서체 선택창 열기"},
 {"copyStyle","스타일 복사","⌃⌥C"},{"pasteStyle","스타일 붙여넣기","⌃⌥V"},{"pasteMatch","주변 서식에 맞춰 붙여넣기"},
 {"duplicate","선택한 대상 복제"},{"group","대상체 그룹화","⌃⌥G"},{"ungroup","대상체 그룹 해제"},
 {"objectLeft","도형 왼쪽 맞추기"},{"objectCenter","도형 가로 가운데 맞추기"},{"objectMiddle","도형 세로 중앙 맞추기"},
 {"distributeH","도형 가로 간격 같게"},{"distributeV","도형 세로 간격 같게"},{"front","대상체 맨 앞으로"},{"back","대상체 맨 뒤로"},
 {"textBox","텍스트 상자 추가"},{"rowBelow","아래에 행 추가"},{"columnAfter","뒤에 열 추가"},
 {"fitRows","내용에 맞게 행 높이"},{"fitColumns","내용에 맞게 열 너비"},{"wrap","셀 텍스트 줄바꿈"},
}) do add(table.unpack(r)) end
local function restoreThen(ctx,fn)
 if not ctx or not ctx.app:isRunning() then completed(false,"Pages·Keynote·Numbers·Freeform를 먼저 열어 주세요.");return end
 ctx.app:activate();if ctx.window then ctx.window:focus() end
 M.restoreTimer=hs.timer.doAfter(0.15,function()
  if not valid(ctx) then completed(false,"대상 앱을 선택해 다시 실행하세요.");return end
  if not M.restoreSelection(ctx) then completed(false,"선택한 글자를 다시 선택해 주세요.");return end
  fn()
 end)
end
local function run(id,ctx)
 if M.paused then alert("편집 도우미가 일시 중지되었습니다.");return end
 if M.busy or M.dispatchPending then alert("앞선 작업을 마친 뒤 실행해 주세요.");return end
 if valid(ctx) and not ctx.selectionCaptured then M.snapshotSelection(ctx) end
 M.dispatchPending=true;M.lastAction={id=id,kind=ctx and ctx.kind,time=hs.timer.secondsSinceEpoch()}
 restoreThen(ctx,function()
  M.dispatchPending=false
  if id=="undo" then hs.eventtap.keyStroke({"cmd"},"z",0,ctx.app);completed(true,"실행 취소")
  elseif ctx.kind=="freeform" then M.freeform.run(id,ctx)
  elseif M.work and M.work.handles(id) then M.work.run(id,ctx)
  elseif M.office and M.office.handles(id) then M.office.run(id,ctx)
  elseif id:match("^preset:") then applyPreset(ctx,tonumber(id:match("%d+$")))
  elseif id=="customSize" then
   local button,text=hs.dialog.textPrompt("글자 크기","6~200 사이의 pt 값을 입력하세요.","14","적용","취소")
   local size=tonumber(text)
   if button=="적용" and size and size>=6 and size<=200 then
    restoreThen(ctx,function() M.busy=true;setSize(ctx,size,function(ok,msg) completed(ok,ok and (size.."pt 적용") or msg) end) end)
   elseif button=="적용" then alert("6~200 사이의 숫자를 입력하세요.") end
  else
   M.busy=true
   local attempts=0
   local function tryMenu()
    if not valid(ctx) or not ctx.app:focusedWindow() or ctx.app:focusedWindow():id()~=ctx.window:id() then completed(false,"대상 문서로 돌아가 다시 실행하세요.");return end
    attempts=attempts+1;local item=findMenu(ctx.app,id)
    -- 최신판은 앱을 다시 활성화한 직후 메뉴 상태가 늦게 갱신될 수 있습니다.
    -- 메뉴가 켜질 때까지만 재조회하고, 실제 편집 명령은 한 번만 실행합니다.
    if (not item or not item.enabled) and attempts<4 then M.menuTimer=hs.timer.doAfter(0.15,tryMenu);return end
    local ok=executeMenu(ctx,id,true);completed(ok,ok and "편집 명령 적용" or "현재 선택에서는 사용할 수 없습니다.")
   end
   tryMenu()
  end
 end)
end
M.run=run
function M.helpURL(target)
 local ctx=type(target)=="table" and names[target.kind] and target or capture()
 -- 파일 경로에 #을 붙이면 파일명으로 해석되므로, 경로를 file: URL로 변환합니다.
 local path=(M.root.."/사용 안내.html"):gsub("([^A-Za-z0-9%-%._~/])",function(c) return string.format("%%%02X",string.byte(c)) end)
 return "file://"..path..(ctx and names[ctx.kind] and ("#"..ctx.kind) or "")
end
function M.help(target) M.lastHelpURL=M.helpURL(target);M.helpTask=hs.task.new("/usr/bin/open",nil,{M.helpURL(target)}):start() end
function M.show(onlyPresets,target)
 local ctx=target or capture()
 if not ctx then alert("편집할 Pages·Keynote·Numbers·Freeform를 먼저 선택하세요.");return end
 M.snapshotSelection(ctx)
 local choices={}
 for i,p in ipairs(M.settings[ctx.kind]) do
  table.insert(choices,{text=p.name,subText=string.format("프리셋 %d · %gpt · %s · ⌃⌥%d",i,p.size,p.bold and "굵게" or "보통",i),id="preset:"..i})
 end
 for i,p in ipairs(M.profiles[ctx.kind].extra) do
  table.insert(choices,{text=p.name,subText='추가 프리셋 · '..p.size..'pt',id='extra:'..i})
 end
 if not onlyPresets and ctx.kind=="freeform" then
  for _,v in ipairs(M.freeform.commands) do table.insert(choices,{id=v.id,text=v.title,subText="Freeform 보드 도구"}) end
 elseif not onlyPresets then
  table.insert(choices,{text=M.profiles[ctx.kind].cleanup.name,subText='선택한 부분 정리',id='cleanup'})
  for i,p in ipairs(M.profiles.tableStyles) do table.insert(choices,{text='표 · '..M.profiles[ctx.kind].tableNames[i],subText='선택 범위 첫 행 강조',id='table:style:'..i}) end
  table.insert(choices,{text='표 양식 추가',subText='앱별 새 표',id='table:template'})
  for _,v in ipairs({{'image:small','사진 작게'},{'image:medium','사진 중간 크기'},{'image:wide','사진 넓게'},{'image:sameHeight','사진 높이 같게'},{'chart:new:bar','비교 차트 추가'},{'chart:new:line','변화 차트 추가'},{'chart:new:pie','비중 차트 추가'},{'chart:compact','차트 작게'},{'chart:wide','차트 넓게'}}) do table.insert(choices,{id=v[1],text=v[2],subText='미디어 도구'}) end
  table.insert(choices,{text="글자 크기 직접 입력…",subText="예: 14pt, 28pt",id="customSize"})
  for _,c in ipairs(M.commands) do if not c.scope or c.scope==ctx.kind then table.insert(choices,{text=c.title,subText=c.sub,id=c.id}) end end
 end
 M.chooser=hs.chooser.new(function(choice) if choice then run(choice.id,ctx) end end)
 M.chooser:placeholderText(names[ctx.kind].." · 이름을 검색하고 Enter · Esc로 닫기")
 M.chooser:width(42):rows(10):searchSubText(true):choices(choices):show()
 hs.focus()
end
function M.editPresets()
 if M.work then return M.work.editPresets() end
 local choices={}
 for _,k in ipairs({"pages","keynote","numbers"}) do for i,p in ipairs(M.settings[k]) do
  table.insert(choices,{text=names[k].." · "..p.name,subText=p.size.."pt / "..p.align,kind=k,index=i})
 end end
 for i,p in ipairs(M.settings.office.styles) do
  table.insert(choices,{text="공문서 · "..p.name,subText=p.size.."pt / "..p.align,kind="office",index=i})
 end
 M.editor=hs.chooser.new(function(c)
  if not c then return end
  local p=c.kind=="office" and M.settings.office.styles[c.index] or M.settings[c.kind][c.index]
  local example=p.name..", "..p.size..", "..(p.bold and "굵게" or "보통")..", "..({left="왼쪽",center="가운데",right="오른쪽"})[p.align]
  local b,t=hs.dialog.textPrompt("프리셋 수정", "이름, 크기, 굵게/보통, 왼쪽/가운데/오른쪽\n예: 학습지 제목, 24, 굵게, 가운데\n글꼴·줄간격은 현재 서식을 유지합니다.",example,"저장","취소")
  if b~="저장" then return end
  local n,s,w,a=t:match("^%s*([^,]+)%s*,%s*([%d%.]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
  local function trim(x) return x and x:match("^%s*(.-)%s*$") end
  n,w,a=trim(n),trim(w),trim(a);s=tonumber(s)
  local alignment=({['왼쪽']="left",['가운데']="center",['오른쪽']="right"})[a]
  if not n or #n>100 or not s or s<6 or s>200 or (w~="굵게" and w~="보통") or not alignment then alert("입력 형식을 확인해 주세요. 변경하지 않았습니다.");return end
  p.name=n;p.size=s;p.bold=w=="굵게";p.align=alignment
  if saveSettings() then
   if M.panel then M.panel.render() end
   alert("저장했습니다. 다음 실행부터 바로 적용됩니다.")
  else alert("설정을 저장하지 못했습니다.") end
 end)
 M.editor:placeholderText("바꿀 프리셋을 고르세요"):choices(choices):rows(12):show()
 hs.focus()
end
local function bind(key,fn,appOnly)
 if not hs.hotkey.assignable(mods,key) then table.insert(M.conflicts,key);return end
 local h=hs.hotkey.new(mods,key,function() M.lastShortcut={key=key,time=hs.timer.secondsSinceEpoch()};fn() end)
 table.insert(M.hotkeys,h)
 if appOnly then table.insert(M.appKeys,h) else h:enable() end
end
local function updateKeys()
 local yes=capture()~=nil
 for _,h in ipairs(M.appKeys) do if yes then h:enable() else h:disable() end end
end
for _,c in ipairs(M.commands) do
 local key=M.settings.shortcuts[c.id]
 if key then local id=c.id;bind(key,function() run(id,capture()) end,true) end
end
for i=1,4 do local index=i;bind(tostring(i),function() run("preset:"..index,capture()) end,true) end
bind(M.settings.shortcuts.palette,function() M.show(false) end,true)
bind(M.settings.shortcuts.presets,function() M.show(true) end,true)
bind(M.settings.shortcuts.help,M.help,false)
M.watcher=hs.application.watcher.new(function(_,event)
 if event==hs.application.watcher.activated or event==hs.application.watcher.terminated then updateKeys() end
end):start()
M.menu=hs.menubar.new():setTitle("✦ 편집"):setTooltip("iWork 편집 도우미 · ⌃⌥K")
M.menu:setMenu(function()
 local ctx=capture();local k=ctx and ctx.kind
 local menu={{title="클릭 패널 보이기 / 숨기기",checked=M.panel and M.panel.enabled or false,fn=function() if M.panel then M.panel.toggle() end end},
  {title="-"},{title=k and (names[k].." 편집") or "Pages·Keynote·Numbers·Freeform을 선택하세요",disabled=true},
  {title="명령 검색…                 ⌃⌥K",disabled=not ctx,fn=function() M.show(false,ctx) end},
  {title="프리셋 고르기…           ⌃⌥P",disabled=not ctx,fn=function() M.show(true,ctx) end}}
 table.insert(menu,{title="기본 단축키 보기…",fn=function() M.panel.showShortcuts(k) end})
 if k then
  table.insert(menu,{title="-"})
  for i,p in ipairs(M.settings[k]) do local index=i;table.insert(menu,{title=p.name.."   ⌃⌥"..i,fn=function() run("preset:"..index,ctx) end}) end
 end
 table.insert(menu,{title="-"})
 local currentItems,classicItems={},{}
 for _,key in ipairs({"pages","keynote","numbers"}) do
  local variant=M.appVariants[key];local label=names[key]
  local currentInfo,classicInfo=appInfo(variant.current),appInfo(variant.classic)
  if currentInfo then table.insert(currentItems,{title=label.." · "..currentInfo.CFBundleShortVersionString,fn=function() M.launchApp(key) end}) end
  if classicInfo then table.insert(classicItems,{title=label.." · "..classicInfo.CFBundleShortVersionString,fn=function() M.launchApp(key,true) end}) end
 end
 table.insert(menu,{title="최신 앱 열기 · Creator Studio",menu=currentItems})
 if #classicItems>0 then table.insert(menu,{title="이전 일반판 열기",menu=classicItems}) end
 table.insert(menu,{title="Freeform 열기",fn=function() M.launchApp("freeform") end})
 table.insert(menu,{title="프리셋 값 바꾸기…",fn=M.editPresets})
 table.insert(menu,{title="사용 안내·단축키표      ⌃⌥H",fn=M.help})
 table.insert(menu,{title="일시 중지 / 다시 켜기",fn=function()
  M.paused=not M.paused
  if M.paused then for _,h in ipairs(M.appKeys) do h:disable() end;M.menu:setTitle("✦ 편집 ⏸")
  else updateKeys();M.menu:setTitle("✦ 편집") end
 end})
 return menu
end)
local oldUpdate=updateKeys
updateKeys=function() if not M.paused then oldUpdate() end end
updateKeys()
function M.stop()
 if M.panel then M.panel.destroy() end
 for _,h in ipairs(M.hotkeys) do h:delete() end
 if M.office then M.office.stop() end
 if M.work then M.work.stop() end
 if M.freeform then M.freeform.stop() end
 for _,name in ipairs({"presetRetry","watcher","sizeTimer","restoreTimer","menuTimer","workerTimeout","textTimeout"}) do if M[name] then M[name]:stop() end end
 for _,key in ipairs({"worker","textWorker"}) do if M[key] and M[key]:isRunning() then M[key]:terminate() end end
 if M.menu then M.menu:delete() end
 if M.chooser then M.chooser:delete() end
 if M.editor then M.editor:delete() end
end
M.version="2.1.0"
M.office=dofile(M.root.."/office.lua")(M)
M.work=dofile(M.root.."/work.lua")(M)
M.freeform=dofile(M.root.."/freeform.lua")(M)
M.panel=dofile(M.root.."/panel.lua")(M)
return M
