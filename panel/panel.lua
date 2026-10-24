-- 클릭 직전의 iWork 문서로 돌아가 선택한 부분을 편집하는 로컬 패널입니다.
return function(M)
 local P={buttons={},layouts={},baseW=344,baseH=768}
 local C={ink={hex="#1B1B1B"},muted={hex="#545B66"},bg={hex="#F3F5F7"},white={white=1},accent={hex="#005A9E"},button={hex="#FFFFFF"},hover={hex="#E5F1FB"},line={hex="#D5DAE1"},error={hex="#A4262C"},disabled={hex="#ECEFF3"},disabledText={hex="#737A85"}}
 local appNames={pages="Pages",keynote="Keynote",numbers="Numbers",freeform="Freeform"}
 local statePath=M.root.."/panel-state.json"
 local state=hs.json.read(statePath) or {}
 local function context()
  local ctx=M.capture()
  if ctx then P.target=M.snapshotSelection(ctx);return P.target end
  local front=hs.application.frontmostApplication()
  if front and front:bundleID()=="org.hammerspoon.Hammerspoon" and P.target and P.target.app:isRunning() then return P.target end
  P.target=nil;return nil
 end
 local function save()
  local f=P.canvas and P.canvas:frame()
  hs.json.write({visible=P.enabled,frame=f and {x=f.x,y=f.y,w=f.w,h=f.h}},statePath,true,true)
 end
 local function sameFrame(a,b)
  return a and b and math.abs(a.x-b.x)<4 and math.abs(a.y-b.y)<4 and math.abs(a.w-b.w)<4 and math.abs(a.h-b.h)<4
 end
 local function availableScreen(ctx)
  return ctx and ctx.window and ctx.window:screen() or hs.screen.mainScreen()
 end
 local function restoreLayouts()
  for _,r in pairs(P.layouts) do
   local ok,current=pcall(function() return r.window and r.window:frame() end)
   if ok and sameFrame(current,r.applied) then r.window:setFrame(r.original,0) end
  end
  P.layouts={}
 end
 function P.arrange()
  local ctx=context()
  if not ctx or not ctx.window then hs.alert.show("나란히 놓을 iWork 문서를 먼저 선택하세요.");return end
  if ctx.window:isFullScreen() then hs.alert.show("전체 화면을 해제한 뒤 나란히 놓기를 누르세요.");return end
  local id=ctx.window:id();local prior=P.layouts[id]
  if prior and sameFrame(ctx.window:frame(),prior.applied) then
   ctx.window:setFrame(prior.original,0);P.layouts[id]=nil;return
  end
  local f=ctx.window:screen():frame();local pf=P.canvas:frame()
  local target={x=f.x+8,y=f.y+8,w=f.w-pf.w-32,h=f.h-16}
  if target.w<520 then hs.alert.show("이 화면에서는 패널을 끌어서 배치해 주세요.");return end
  P.layouts[id]={window=ctx.window,original=ctx.window:frame(),applied=target}
  ctx.window:setFrame(target,0)
  P.layouts[id].applied=ctx.window:frame()
  P.canvas:topLeft({x=f.x+f.w-pf.w-8,y=f.y+8});save()
 end
 local function geometry()
  local ctx=context();local sf=availableScreen(ctx):frame()
  P.scale=math.min(1,(sf.h-24)/P.baseH)
  local w,h=P.baseW*P.scale,P.baseH*P.scale
  local x,y=sf.x+sf.w-w-12,sf.y+12
  if state.frame then
   local center={x=state.frame.x+w/2,y=state.frame.y+h/2}
   for _,screen in ipairs(hs.screen.allScreens()) do
    local s=screen:frame()
    if center.x>=s.x and center.x<=s.x+s.w and center.y>=s.y and center.y<=s.y+s.h then
     x=math.max(s.x,math.min(state.frame.x,s.x+s.w-w));y=math.max(s.y,math.min(state.frame.y,s.y+s.h-h));break
    end
   end
  end
  return {x=x,y=y,w=w,h=h}
 end
 local function rect(x,y,w,h) local s=P.scale;return {x=x*s,y=y*s,w=w*s,h=h*s} end
 local function append(list,e) table.insert(list,e);return #list end
 local function text(list,label,x,y,w,h,size,color,align)
  append(list,{type="text",text=label,textFont="NotoSansKR-Regular",textSize=size*P.scale,textColor=color or C.ink,textAlignment=align or "left",textLineBreak="truncateTail",frame=rect(x,y,w,h)})
 end
 local function button(list,id,label,x,y,w,h,enabled,sub)
  local bounds=rect(x,y,w,h)
  local index=append(list,{type="rectangle",action="fill",id=id,frame=bounds,roundedRectRadii={xRadius=4*P.scale,yRadius=4*P.scale},fillColor=enabled and C.button or C.disabled,trackMouseUp=enabled,trackMouseDown=enabled,trackMouseEnterExit=enabled})
  P.buttons[id]={frame=bounds,index=index,enabled=enabled,label=label}
  text(list,label,x+4,y+(sub and 4 or 8),w-8,sub and 20 or h-8,w<90 and 11 or 13,enabled and C.ink or C.disabledText,"center")
  if sub then text(list,sub,x+6,y+25,w-12,16,10,enabled and C.muted or C.disabledText,"center") end
 end
 function P.showShortcuts(kind)
  P.tabs=P.tabs or {};P.tabs[P.kind or "none"]="shortcuts";P.shortcutKind=kind or P.kind or "pages";P.show();P.render()
 end
 function P.render()
  if not P.canvas then return end
  local ctx=context();local k=ctx and ctx.kind
  if k and k~=P.kind then P.shortcutKind=k end
  P.kind=k;P.buttons={};P.tabs=P.tabs or {};P.pages=P.pages or {}
  P.tab=P.tabs[k or 'none'] or 'text'
  local enabled=ctx~=nil and not M.paused and not M.busy and not M.dispatchPending and not P.pending
  local idle=not M.busy and not M.dispatchPending and not P.pending
  local cells=ctx and (ctx.tableFocused or M.cellsSelected(ctx)) or false
  local list={}
  append(list,{type='rectangle',action='fill',fillColor=C.bg,roundedRectRadii={xRadius=7,yRadius=7},frame=rect(0,0,P.baseW,P.baseH)})
  append(list,{type='rectangle',action='fill',id='drag',fillColor=C.white,frame=rect(0,0,P.baseW,42),trackMouseDown=true,trackMouseUp=true})
  append(list,{type='rectangle',action='fill',fillColor=C.accent,frame=rect(0,0,4,42)})
  text(list,'iWork + Freeform',16,10,180,22,15,C.ink)
  button(list,'layout','나란히',228,7,62,28,ctx~=nil and idle)
  button(list,'close','×',300,7,28,28,true)
  text(list,ctx and M.appLabel(ctx) or 'iWork 편집 도구',16,54,300,27,20,C.ink)
  local selected=cells and '선택 셀 · 값과 수식 유지' or ctx and (ctx.selectionSnapshot and '선택한 글자 · 문구 유지' or ctx.wholeTextItem and '선택한 글상자' or '글자·셀·대상체를 선택하세요') or 'Pages · Numbers · Keynote · Freeform'
  text(list,M.paused and '일시 중지됨' or selected,16,87,310,22,12,C.muted)
  local cleanup=k and M.profiles[k].cleanup
  button(list,'cleanup',cleanup and cleanup.name or '선택 정리',16,118,208,50,enabled and (k~='numbers' or cells),cleanup and (cleanup.size..'pt · '..(k=='numbers' and '숫자 오른쪽' or '왼쪽 · 문구 유지')) or '앱에 맞는 서식')
  button(list,'undo','되돌리기',232,118,96,50,enabled,'⌘Z')
  text(list,'빠른 도구',16,184,130,20,11,C.muted)
  local nav={{'text',k=='numbers' and '셀' or '글자'},{'table','표'},{'image','그림'},{'chart','차트'},{'tools','도구'},{'shortcuts','단축키'}}
  if k=='freeform' then nav={{'text','글자'},{'board','보드'},{'table','표'},{'image','그림'},{'tools','정렬'},{'shortcuts','단축키'}} end
  for i,item in ipairs(nav) do
   local id='tab:'..item[1];button(list,id,item[2],12,215+(i-1)*58,52,46,idle)
   if P.tab==item[1] then list[P.buttons[id].index].fillColor=C.hover;append(list,{type='rectangle',action='fill',fillColor=C.accent,frame=rect(12,220+(i-1)*58,3,36)}) end
  end
  local rows={}
  local function row(...) rows[#rows+1]={...} end
  local function b(id,label,sub,condition) return {id=id,label=label,sub=sub,enabled=condition} end
  local function pair(items) for i=1,#items,2 do row(items[i],items[i+1]) end end
  if not k and P.tab~='shortcuts' then
   row(b('launch:pages','Pages 열기','문서 · 학습지',true))
   row(b('launch:numbers','Numbers 열기','셀 · 데이터',true))
   row(b('launch:keynote','Keynote 열기','슬라이드 · 발표',true))
   row(b('launch:freeform','Freeform 열기','보드 · 아이디어',true))
   row(b('help','사용 안내','선택 → 클릭 → 적용',true))
  elseif k=='freeform' and P.tab~='shortcuts' then
   for _,r in ipairs(M.freeform.rows(P.tab)) do local items={};for _,v in ipairs(r) do items[#items+1]=b(v[1],v[2],v[3],enabled and M.freeform.available(ctx,v[1])) end;row(table.unpack(items)) end
  elseif P.tab=='text' then
   local items={}
   for i,p in ipairs(M.settings[k]) do items[#items+1]=b('preset:'..i,p.name,p.size..'pt · ⌃⌥'..i,enabled and (k~='numbers' or cells)) end
   for i,p in ipairs(M.profiles[k].extra) do items[#items+1]=b('extra:'..i,p.name,p.size..'pt',enabled and (k~='numbers' or cells)) end
   pair(items)
   row(b('bold','굵게','⌃⌥B',enabled),b('underline','밑줄',nil,enabled),b('strike','취소선',nil,enabled))
   row(b('left','왼쪽',nil,enabled),b('center','가운데',nil,enabled),b('right','오른쪽',nil,enabled))
   row(b('shrink','A−',nil,enabled),b('customSize','크기…',nil,enabled and (k~='numbers' or cells)),b('grow','A+',nil,enabled))
   if k=='numbers' then
    row(b('number:number','숫자','표시 형식',enabled and cells),b('number:currency','금액','현재 문서 통화',enabled and cells))
    row(b('number:percent','백분율','0.25 → 25%',enabled and cells),b('number:text','텍스트','입력 전 지정',enabled and cells))
    row(b('number:automatic','자동 형식','내용에 맞춰 표시',enabled and cells))
   else row(b('cleanEnters','엔터 정리','빈 줄만 한 줄로',enabled),b('today','오늘 날짜','커서에 넣기',enabled)) end
   if k=='pages' then row(b('paper','용지 여백','10·15·10·15·20·20mm',enabled)) end
  elseif P.tab=='table' then
   local items={};for i,p in ipairs(M.profiles.tableStyles) do items[#items+1]=b('table:style:'..i,M.profiles[k].tableNames[i],'첫 행 강조',enabled and cells) end;row(table.unpack(items))
   row(b('table:create','새 표 만들기…','행·열 지정',enabled),b('table:template','표 양식…','새 표로 추가',enabled))
   local fills={};for _,v in ipairs({{'#FFFFFF','흰'},{'#E5F1FB','파랑'},{'#E4F1E5','초록'},{'#FFF4D6','노랑'}}) do fills[#fills+1]=b('table:fill:'..v[1],v[2],nil,enabled and cells) end;row(table.unpack(fills))
   row(b('table:border:all','전체선',nil,enabled and cells),b('table:border:outside','바깥선',nil,enabled and cells),b('table:border:none','선 없음',nil,enabled and cells))
   row(b('table:align:left','왼쪽',nil,enabled and cells),b('table:align:center','가운데',nil,enabled and cells),b('table:align:right','오른쪽',nil,enabled and cells))
   row(b('table:middle','세로 중앙',nil,enabled and cells),b('table:oneLine','한 줄 표시',nil,enabled and cells),b('table:wrap','줄바꿈',nil,enabled and cells))
   row(b('table:equalRows','행 높이 같게',nil,enabled and cells),b('table:equalColumns','열 너비 같게',nil,enabled and cells))
   row(b('rowBelow','아래에 행',nil,enabled and cells),b('columnAfter','뒤에 열',nil,enabled and cells))
   row(b('fitRows','행 내용 맞춤',nil,enabled and cells),b('fitColumns','열 내용 맞춤',nil,enabled and cells))
   row(b('table:borders','테두리 설정…',nil,enabled and cells))
  elseif P.tab=='image' then
   row(b('image:small','작은 사진',k=='keynote' and '너비 360pt · 비율 유지' or '너비 240pt · 비율 유지',enabled))
   row(b('image:medium','중간 사진',k=='keynote' and '너비 640pt · 비율 유지' or '너비 360pt · 비율 유지',enabled))
   row(b('image:wide',k=='pages' and '본문 폭' or '넓은 사진','비율 유지',enabled))
   row(b('image:sameHeight','같은 높이','사진 2개 이상',enabled))
   if k~='pages' then row(b('image:row','사진 나란히','2~4개 · 간격 24pt',enabled)) end
   row(b('objectCenter','가로 중앙',nil,enabled),b('objectMiddle','세로 중앙',nil,enabled))
   row(b('front','맨 앞으로',nil,enabled),b('back','맨 뒤로',nil,enabled))
  elseif P.tab=='chart' then
   row(b('chart:new:bar','비교 차트','2D 세로 막대',enabled))
   row(b('chart:new:line','변화 차트','2D 꺾은선',enabled))
   row(b('chart:new:pie','비중 차트','2D 원형',enabled))
   row(b('chart:compact','작게 배치','비율 유지',enabled),b('chart:wide','넓게 배치','비율 유지',enabled))
   row(b('chart:style:1','스타일 1','현재 페이지 첫 서식',enabled),b('chart:style:2','스타일 2','현재 페이지 둘째 서식',enabled))
   row(b('chart:style:3','스타일 3','현재 페이지 셋째 서식',enabled))
   row(b('objectCenter','가로 중앙',nil,enabled),b('objectMiddle','세로 중앙',nil,enabled))
  elseif P.tab=='shortcuts' then
   P.shortcutKind=P.shortcutKind or k or 'pages';local data=hs.json.read(M.root..'/shortcut-data.json')
   row(b('shortcutApp:pages','Pages',nil,idle),b('shortcutApp:numbers','Numbers',nil,idle),b('shortcutApp:keynote','Keynote',nil,idle))
   row(b('shortcutApp:freeform','Freeform',nil,idle))
   row(b('showPalette','명령 검색','⌃⌥K',enabled),b('showPresets','프리셋','⌃⌥P',enabled))
   for _,v in ipairs(data[P.shortcutKind].rows) do row(b('info:'..#rows,v[1],v[2],false)) end
   for _,v in ipairs(data.common) do row(b('info:'..#rows,v[1],v[2],false)) end
   row(b('shortcutOfficial','Apple 전체 단축키 ↗',nil,idle))
  else
   local items={};for _,c in ipairs(M.commands) do items[#items+1]=b(c.id,c.title,c.sub,enabled) end;pair(items)
   row(b('symbols','특수문자…','자주 쓰는 기호',enabled),b('today','오늘 날짜',nil,enabled))
   row(b('showPalette','명령 검색','⌃⌥K',enabled),b('showPresets','프리셋 목록','⌃⌥P',enabled))
  end
  local pageKey=(k or 'none')..':'..P.tab;local count=math.max(1,math.ceil(#rows/8));local page=math.max(1,math.min(P.pages[pageKey] or 1,count));P.pages[pageKey]=page;P.pageKey=pageKey;P.pageCount=count
  for n=(page-1)*8+1,math.min(page*8,#rows) do
   local items=rows[n];local cols=#items;local w=(252-(cols-1)*8)/cols;local y=214+((n-1)%8)*52
   for j,item in ipairs(items) do if item then
    button(list,item.id,item.label,76+(j-1)*(w+8),y,w,44,item.enabled,item.sub)
    if item.id:match('^table:fill:') then list[P.buttons[item.id].index].fillColor={hex=item.id:sub(12)} end
   end end
  end
  if count>1 then
   button(list,'page:prev','‹',76,636,40,28,idle and page>1)
   text(list,page..' / '..count,126,640,150,20,12,C.muted,'center')
   button(list,'page:next','›',288,636,40,28,idle and page<count)
  end
  append(list,{type='rectangle',action='fill',fillColor=C.line,frame=rect(12,674,316,1)})
  button(list,'editPresets','프리셋 설정',16,686,152,32,idle)
  button(list,'help','사용 안내 ↗',176,686,152,32,idle)
  local status=M.busy and '적용 중…' or '선택한 부분에만 적용합니다.'
  if M.lastResult and M.resultSequence~=P.oldResult then P.oldResult=M.resultSequence;P.resultUntil=hs.timer.secondsSinceEpoch()+6 end
  if P.resultUntil and P.resultUntil>hs.timer.secondsSinceEpoch() and M.lastResult then status=M.lastResult.message end
  text(list,status,16,730,310,24,11,M.lastResult and M.lastResult.ok==false and C.error or C.muted)
  P.canvas:replaceElements(list)
 end
 local function startDrag()
  if P.dragTimer then P.dragTimer:stop() end
  local start=hs.mouse.absolutePosition();local original=P.canvas:topLeft()
  P.dragTimer=hs.timer.doEvery(0.02,function()
   if not hs.eventtap.checkMouseButtons().left then P.dragTimer:stop();P.dragTimer=nil;save();return end
   local now=hs.mouse.absolutePosition();P.canvas:topLeft({x=original.x+now.x-start.x,y=original.y+now.y-start.y})
  end)
 end
 function P.click(id)
  local b=P.buttons[id];if not b or not b.enabled then return end
  local front=hs.application.frontmostApplication()
  P.lastClick={id=id,front=front and front:bundleID()}
  if id=="shortcuts" then P.showShortcuts(P.kind);return
  elseif id:match("^tab:") then P.tabs[P.kind or "none"]=id:sub(5);if id=="tab:shortcuts" then P.shortcutKind=P.kind or "pages" end;P.render();return
  elseif id=="page:next" or id=="page:prev" then P.pages[P.pageKey]=P.pages[P.pageKey]+(id=="page:next" and 1 or -1);P.render();return
  elseif id=="showPalette" or id=="showPresets" then M.show(id=="showPresets",context());return
  elseif id=="symbols" then M.work.symbols(context());return
  elseif id:match("^shortcutApp:") then P.shortcutKind=id:sub(13);P.render();return
  elseif id=="shortcutOfficial" then local data=hs.json.read(M.root.."/shortcut-data.json");P.openTask=hs.task.new("/usr/bin/open",nil,{data[P.shortcutKind].url}):start();return
  elseif id=="close" then P.hide();return
  elseif id=="layout" then P.arrange();return
  elseif id=="help" then M.help(context());return
  elseif id=="editPresets" then M.work.editPresets(P.kind);return
  elseif id:match("^launch:") then
   local app=id:match(":(.+)$");M.launchApp(app);return
  end
  local ctx=context()
  if not ctx or M.paused then hs.alert.show("편집할 문서를 먼저 선택하세요.");return end
  P.lastClick.target=ctx.app:bundleID()
  P.pending=true;P.render();M.run(id,ctx)
  P.pendingTimer=hs.timer.doAfter(0.3,function() P.pending=false;P.render() end)
 end
 local function mouseCallback(_,event,id)
  if event=="mouseEnter" then local ctx=M.capture();if ctx then P.target=M.snapshotSelection(ctx) end end
  if id=="drag" and event=="mouseDown" then startDrag();return end
  local b=P.buttons[id]
  if event=="mouseUp" and b then P.click(id)
  elseif (event=="mouseEnter" or event=="mouseExit") and b and b.enabled then
   P.canvas:elementAttribute(b.index,"fillColor",event=="mouseEnter" and C.hover or C.button)
  end
 end
 function P.show()
  P.enabled=true
  if not P.canvas then
   P.canvas=hs.canvas.new(geometry()):level("floating"):behavior({"canJoinAllSpaces","fullScreenAuxiliary"}):clickActivating(false):mouseCallback(mouseCallback)
   P.render()
  end
  P.canvas:show();save()
 end
 function P.hide() P.enabled=false;if P.canvas then P.canvas:hide() end;restoreLayouts();save() end
 function P.toggle() if P.enabled then P.hide() else P.show() end end
 function P.destroy()
  for _,key in ipairs({"timer","pendingTimer","dragTimer","appWatcher","clickTap"}) do if P[key] then P[key]:stop() end end
  restoreLayouts();if P.canvas then P.canvas:delete();P.canvas=nil end
 end
 P.appWatcher=hs.application.watcher.new(function(_,event,app)
  if event~=hs.application.watcher.activated or not app then return end
  if app:bundleID()~="org.hammerspoon.Hammerspoon" and not M.kind(app) then P.target=nil end
 end):start()
 P.clickTap=hs.eventtap.new({hs.eventtap.event.types.leftMouseDown},function(event)
  if not P.enabled or not P.canvas then return false end
  local point=event:location();local f=P.canvas:frame()
  if point.x>=f.x and point.x<=f.x+f.w and point.y>=f.y and point.y<=f.y+f.h then
   local ctx=M.capture();if ctx then P.target=M.snapshotSelection(ctx) end
  end
  return false
 end):start()
 P.timer=hs.timer.doEvery(0.35,function()
  if not P.enabled then return end
  local ctx=context()
  local sig=(ctx and ctx.kind or "none")..":"..tostring(ctx and ctx.pid)..":"..tostring(M.busy)..":"..tostring(M.paused)..":"..tostring(M.resultSequence)..":"..tostring(ctx and ctx.tableFocused)..":"..tostring(ctx and ctx.focusRole)..":"..tostring(M.settings.pages[1].name)
  if sig~=P.signature or (P.resultUntil and P.resultUntil<hs.timer.secondsSinceEpoch()) then
   P.signature=sig;if P.resultUntil and P.resultUntil<hs.timer.secondsSinceEpoch() then P.resultUntil=nil end;P.render()
  end
 end)
 if state.visible~=false then P.show() end
 return P
end
