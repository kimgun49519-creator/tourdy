const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');

function buildPreview() {
  let html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const bootstrap = `window.TOURDY_TEST_STORAGE=(()=>{const data=new Map();return{failed:false,getItem:key=>data.get(key)??null,setItem(key,value){if(this.failed)throw new DOMException('Test quota failure','QuotaExceededError');data.set(key,String(value))},removeItem:key=>data.delete(key),clear:()=>data.clear(),key:index=>[...data.keys()][index]??null,get length(){return data.size}}})();
  window.TOURDY_TEST_STORAGE.setItem('studyplanner.v2',JSON.stringify({subjects:[{id:'test-math',name:'수학',color:'#0090FF',icon:'fx',goal:0},{id:'test-english',name:'영어',color:'#30A46C',icon:'globe',goal:0}],sessions:[],running:null,tasks:{},repeats:[],welcome:false,notify:{sound:false,memo:false}}));`;
  html = html.replace('<head>', '<head>\n<script>' + bootstrap + '</script>');
  html = html.replace('<title>투어디 TOURDY</title>', '<title>TOURDY · 테스트</title>');
  html = html.replace(/<link rel="manifest"[^>]+>/g, '');
  html = html.replace(/<link rel="(?:apple-touch-icon|icon)"[^>]+>/g, '');
  html = html.replace('<link rel="stylesheet" href="css/app.css">', () => '<style>' + fs.readFileSync(path.join(root, 'css/app.css'), 'utf8') + '\n.test-controls{padding:16px}.test-actions{display:flex;flex-wrap:wrap;gap:8px}.test-actions button{min-height:38px}.test-controls .panel-head h2{font-size:18px}</style>');
  html = html.replace(/<script src="(js\/[^\"]+)"><\/script>/g, (_, file) => {
    if (file === 'js/pwa.js') return '';
    let code = fs.readFileSync(path.join(root,file),'utf8');
    code = code.replace(/\blocalStorage\b/g, 'window.TOURDY_TEST_STORAGE').replace('const TRAVEL_TEST=false', 'const TRAVEL_TEST=true');
    return '<script>\n' + code.replace(/<\/script/gi, '<\\/script') + '\n</script>';
  });
  html = html.replace('</body>', () => '<script>\n' + fs.readFileSync(path.join(root,'js/test-mode.js'),'utf8') + '\n</script>\n</body>');
  return html;
}

function buildInline(html) {
  const data = JSON.stringify(html).replace(/<\/script/gi,'<\\/script');
  return `<div id="tourdy-test-viewer"><iframe id="tourdy-test-frame" title="TOURDY 테스트 앱" sandbox="allow-scripts allow-modals allow-downloads" referrerpolicy="no-referrer" style="display:block;width:100%;height:860px;border:0"></iframe></div>
<script>
(()=>{
  const root=document.getElementById('tourdy-test-viewer'),frame=root.querySelector('iframe');
  const saved=window.openai?.widgetState;
  let lastView=saved?.privateContent?.view||'home';
  window.addEventListener('message',event=>{
    if(event.source!==frame.contentWindow||event.data?.type!=='tourdy-preview-state')return;
    if(event.data.view===lastView)return;lastView=event.data.view;
    window.openai?.setWidgetState({modelContent:{screen:event.data.view,reward:event.data.reward},privateContent:{view:lastView}}).catch(()=>{});
  });
  window.addEventListener('openai:set_globals',event=>{const view=event.detail?.globals?.widgetState?.privateContent?.view;if(view){lastView=view;frame.contentWindow.postMessage({type:'tourdy-preview-restore',view},'*')}});
  frame.addEventListener('load',()=>frame.contentWindow.postMessage({type:'tourdy-preview-restore',view:lastView},'*'));
  frame.srcdoc=${data};
})();
</script>
`;
}

if (require.main === module) {
  const output = path.resolve(process.argv[2] || path.join(root,'.preview/tourdy-test.html'));
  const html = buildPreview();fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,html);
  console.log(output);
  if(process.argv[3]){const inline=path.resolve(process.argv[3]);fs.mkdirSync(path.dirname(inline),{recursive:true});fs.writeFileSync(inline,buildInline(html));console.log(inline);}
}
module.exports = { buildPreview, buildInline };
