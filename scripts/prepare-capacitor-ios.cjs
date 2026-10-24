const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const app=path.join(root,'capacitor/ios/App');
const xcode=require(require.resolve('xcode',{paths:[path.dirname(require.resolve('@capacitor/cli/package.json'))]}));
const project=xcode.project(path.join(app,'App.xcodeproj/project.pbxproj'));
project.parseSync();
const group=project.findPBXGroupKey({path:'App'});
for(const name of ['TourdyRecordsPlugin.swift','TourdyBridgeViewController.swift']){
  fs.copyFileSync(path.join(root,'native/ios',name),path.join(app,'App',name));
  if(!project.hasFile(name))project.addSourceFile(name,{target:'504EC3031FED79650016851F'},group);
}
fs.writeFileSync(path.join(app,'App.xcodeproj/project.pbxproj'),project.writeSync());
const scene=path.join(app,'App/SceneDelegate.swift');
fs.writeFileSync(scene,fs.readFileSync(scene,'utf8').replace('= CAPBridgeViewController()','= TourdyBridgeViewController()'));
const storyboard=path.join(app,'App/Base.lproj/Main.storyboard');
fs.writeFileSync(storyboard,fs.readFileSync(storyboard,'utf8').replace('customClass="CAPBridgeViewController" customModule="Capacitor"','customClass="TourdyBridgeViewController" customModule="App"'));
const packageFile=path.join(app,'CapApp-SPM/Package.swift');
let packageSource=fs.readFileSync(packageFile,'utf8');
for(const [name,product] of [['app','App'],['filesystem','Filesystem'],['haptics','Haptics'],['local-notifications','LocalNotifications'],['share','Share']]){
  const source=path.dirname(require.resolve('@capacitor/'+name+'/package.json'));
  const destination=path.join(root,'capacitor/vendor',name);
  fs.mkdirSync(destination,{recursive:true});
  fs.cpSync(source,destination,{recursive:true,filter:p=>path.basename(p)!=='node_modules'});
  packageSource=packageSource.replace(new RegExp('(name: "Capacitor'+product+'", path: ")[^"]+'), '$1../../../vendor/'+name);
}
fs.writeFileSync(packageFile,packageSource);
console.log('Capacitor iOS plugin registration and portable dependencies prepared.');
