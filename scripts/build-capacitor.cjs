const fs=require('node:fs');
const path=require('node:path');
const esbuild=require('esbuild');
const root=path.join(__dirname,'..'),out=path.join(root,'native-dist');
async function build(){
  fs.mkdirSync(path.join(out,'native'),{recursive:true});
  for(const dir of ['css','js'])fs.cpSync(path.join(root,dir),path.join(out,dir),{recursive:true});
  for(const file of ['manifest.webmanifest','icon-192.png','icon-512.png','icon-maskable-512.png','apple-touch-icon.png','favicon-64.png'])fs.copyFileSync(path.join(root,file),path.join(out,file));
  let html=fs.readFileSync(path.join(root,'index.html'),'utf8');
  const scripts=[];
  html=html.replace(/<script src="(js\/[^\"]+)"><\/script>/g,(_,src)=>{if(src!=='js/pwa.js')scripts.push(src);return '';});
  // Keep the exact original markup and stylesheet. Bundle fonts separately later;
  // the existing system font fallback keeps the entire app usable offline.
  html=html.replace(/<link[^>]+(?:fonts\.googleapis\.com|fonts\.gstatic\.com)[^>]*>/g,'');
  html=html.replace('</body>','<script>window.TOURDY_APP_SCRIPTS='+JSON.stringify(scripts)+'</script><script src="native/bridge.js"></script></body>');
  fs.writeFileSync(path.join(out,'index.html'),html);
  await esbuild.build({entryPoints:[path.join(root,'native/bridge-entry.js')],outfile:path.join(out,'native/bridge.js'),bundle:true,format:'iife',target:'safari16',minify:false});
  console.log('Original TOURDY assets bundled for Capacitor: '+out);
}
if(require.main===module)build().catch(error=>{console.error(error);process.exitCode=1;});
module.exports={build};
