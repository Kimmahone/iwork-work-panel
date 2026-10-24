// Native objects only. Selection and document are checked before any mutation.
function run(argv) {
 var q=JSON.parse(argv[0]);
 if(!/^com\.apple\.(iWork\.)?(Pages|Numbers|Keynote)$/.test(q.id))throw Error('지원하지 않는 앱입니다.');
 var app=Application(q.id);if(!app.documents.length)throw Error('문서를 먼저 여세요.');
 var d=app.documents[0],kind=q.id.split('.').pop();
 if(q.window.normalize('NFC').indexOf(d.name().normalize('NFC'))<0)throw Error('대상 문서가 바뀌었습니다.');
 var expected=q.action.indexOf('image:')===0?'image':'chart',selected=[];
 if(kind==='Numbers'){
  if(!Array.isArray(q.objects)||!q.objects.length)throw Error('이미지 또는 차트를 먼저 선택하세요.');
  var pool=(expected==='image'?d.activeSheet.images():d.activeSheet.charts()).map(function(o){return {o:o,w:o.width(),h:o.height(),p:o.position()};});
  var used=[];q.objects.forEach(function(x){
   var candidates=pool.filter(function(p){return Math.abs(p.w-x.width)<0.16&&Math.abs(p.h-x.height)<0.16&&Math.abs(p.p.x-x.x)<0.16&&Math.abs(p.p.y-x.y)<0.16;});
   if(candidates.length!==1||used.indexOf(candidates[0])>=0)throw Error('겹친 대상체를 구분할 수 없습니다. 대상체를 이동한 뒤 다시 선택하세요.');
   used.push(candidates[0]);selected.push(candidates[0].o);
  });
 }else selected=d.selection();
 if(!selected.length)throw Error('이미지 또는 차트를 먼저 선택하세요.');
 var objects=selected.map(function(o){
  var spec=Automation.getDisplayString(o),type=/\.images\./.test(spec)?'image':/\.charts\./.test(spec)?'chart':'other';if(type!==expected)throw Error(expected==='image'?'이미지만 선택하세요.':'차트만 선택하세요.');
  if(o.locked())throw Error('잠긴 대상체가 포함되어 있습니다.');
  return {o:o,w:o.width(),h:o.height(),p:o.position()};
 });
 var available=kind==='Pages'?480:kind==='Keynote'?d.width()-120:720;
 var action=q.action.split(':')[1],width;
 if(action==='small')width=kind==='Keynote'?360:240;
 else if(action==='wide')width=available;
 else if(action==='medium')width=kind==='Keynote'?640:360;
 else if(action==='compact')width=kind==='Keynote'?560:360;
 else if(action==='sameHeight'){
  if(objects.length<2)throw Error('이미지를 두 개 이상 선택하세요.');
  var h=objects[0].h;objects.forEach(function(x){x.o.width=x.w*h/x.h;x.o.height=h;});
 } else if(action==='row'){
  if(kind==='Pages')throw Error('사진 나란히 배치는 Numbers·Keynote에서 사용하세요.');
  if(objects.length<2||objects.length>4)throw Error('이미지 2~4개를 선택하세요.');
  var gap=24,ratios=objects.reduce(function(sum,x){return sum+x.w/x.h;},0),height=(available-gap*(objects.length-1))/ratios;
  var x=kind==='Keynote'?60:40,y=Math.min.apply(null,objects.map(function(o){return o.p.y;}));
  objects.forEach(function(item){var w=height*item.w/item.h;item.o.width=w;item.o.height=height;item.o.position={x:x,y:y};x+=w+gap;});
 } else throw Error('지원하지 않는 미디어 프리셋입니다.');
 if(width)objects.forEach(function(x){x.o.width=width;x.o.height=x.h*width/x.w;});
 var result=objects.map(function(x){return {type:expected,width:x.o.width(),height:x.o.height(),position:x.o.position()};});
 if(width&&result.some(function(x){return Math.abs(x.width-width)>1;}))throw Error('문서가 대상체 크기를 제한했습니다. 적용 크기를 확인하세요.');
 if(result.some(function(x,i){return Math.abs(x.width/x.height-objects[i].w/objects[i].h)>0.02;}))throw Error('대상체 비율을 확인해 주세요.');
 return JSON.stringify({ok:true,objects:result});
}
