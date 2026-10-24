// 현재 문서의 선택된 표 서식만 수정합니다. 기존 셀의 값과 수식에는 쓰지 않습니다.
function run(argv) {
 var req=JSON.parse(argv[0]);
 if(!/^com\.apple\.(iWork\.)?(Pages|Keynote|Numbers)$/.test(req.id))throw Error('지원하지 않는 앱입니다.');
 var app=Application(req.id);if(!app.documents.length)throw Error('문서를 먼저 여세요.');
 var doc=app.documents[0];
 if(req.window.normalize('NFC').indexOf(doc.name().normalize('NFC'))<0)throw Error('대상 문서가 바뀌었습니다.');
 var container=/Numbers$/.test(req.id)?doc.activeSheet():/Keynote$/.test(req.id)?doc.currentSlide():doc;
 if(req.action==='template') {
  var templates={
   report:[['구분','내용','비고'],['항목 1','',''],['항목 2','',''],['항목 3','','']],
   comparison:[['비교 항목','A','B'],['특징','',''],['장점','',''],['고려할 점','','']],
   schedule:[['일시','활동','담당'],['','',''],['','',''],['','','']],
   checklist:[['이름','완료','메모'],['',false,''],['',false,''],['',false,''],['',false,'']],
   budget:[['항목','수량','단가','금액'],['항목 1',0,0,'=B2*C2'],['항목 2',0,0,'=B3*C3'],['항목 3',0,0,'=B4*C4'],['합계','','','=SUM(D2:D4)']],
   assessment:[['이름','기준 1','기준 2','메모'],['','','',''],['','','',''],['','','','']],
   metrics:[['핵심 지표','값','설명'],['지표 1',0,''],['지표 2',0,''],['지표 3',0,'']],
   steps:[['단계','할 일','완료 기준'],['1. 준비','',''],['2. 실행','',''],['3. 확인','','']]
  };
  var values=templates[req.template];if(!values)throw Error('표 양식을 확인하세요.');
  if(/Pages$/.test(req.id))container=doc.currentPage();
  var serial=container.tables.length+1,tableName='Work '+req.template+' '+serial,existingNames=container.tables.name();
  while(existingNames.indexOf(tableName)>=0)tableName='Work '+req.template+' '+(++serial);
  var nt=app.Table({rowCount:values.length,columnCount:values[0].length,headerRowCount:1,headerColumnCount:0,name:tableName});container.tables.push(nt);
  // Pages may reorder tables after insertion; resolve the new table by its unique name.
  nt=container.tables.byName(tableName);if(nt.name()!==tableName)throw Error('새 표를 식별하지 못했습니다.');
  values.forEach(function(row,y){row.forEach(function(v,x){nt.rows[y].cells[x].value=v;});});
  var fs=/Keynote$/.test(req.id)?24:12;
  nt.cellRange.fontSize=fs;nt.cellRange.backgroundColor=[65535,65535,65535];nt.cellRange.textColor=[6939,6939,6939];nt.cellRange.textWrap=true;nt.cellRange.verticalAlignment='center';
  nt.rows[0].backgroundColor=[0,23130,40606];nt.rows[0].textColor=[65535,65535,65535];
  nt.columns().forEach(function(c){c.width=(/Keynote$/.test(req.id)?960:480)/values[0].length;});nt.rows().forEach(function(r){r.height=fs*2;});
  if(req.template==='budget'){nt.columns[2].format='currency';nt.columns[3].format='currency';nt.rows[values.length-1].backgroundColor=[58853,61937,64507];}
  if(req.template==='checklist'&&/Numbers$/.test(req.id))nt.ranges.byName('B2:B'+values.length).format='checkbox';
  // Apply and verify the final font size on the uniquely identified new table.
  nt.cellRange.fontSize=fs;
  if(nt.cells().some(function(cell){return Math.abs(cell.fontSize()-fs)>.01;}))throw Error('새 표의 글자 크기를 확인하지 못했습니다. 표를 선택해 서식을 다시 적용하세요.');
  nt.selectionRange=nt.cellRange();return JSON.stringify({created:true,name:nt.name(),rows:nt.rowCount(),columns:nt.columnCount()});
 }
 if(req.action==='create') {
  if(/Pages$/.test(req.id))container=doc.currentPage();
  var rows=req.rows,cols=req.columns;
  if(!Number.isInteger(rows)||rows<1||rows>100||!Number.isInteger(cols)||cols<1||cols>20)throw Error('행은 1~100, 열은 1~20입니다.');
  var before=container.tables.length;
  var serial=before+1,tableName='편집 도우미 표 '+serial,existingNames=container.tables.name();while(existingNames.indexOf(tableName)>=0)tableName='편집 도우미 표 '+(++serial);
  var table=app.Table({rowCount:rows,columnCount:cols,headerRowCount:0,headerColumnCount:0,name:tableName});
  container.tables.push(table);
  if(container.tables.length!==before+1)throw Error('표 생성 결과를 확인하지 못했습니다.');
  var added=container.tables.byName(tableName);if(added.name()!==tableName)throw Error('새 표를 식별하지 못했습니다.');
  if(added.rowCount()!==rows||added.columnCount()!==cols)throw Error('표의 행·열 수를 확인해 주세요.');
  var font=/Keynote$/.test(req.id)?24:12;added.cellRange.fontSize=font;added.cellRange.alignment='left';added.cellRange.verticalAlignment='center';added.cellRange.textWrap=true;
  added.columns().forEach(function(c){c.width=(/Keynote$/.test(req.id)?960:480)/cols;});added.rows().forEach(function(r){r.height=font*2;});
  added.cellRange.fontSize=font;
  if(added.cells().some(function(cell){return Math.abs(cell.fontSize()-font)>.01;}))throw Error("새 표의 글자 크기를 확인하지 못했습니다.");
  added.selectionRange=added.cellRange();
  return JSON.stringify({created:true,name:added.name(),rows:rows,columns:cols});
 }
 var selectedNames=[];
 if(!/Numbers$/.test(req.id))try {doc.selection().forEach(function(o){try{selectedNames.push(o.name());}catch(e){}});}catch(e){}
 var tables=container.tables(),matches=[];
 tables.forEach(function(t){
  try {
   var r=t.selectionRange();
   var titleMatches=!req.tableTitle||req.tableTitle.normalize('NFC').indexOf(t.name().normalize('NFC')+',')===0;
   if(r&&r.name()&&titleMatches&&(!selectedNames.length||selectedNames.indexOf(t.name())>=0))matches.push({table:t,range:r});
  }catch(e){}
 });
 if(matches.length!==1)throw Error('표 안의 셀 범위를 하나 선택하세요.');
 var table=matches[0].table,address=matches[0].range.name();
 // 선택 범위 프록시는 행·열 크기를 바꾸는 도중 달라질 수 있으므로 주소를 고정합니다.
 var r=table.ranges.byName(address);
 var coordinates=address.replace(/\$/g,'').match(/^([A-Z]+)(\d+)(?::([A-Z]+)(\d+))?$/);
 function columnNumber(s){var n=0;for(var i=0;i<s.length;i++)n=n*26+s.charCodeAt(i)-64;return n;}
 function selectedAxes(axis){
  if(!coordinates)throw Error('하나의 사각형 셀 범위를 선택하세요.');
  var start=axis==='rows'?Number(coordinates[2]):columnNumber(coordinates[1]);
  var end=axis==='rows'?Number(coordinates[4]||coordinates[2]):columnNumber(coordinates[3]||coordinates[1]);
  var result=[];for(var i=start;i<=end;i++)result.push(table[axis][i-1]);return result;
 }
 function equalize(items,property){
  var target=items.reduce(function(n,x){return n+x[property]();},0)/items.length;
  items.forEach(function(x){x[property]=target;});
  var actual=items.map(function(x){return x[property]();});
  // 여러 줄 셀의 최소 크기 때문에 일부 행·열만 커지면, 수용 가능한 크기로 재통일합니다.
  if(Math.max.apply(null,actual)-Math.min.apply(null,actual)>0.02){
   target=Math.ceil(Math.max.apply(null,actual));items.forEach(function(x){x[property]=target;});
   actual=items.map(function(x){return x[property]();});
  }
  if(Math.max.apply(null,actual)-Math.min.apply(null,actual)>0.02)throw Error('일부 셀의 최소 크기 때문에 균등하게 맞추지 못했습니다.');
 }
 function color(s){if(!/^#[0-9a-f]{6}$/i.test(s))throw Error('색상 값을 확인하세요.');return [1,3,5].map(function(i){return parseInt(s.slice(i,i+2),16)*257;});}
 switch(req.action){
 case 'fill':r.backgroundColor=color(req.color);break;
 case 'align':
  if(['left','center','right'].indexOf(req.value)<0)throw Error('정렬을 확인하세요.');r.alignment=req.value;break;
 case 'vertical':
  if(['top','center','bottom'].indexOf(req.value)<0)throw Error('세로 정렬을 확인하세요.');r.verticalAlignment=req.value;break;
 case 'wrap':r.textWrap=req.value===true;break;
 case 'equalRows':
  equalize(selectedAxes('rows'),'height');table.selectionRange=r;break;
 case 'equalColumns':
  equalize(selectedAxes('columns'),'width');table.selectionRange=r;break;
 case 'cleanup':
  r.fontSize=req.size;r.verticalAlignment='center';r.textWrap=true;
  r.cells().forEach(function(c){c.alignment=typeof c.value()==='number'?'right':'left';});break;
 case 'preset':
  var p=req.preset;if(!p||!Number.isFinite(req.size)||req.size<6||req.size>200)throw Error('표 프리셋을 확인하세요.');
  var bg=color(p.background),fg=color(p.color),hb=color(p.headerBackground),hf=color(p.headerColor);
  r.fontSize=req.size;r.backgroundColor=bg;r.textColor=fg;r.verticalAlignment='center';r.textWrap=true;
  r.cells().forEach(function(c){c.alignment=typeof c.value()==='number'?'right':'left';});
  var headRow=Number(coordinates[2]);
  r.cells().forEach(function(c){if(c.row.address()===headRow){c.backgroundColor=hb;c.textColor=hf;c.alignment='center';}});break;
 case 'format':
  if(['automatic','number','currency','percent','text','date and time'].indexOf(req.value)<0)throw Error('표시 형식을 확인하세요.');
  var cells=r.cells();
  if(req.value==='text'&&cells.some(function(c){var v=c.value();return (v!==null&&v!==undefined&&v!=='')||!!c.formula();}))throw Error('텍스트 형식은 입력 전의 빈 셀에 지정하세요. 기존 값·수식은 유지했습니다.');
  r.format=req.value;
  // Mixed text/number selections have no single range format. JXA also does not
  // expose the reserved `number` and `text` enumeration values as ordinary strings.
  if(req.value==='currency'||req.value==='percent')cells.forEach(function(c){if(typeof c.value()==='number'&&c.format()!==req.value)throw Error('숫자 셀의 표시 형식을 확인하지 못했습니다.');});
  if(req.value==='automatic'&&r.format()!=='automatic')throw Error('자동 표시 형식을 확인하지 못했습니다.');break;
 case 'merge':app.merge(r);break;
 case 'unmerge':app.unmerge(r);break;
 default:throw Error('지원하지 않는 표 작업입니다.');
 }
 return JSON.stringify({ok:true,range:address,size:r.fontSize(),alignment:r.alignment(),vertical:r.verticalAlignment(),wrap:r.textWrap()});
}
