-- Freeform uses its own native menus. It never enters iWork AppleScript workers.
return function(M)
 local F={commands={},paths={},sizes={}}
 for _,n in ipairs({10,12,14,18,24,36,48,64,72,96,144}) do F.sizes[n]=true end
 local function add(id,title,path) F.commands[#F.commands+1]={id=id,title=title};F.paths[id]=path end
 for _,v in ipairs({{'left','왼쪽 정렬','왼쪽 정렬'},{'center','가운데 정렬','중앙 정렬'},{'right','오른쪽 정렬','오른쪽 정렬'},{'justify','양쪽 정렬','좌우 정렬'},{'autoSize','텍스트 크기 자동 조절','텍스트 크기 자동 조절'}}) do add(v[1],v[2],{'포맷','텍스트',v[3]}) end
 for _,v in ipairs({{'bold','굵게','볼드체'},{'underline','밑줄','밑줄체'},{'strike','취소선','취소선'},{'grow','글자 크게','크게'},{'shrink','글자 작게','작게'},{'fonts','서체 창','서체 보기'}}) do add(v[1],v[2],{'포맷','서체',v[3]}) end
 for _,v in ipairs({{'textBox','글상자','텍스트 상자'},{'sticky','스티커 메모','스티커 메모'},{'boardTable','새 표','표'},{'connector','연결선','연결선'},{'arrow','화살표 선','화살촉이 있는 선'},{'file','파일·이미지 넣기…','파일 선택'},{'link','링크 넣기…','링크'}}) do add(v[1],v[2],{'삽입',v[3]}) end
 for _,v in ipairs({{'rectangle','사각형','직사각형'},{'rounded','둥근 카드','모서리가 둥근 사각형'},{'circle','타원','타원형'},{'diamond','마름모','마름모'}}) do add(v[1],v[2],{'삽입','도형',v[3]}) end
 for _,v in ipairs({{'copyStyle','스타일 복사','스타일 복사하기'},{'pasteStyle','스타일 붙이기','스타일 붙여넣기'},{'shadow','그림자','그림자'},{'roundedCorners','둥근 모서리','둥근 모서리'},{'colors','색상 창','색상 보기'},{'saveStyle','삽입 스타일 저장','삽입 스타일로 저장'}}) do add(v[1],v[2],{'포맷',v[3]}) end
 for _,v in ipairs({{'duplicate','선택 복제','선택 부분 복제'},{'pasteMatch','주변 서식에 맞춰 붙이기','붙여넣고 스타일 일치'}}) do add(v[1],v[2],{'편집',v[3]}) end
 for _,v in ipairs({{'rowBelow','아래에 행','아래에 행 추가'},{'columnAfter','뒤에 열','뒤에 열 추가'},{'fitRows','행 내용 맞춤','콘텐츠에 맞게 행 크기 변경'},{'fitColumns','열 내용 맞춤','콘텐츠에 맞게 열 크기 변경'},{'equalRows','행 높이 같게','같은 너비로 행 조정'},{'equalColumns','열 너비 같게','같은 너비로 열 조정'}}) do add(v[1],v[2],{'포맷','표',v[3]}) end
 for _,v in ipairs({{'mask','사진 자르기','마스크 편집'},{'resetMask','자르기 초기화','마스크 재설정'},{'removeBackground','배경 제거','배경 제거'}}) do add(v[1],v[2],{'포맷','이미지',v[3]}) end
 add('maskCircle','원형 사진',{'포맷','이미지','도형으로 마스크','타원형'})
 add('maskRounded','둥근 사진',{'포맷','이미지','도형으로 마스크','모서리가 둥근 사각형'})
 for _,v in ipairs({{'group','그룹','그룹'},{'ungroup','그룹 해제','그룹화 해제'},{'front','맨 앞으로','맨 앞으로 가져오기'},{'back','맨 뒤로','맨 뒤로 보내기'},{'lock','잠그기','잠그기'},{'unlock','잠금 해제','잠금 해제'},{'aspect','비율 유지','비율 유지'}}) do add(v[1],v[2],{'정렬',v[3]}) end
 for _,v in ipairs({{'objectLeft','왼쪽 맞춤','왼쪽'},{'objectCenter','가로 중앙','중앙 정렬'},{'objectMiddle','세로 중앙','가운데'},{'objectTop','위쪽 맞춤','상단'}}) do add(v[1],v[2],{'정렬','대상체 정렬',v[3]}) end
 add('distributeH','가로 간격 같게',{'정렬','대상체 균등 배열','가로 방향'})
 add('distributeV','세로 간격 같게',{'정렬','대상체 균등 배열','세로 방향'})
 add('fitBoard','보드 전체 보기',{'보기','확대/축소','콘텐츠에 맞게 확대/축소'})
 add('fitSelection','선택 부분 보기',{'보기','확대/축소','선택 부분 확대/축소'})
 add('actualSize','100% 보기',{'보기','확대/축소','실제 크기'})
 add('snap','격자에 맞추기',{'보기','격자로 스냅'})
 add('scene','현재 화면을 장면으로',{'보기','장면','장면 추가'})
 local function active(ctx)
  local a=hs.application.frontmostApplication();local w=ctx.app:focusedWindow()
  return a and a:pid()==ctx.pid and w and w:id()==ctx.window:id()
 end
 local function find(e,pred,depth)
  if not e or (depth or 0)>24 then return end
  if pred(e) then return e end
  for _,c in ipairs(e:attributeValue('AXChildren') or {}) do local r=find(c,pred,(depth or 0)+1);if r then return r end end
 end
 local function menu(ctx,id)
  if not active(ctx) then return false end
  local path=F.paths[id];if not path then return false end
  local item=ctx.app:findMenuItem(path)
  if id=='fonts' and not item then path={'포맷','서체','서체 가리기'};item=ctx.app:findMenuItem(path) end
  if item and item.enabled then return ctx.app:selectMenuItem(path)~=nil end
  return false
 end
 local function sizeButton(ctx)
  return find(hs.axuielement.windowElement(ctx.window),function(e)return (e:attributeValue('AXRole')=='AXButton' and e:attributeValue('AXDescription')=='서체 크기 설정') or (e:attributeValue('AXRole')=='AXMenuButton' and e:attributeValue('AXDescription')=='텍스트 크기 메뉴') end)
 end
 function F.preset(ctx,p,attempt)
  if ctx.textCaret then M.completed(false,"글자를 드래그하거나 글상자 테두리를 선택하세요.");return end
  if ctx.multipleSelection or ctx.tableFocused then M.completed(false,"글자 프리셋은 글상자·메모 한 개씩 선택하세요.");return end
  if not p or not F.sizes[p.size] then M.completed(false,'Freeform 크기 목록에서 값을 선택하세요.');return end
  local button=sizeButton(ctx)
  if not button and not attempt then
   local focus=ctx.objectElement or ctx.focus
   if focus and focus:isValid() then
    for _,action in ipairs(focus:actionNames() or {}) do
     if action:find('Name:포맷 옵션 보기',1,true)==1 then
      M.busy=true;focus:performAction(action);F.timer=hs.timer.doAfter(.18,function() if active(ctx) then F.preset(ctx,p,true) else M.completed(false,'보드를 다시 선택하세요.') end end);return
     end
    end
   end
  end
  if not button then M.completed(false,'글상자·메모 하나를 클릭하거나 글자를 선택하세요.');return end
  M.busy=true;button:performAction('AXPress')
  F.timer=hs.timer.doAfter(.15,function()
   if not active(ctx) then M.completed(false,'시험하던 보드로 돌아가 다시 실행하세요.');return end
   local option=find(hs.axuielement.windowElement(ctx.window),function(e)return e:attributeValue('AXRole')=='AXMenuItem' and e:attributeValue('AXDescription')==tostring(p.size)..'pt' end)
   if not option then hs.eventtap.keyStroke({},'escape',0,ctx.app);M.completed(false,'서체 크기 목록을 열지 못했습니다.');return end
   option:performAction('AXPress')
   F.timer=hs.timer.doAfter(.15,function()
    if not active(ctx) then M.completed(false,'보드로 돌아가 적용 상태를 확인하세요.');return end
    local openMenu=option:attributeValue('AXParent');if openMenu and openMenu:isValid() then openMenu:performAction('AXCancel') end
    local bold=ctx.app:findMenuItem(F.paths.bold)
    local okBold=bold and bold.enabled and ((bold.ticked==true)==p.bold or menu(ctx,'bold'))
    local okAlign=menu(ctx,p.align)
    local tries=0
    local function verify()
     if not active(ctx) then M.completed(false,'보드로 돌아가 적용 상태를 확인하세요.');return end
     tries=tries+1;local actual=sizeButton(ctx);local value=actual and actual:attributeValue('AXTitle')
     if tonumber(value)~=p.size and tries<5 then F.timer=hs.timer.doAfter(.15,verify);return end
     F.lastVerification={size=value,bold=okBold,align=okAlign,window=ctx.window:title()}
     local ok=okBold and okAlign and tonumber(value)==p.size
     M.completed(ok,p.name..(ok and ' 적용 · 문구 유지' or ' · 적용된 크기와 정렬을 확인해 주세요.'))
    end
    F.timer=hs.timer.doAfter(.15,verify)
   end)
  end)
 end
 function F.run(id,ctx,attempt)
  if id:match('^boardBorder:') then
   local labels={all='모든 테두리 보기',outside='표 바깥쪽 윤곽선 보기',none='표 테두리 없음'}
   local label=labels[id:match(':(.+)$')];local root=hs.axuielement.windowElement(ctx.window)
   local button=find(root,function(e)return e:attributeValue('AXRole')=='AXButton' and e:attributeValue('AXDescription')=='표 스타일 인스펙터' end)
   if not button and not attempt and ctx.tableElement then
    for _,action in ipairs(ctx.tableElement:actionNames() or {}) do if action:find('Name:포맷 옵션 보기',1,true)==1 then
     M.busy=true;ctx.tableElement:performAction(action);F.timer=hs.timer.doAfter(.18,function() if active(ctx) then F.run(id,ctx,true) else M.completed(false,'대상 보드로 돌아가세요.') end end);return
    end end
   end
   if not button then M.completed(false,'Esc를 누른 뒤 표 전체를 선택하고 다시 실행하세요.');return end
   M.busy=true;button:performAction('AXPress')
   F.timer=hs.timer.doAfter(.18,function()
    if not active(ctx) then M.completed(false,'대상 보드로 돌아가세요.');return end
    local control=find(root,function(e)return e:attributeValue('AXRole')=='AXCheckBox' and e:attributeValue('AXDescription')==label end)
    if not control then M.completed(false,'표 테두리 설정을 찾지 못했습니다.');return end
    control:performAction('AXPress')
    F.timer=hs.timer.doAfter(.18,function()
     if not active(ctx) then M.completed(false,'대상 보드로 돌아가세요.');return end
     local ok=control:isValid() and control:attributeValue('AXValue')==1
     local pop=find(root,function(e)return e:attributeValue('AXRole')=='AXPopover' end);if pop then pop:performAction('AXCancel') end
     M.completed(ok,ok and 'Freeform 표 테두리 적용' or '표 테두리 적용 상태를 확인하세요.')
    end)
   end);return
  end
  local inspector=({tableAppearance='표 스타일 인스펙터',tableText='표 텍스트 인스펙터',tableLayout='표 레이아웃 인스펙터'})[id]
  if inspector then
   local e=find(hs.axuielement.windowElement(ctx.window),function(x)return x:attributeValue('AXRole')=='AXButton' and x:attributeValue('AXDescription')==inspector end)
   if not e and not attempt and ctx.tableElement then
    for _,action in ipairs(ctx.tableElement:actionNames() or {}) do if action:find('Name:포맷 옵션 보기',1,true)==1 then
     ctx.tableElement:performAction(action);F.timer=hs.timer.doAfter(.18,function() if active(ctx) then F.run(id,ctx,true) else M.completed(false,'대상 보드로 돌아가세요.') end end);return
    end end
   end
   local ok=active(ctx) and e and e:performAction('AXPress')
   M.completed(ok~=nil and ok~=false,ok and 'Freeform 표 서식 도구 열기' or '표 또는 셀을 선택하고 다시 누르세요.');return
  end
  if id=='cleanup' then return F.preset(ctx,M.profiles.freeform.cleanup) end
  if id:match('^preset:') then return F.preset(ctx,M.settings.freeform[tonumber(id:match('%d+$'))]) end
  local ok=menu(ctx,id);M.completed(ok,ok and 'Freeform 편집 명령 적용' or '현재 선택에서는 사용할 수 없습니다. 대상체 또는 표 셀을 선택하세요.')
 end
 function F.available(ctx,id)
  if not F.paths[id] then return true end
  local item=ctx.app:findMenuItem(F.paths[id]);if id=='fonts' and not item then item=ctx.app:findMenuItem({'포맷','서체','서체 가리기'}) end;return item and item.enabled==true or false
 end
 function F.rows(tab)
  if tab=='text' then
   local p=M.settings.freeform;return {{{'preset:1',p[1].name,p[1].size..'pt · ⌃⌥1'},{'preset:2',p[2].name,p[2].size..'pt · ⌃⌥2'}},{{'preset:3',p[3].name,p[3].size..'pt · ⌃⌥3'},{'preset:4',p[4].name,p[4].size..'pt · ⌃⌥4'}},{{'textBox','글상자 추가'},{'sticky','메모 추가'}},{{'bold','굵게'},{'underline','밑줄'},{'strike','취소선'}},{{'left','왼쪽'},{'center','가운데'},{'right','오른쪽'}},{{'shrink','A−'},{'fonts','서체 창'},{'grow','A+'}},{{'copyStyle','스타일 복사'},{'pasteStyle','스타일 붙이기'}},{{'autoSize','텍스트 크기 자동 조절'}}}
  elseif tab=='board' then return {{{'sticky','스티커 메모'},{'textBox','글상자'}},{{'rounded','둥근 카드'},{'rectangle','사각형'}},{{'circle','타원'},{'diamond','마름모'}},{{'connector','연결선'},{'arrow','화살표 선'}},{{'link','링크 넣기…'},{'duplicate','선택 복제','⌘D'}},{{'fitBoard','보드 전체 보기'},{'fitSelection','선택 부분 보기'}},{{'actualSize','100% 보기'},{'snap','격자에 맞추기'}},{{'scene','현재 화면을 장면으로'}}}
  elseif tab=='table' then return {{{'boardTable','새 표 추가'}},{{'tableAppearance','테두리·채우기…'},{'tableText','표 글자…'}},{{'rowBelow','아래에 행'},{'columnAfter','뒤에 열'}},{{'boardBorder:all','전체선'},{'boardBorder:outside','바깥선'},{'boardBorder:none','선 없음'}},{{'equalRows','행 높이 같게'},{'equalColumns','열 너비 같게'}},{{'left','왼쪽'},{'center','가운데'},{'right','오른쪽'}},{{'tableLayout','행·열 크기 설정…','자동 크기 조절'}},{{'copyStyle','스타일 복사'},{'pasteStyle','스타일 붙이기'}}}
  elseif tab=='image' then return {{{'file','파일·이미지 넣기…','Mac에서 파일 선택'}},{{'mask','사진 자르기'},{'resetMask','자르기 초기화'}},{{'maskCircle','원형 사진'},{'maskRounded','둥근 사진'}},{{'shadow','그림자'},{'removeBackground','배경 제거'}},{{'aspect','비율 유지'},{'duplicate','선택 복제'}},{{'front','맨 앞으로'},{'back','맨 뒤로'}},{{'objectCenter','가로 중앙'},{'objectMiddle','세로 중앙'}}}
  else return {{{'objectLeft','왼쪽 맞춤'},{'objectTop','위쪽 맞춤'}},{{'objectCenter','가로 중앙'},{'objectMiddle','세로 중앙'}},{{'distributeH','가로 간격 같게','대상체 3개 이상'},{'distributeV','세로 간격 같게','대상체 3개 이상'}},{{'group','그룹','⌃⌥G'},{'ungroup','그룹 해제'}},{{'front','맨 앞으로'},{'back','맨 뒤로'}},{{'lock','잠그기'},{'unlock','잠금 해제'}},{{'fitBoard','보드 전체 보기'},{'fitSelection','선택 부분 보기'}},{{'saveStyle','삽입 스타일 저장','선택 대상의 기본 서식'}}} end
 end
 for _,v in ipairs({{'cleanup','글자 정리'},{'boardBorder:all','표 전체선'},{'boardBorder:outside','표 바깥선'},{'boardBorder:none','표 선 없음'},{'tableAppearance','표 테두리·채우기 설정'},{'tableText','표 글자 설정'},{'tableLayout','표 행·열 크기 설정'}}) do F.commands[#F.commands+1]={id=v[1],title=v[2]} end
 function F.stop() if F.timer then F.timer:stop() end end
 return F
end
