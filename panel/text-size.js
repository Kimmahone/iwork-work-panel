// 선택한 글상자 또는 정확히 대응되는 선택 문자 구간의 크기만 변경합니다.
// 문서 내용은 로컬 표준입력으로만 받고 로그·파일에 남기지 않습니다.
ObjC.import('Foundation');
function run(){
 var raw=$.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile;
 var req=JSON.parse(ObjC.unwrap($.NSString.alloc.initWithDataEncoding(raw,$.NSUTF8StringEncoding)));
 if(!/^com\.apple\.(iWork\.)?(Pages|Keynote|Numbers)$/.test(req.id))throw Error('지원하지 않는 앱입니다.');
 if(!Number.isFinite(req.size)||req.size<6||req.size>200)throw Error('글자 크기는 6~200pt입니다.');
 if(req.caret&&!req.cells)throw Error('바꿀 글자를 드래그해서 선택하거나 Esc 후 글상자를 선택하세요.');
 var app=Application(req.id);if(app.documents.length===0)throw Error('문서를 먼저 여세요.');
 var doc=app.documents[0],docName=doc.name();
 if(req.window.normalize('NFC').indexOf(docName.normalize('NFC'))<0)throw Error('문서 편집 화면을 선택한 뒤 다시 실행하세요.');
 if(req.cells){
  var container=/Numbers$/.test(req.id)?doc.activeSheet():/Keynote$/.test(req.id)?doc.currentSlide():doc, matches=[];
  container.tables().forEach(function(t){try{var r=t.selectionRange();if(r&&r.name()&&(!req.tableTitle||req.tableTitle.normalize('NFC').indexOf(t.name().normalize('NFC')+',')===0))matches.push({t:t,r:r.name()});}catch(e){}});
  if(matches.length!==1)throw Error('하나의 셀 범위를 선택하세요.');
  var r=matches[0].t.ranges.byName(matches[0].r);r.fontSize=req.size;
  if(Math.abs(r.fontSize()-req.size)>0.01)throw Error('셀 크기를 확인하지 못했습니다.');
  return JSON.stringify({ok:true,size:r.fontSize(),range:matches[0].r});
 }
 var selected=doc.selection(),targets=[];
 function normalized(s){return String(s).replace(/\r|\u2028/g,'\n');}
 if(req.range && req.range.length>0){
  var candidates=[];
  if(/Pages$/.test(req.id))try {if(doc.documentBody())candidates.push(doc.bodyText);}catch(e){}
  selected.forEach(function(o){try{if(typeof o.objectText()==='string')candidates.push(o.objectText);}catch(e){}});
  candidates.forEach(function(t){
   var full=normalized(t()),fragment=normalized(req.text),offset=full.indexOf(fragment);
   if(fragment.length===0||offset<0||full.indexOf(fragment,offset+1)>=0)return;
   var start=offset+req.range.location,end=start+req.range.length;
   if(start<0||end>full.length)return;
   if(start>0 && /[\uDC00-\uDFFF]/.test(full[start]))throw Error('선택 구간이 문자 중간에서 시작합니다.');
   if(end<full.length && /[\uDC00-\uDFFF]/.test(full[end]))throw Error('선택 구간이 문자 중간에서 끝납니다.');
   var a=Array.from(full.slice(0,start)).length,b=Array.from(full.slice(0,end)).length;
   if(b-a>1500)throw Error('한 번에 1,500자 이하로 선택해 주세요.');
   targets.push({text:t,start:a,end:b});
  });
  if(targets.length!==1)throw Error('글자 선택 구간을 정확히 확인하지 못했습니다. 글상자 전체를 선택하거나 더 짧은 구간으로 다시 선택하세요.');
 }else{
  if(selected.length===0)throw Error('글자를 드래그하거나 글상자를 선택하세요.');
  selected.forEach(function(o){try{
   if(typeof o.objectText()!=='string')throw Error('text');
   targets.push({text:o.objectText});
  }catch(e){throw Error('글이 들어 있는 글상자만 선택하세요.');}});
 }
 targets.forEach(function(t){
  if(t.start!==undefined){
   for(var i=t.start;i<t.end;i++)t.text.characters[i].size=req.size;
   var sizes=t.text.characters.size().slice(t.start,t.end);
   if(sizes.some(function(s){return Math.abs(s-req.size)>0.01;}))throw Error('선택 글자의 크기를 확인하지 못했습니다.');
  }else{
   t.text.size=req.size;
   if(Math.abs(t.text.size()-req.size)>0.01)throw Error('글상자의 크기를 확인하지 못했습니다.');
  }
 });
 return JSON.stringify({ok:true,size:req.size,targets:targets.length});
}
