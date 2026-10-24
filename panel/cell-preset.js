// 허용한 Numbers의 현재 활성 시트에서 선택된 셀의 서식만 변경합니다.
function run(argv) {
  var req=JSON.parse(argv[0]);
  if(!/^com\.apple\.(iWork\.)?(Pages|Numbers|Keynote)$/.test(req.id)) throw Error('지원하지 않는 앱입니다.');
  var app=Application(req.id), docs=app.documents;
  if(docs.length===0) throw Error('먼저 Numbers 문서를 여세요.');
  var doc=docs[0], tables=(/Numbers$/.test(req.id)?doc.activeSheet():/Keynote$/.test(req.id)?doc.currentSlide():doc).tables(), matches=[];
  if(req.window.normalize('NFC').indexOf(doc.name().normalize('NFC'))<0)throw Error('대상 문서가 바뀌었습니다.');
  tables.forEach(function(t){try {
   var r=t.selectionRange(),titleMatches=!req.tableTitle||req.tableTitle.normalize('NFC').indexOf(t.name().normalize('NFC')+',')===0;
   if(r && r.name() && titleMatches)matches.push({table:t,range:r});
  }catch(e){}});
  if(matches.length!==1) throw Error('서식을 바꿀 셀 범위를 하나 선택하세요.');
  var r=matches[0].table.ranges.byName(matches[0].range.name()), p=req.preset;
  if(!Number.isFinite(p.size)||p.size<6||p.size>200) throw Error('글자 크기는 6~200pt입니다.');
  if(['left','center','right'].indexOf(p.align)<0) throw Error('정렬 값이 올바르지 않습니다.');
  function rgb(s){if(!/^#[0-9A-Fa-f]{6}$/.test(s))throw Error('색은 #RRGGBB 형식입니다.');return [1,3,5].map(function(i){return parseInt(s.slice(i,i+2),16)*257;});}
  var fg=p.color?rgb(p.color):null,bg=p.background?rgb(p.background):null;
  if(p.format && ['number','automatic','percent','currency','text'].indexOf(p.format)<0)throw Error('지원하지 않는 숫자 서식입니다.');
  var address=r.name();
  r.fontSize=p.size;r.alignment=p.align;if(fg)r.textColor=fg;if(bg)r.backgroundColor=bg;
  if(p.format)r.format=p.format;
  // 실제 변경 후 공개 속성을 다시 읽어 확인합니다. 셀 값/수식은 읽거나 변경하지 않습니다.
  var checked={size:r.fontSize(),alignment:r.alignment(),color:r.textColor(),background:r.backgroundColor()};
  if(Math.abs(checked.size-p.size)>0.01||checked.alignment!==p.align)throw Error('서식 적용 결과를 확인하지 못했습니다.');
  return JSON.stringify({ok:true,range:address,checked:checked});
}
