const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'..'),ios=path.join(root,'ios'),resources=path.join(ios,'Tourdy','Resources');
fs.mkdirSync(resources,{recursive:true});
function array(file,name){
  const source=fs.readFileSync(path.join(root,'js',file),'utf8');
  const start=source.indexOf('const '+name+'=['),end=source.indexOf('];',start)+2;
  if(start<0||end<2)throw Error('Missing destination data: '+name);
  const context={};vm.createContext(context);vm.runInContext(source.slice(start,end)+';this.rows='+name,context);
  return context.rows;
}
const places=[
  ...array('travel-korea.js','KR').map(x=>({id:x[0],name:x[1],region:x[2],world:'kr',latitude:x[3],longitude:x[4],cost:0,zone:0})),
  ...array('travel-world.js','NATIONS').map(x=>({id:x[0],name:x[1],region:x[2],world:'world',latitude:x[3],longitude:x[4],cost:0,zone:x[5]})),
  ...array('travel-space.js','SPACE').map(x=>({id:x[0],name:x[1],region:x[6],world:'space',latitude:0,longitude:0,cost:x[4],zone:x[3]}))
];
places.push(...array('travel-experience.js','SECK').map(x=>({id:x[0],name:x[1],region:x[2],world:'kr',latitude:x[3],longitude:x[4],cost:0,zone:0,gate:[x[5]],secret:true})));
places.push(...array('travel-experience.js','SECW').map(x=>({id:x[0],name:x[2],region:x[1],world:'world',latitude:x[3],longitude:x[4],cost:0,zone:0,gate:x[6].split(' '),secret:true})));
fs.writeFileSync(path.join(resources,'places.json'),JSON.stringify(places,null,2));
const experienceSource=fs.readFileSync(path.join(root,'js/travel-experience.js'),'utf8');
const routes=array('travel-experience.js','ROUTES');
const seasonal=experienceSource.match(/ROUTES\.push\(([\s\S]*?)\);/);
if(seasonal){const ctx={routes};vm.createContext(ctx);vm.runInContext('routes.push('+seasonal[1]+')',ctx);}
fs.writeFileSync(path.join(resources,'routes.json'),JSON.stringify(routes,null,2));
const mapSource=fs.readFileSync(path.join(root,'js/travel-map.js'),'utf8');
function mapData(name){const a=mapSource.indexOf('const '+name+'=')+name.length+7;return JSON.parse(mapSource.slice(a,mapSource.indexOf(';',a)));}
function polygons(svg){
  const tokens=svg.match(/[Mlz]|-?\d*\.?\d+(?:e[-+]?\d+)?/gi)||[];
  let i=0,x=0,y=0,command='',polygon=[];const result=[];
  while(i<tokens.length){
    if(/^[Mlz]$/i.test(tokens[i])){command=tokens[i++];if(command==='z'||command==='Z'){if(polygon.length>2)result.push(polygon);polygon=[];continue;}}
    if(i>=tokens.length)break;
    const dx=Number(tokens[i++]),dy=Number(tokens[i++]);if(!Number.isFinite(dx)||!Number.isFinite(dy))throw Error('Invalid map point');
    if(command==='M'){if(polygon.length>2)result.push(polygon);polygon=[];x=dx;y=dy;command='L';}
    else if(command==='l'){x+=dx;y+=dy;}else if(command==='L'){x=dx;y=dy;}else throw Error('Unsupported map command '+command);
    polygon.push([x,y]);
  }
  if(polygon.length>2)result.push(polygon);return result;
}
const km=mapData('KMAP'),wm=mapData('WMAP'),kc=mapData('KCITY'),dots={};
for(const p of places){
  if(p.world==='kr')dots[p.id]=[(p.longitude-km.L0)*km.KX*km.K,(km.P0-p.latitude)*km.K];
  if(p.world==='world'){
    const r=Math.PI/180,M=Math.sqrt(3)/2,la=(((p.longitude-150)%360+540)%360-180)*r,l=Math.asin(M*Math.sin(p.latitude*r)),l2=l*l,l6=l2*l2*l2;
    dots[p.id]=[la*Math.cos(l)/(M*(1.340264+3*(-.081106)*l2+l6*(7*.000893+9*.003796*l2)))*wm.s+wm.tx,-l*(1.340264-.081106*l2+l6*(.000893+.003796*l2))*wm.s+wm.ty];
  }
}
const atlas={kr:{bounds:[-69,0,456,342],regions:kc.city.map(([id,d])=>({id,polygons:polygons(d)}))},world:{bounds:[0,268,1000,464],regions:wm.p.map(([id,d],i)=>({id:id||'region-'+i,polygons:polygons(d)}))},dots};
fs.writeFileSync(path.join(resources,'atlas.json'),JSON.stringify(atlas));
const project=path.join(ios,'Tourdy.xcodeproj');fs.mkdirSync(project,{recursive:true});
// Stable IDs keep generated project diffs reviewable; resources use a folder reference.
const id=n=>String(n).padStart(24,'0');
const configs=(owner,extra)=>[20,21].map((n,i)=>`${id(owner+n)} = {isa = XCBuildConfiguration; buildSettings = {${extra}}; name = ${i?'Release':'Debug'};};`).join('\n');
fs.writeFileSync(path.join(project,'project.pbxproj'),`// !$*UTF8*$!
{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {
${id(1)} = {isa = PBXProject; attributes = {LastUpgradeCheck = 2600;}; buildConfigurationList = ${id(10)}; compatibilityVersion = "Xcode 14.0"; developmentRegion = ko; knownRegions = (ko, en, Base); mainGroup = ${id(2)}; productRefGroup = ${id(3)}; projectDirPath = ""; projectRoot = ""; targets = (${id(4)},${id(40)});};
${id(2)} = {isa = PBXGroup; children = (${id(5)},${id(6)},${id(15)},${id(17)},${id(19)},${id(21)},${id(23)},${id(43)},${id(3)}); sourceTree = "<group>";};
${id(3)} = {isa = PBXGroup; children = (${id(7)},${id(41)}); name = Products; sourceTree = "<group>";};
${id(4)} = {isa = PBXNativeTarget; buildConfigurationList = ${id(11)}; buildPhases = (${id(8)},${id(9)}); buildRules = (); dependencies = (); name = Tourdy; productName = Tourdy; productReference = ${id(7)}; productType = "com.apple.product-type.application";};
${id(5)} = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tourdy/NativeApp.swift; sourceTree = "<group>";};
${id(6)} = {isa = PBXFileReference; lastKnownFileType = text.json; path = Tourdy/Resources/places.json; sourceTree = "<group>";};
${id(7)} = {isa = PBXFileReference; explicitFileType = wrapper.application; path = Tourdy.app; sourceTree = BUILT_PRODUCTS_DIR;};
${id(8)} = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${id(12)},${id(16)},${id(18)},${id(20)}); runOnlyForDeploymentPostprocessing = 0;};
${id(9)} = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (${id(13)},${id(22)},${id(24)}); runOnlyForDeploymentPostprocessing = 0;};
${id(15)} = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tourdy/ExperienceModel.swift; sourceTree = "<group>";};
${id(16)} = {isa = PBXBuildFile; fileRef = ${id(15)};};
${id(17)} = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tourdy/ExperienceUI.swift; sourceTree = "<group>";};
${id(18)} = {isa = PBXBuildFile; fileRef = ${id(17)};};
${id(19)} = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tourdy/ExperienceTravel.swift; sourceTree = "<group>";};
${id(20)} = {isa = PBXBuildFile; fileRef = ${id(19)};};
${id(21)} = {isa = PBXFileReference; lastKnownFileType = text.json; path = Tourdy/Resources/routes.json; sourceTree = "<group>";};
${id(22)} = {isa = PBXBuildFile; fileRef = ${id(21)};};
${id(23)} = {isa = PBXFileReference; lastKnownFileType = text.json; path = Tourdy/Resources/atlas.json; sourceTree = "<group>";};
${id(24)} = {isa = PBXBuildFile; fileRef = ${id(23)};};
${id(40)} = {isa = PBXNativeTarget; buildConfigurationList = ${id(47)}; buildPhases = (${id(45)}); buildRules = (); dependencies = (${id(48)}); name = TourdyNativeTests; productName = TourdyNativeTests; productReference = ${id(41)}; productType = "com.apple.product-type.bundle.unit-test";};
${id(41)} = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = TourdyNativeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;};
${id(43)} = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tests/TourdyNativeTests.swift; sourceTree = SOURCE_ROOT;};
${id(44)} = {isa = PBXBuildFile; fileRef = ${id(43)};};
${id(45)} = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${id(44)}); runOnlyForDeploymentPostprocessing = 0;};
${id(47)} = {isa = XCConfigurationList; buildConfigurations = (${id(320)},${id(321)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;};
${id(48)} = {isa = PBXTargetDependency; target = ${id(4)}; targetProxy = ${id(49)};};
${id(49)} = {isa = PBXContainerItemProxy; containerPortal = ${id(1)}; proxyType = 1; remoteGlobalIDString = ${id(4)}; remoteInfo = Tourdy;};
${id(12)} = {isa = PBXBuildFile; fileRef = ${id(5)};};
${id(13)} = {isa = PBXBuildFile; fileRef = ${id(6)};};
${id(10)} = {isa = XCConfigurationList; buildConfigurations = (${id(120)},${id(121)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
${id(11)} = {isa = XCConfigurationList; buildConfigurations = (${id(220)},${id(221)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
${configs(100,'SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 26.0; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES; ENABLE_TESTABILITY = YES;')}
${configs(200,'PRODUCT_BUNDLE_IDENTIFIER = com.example.tourdy; PRODUCT_NAME = "$(TARGET_NAME)"; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_CFBundleDisplayName = TOURDY; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic; MARKETING_VERSION = 0.1.0; CURRENT_PROJECT_VERSION = 1; SWIFT_VERSION = 5.0;')}
${configs(300,'PRODUCT_BUNDLE_IDENTIFIER = com.example.tourdy.tests; PRODUCT_NAME = "$(TARGET_NAME)"; GENERATE_INFOPLIST_FILE = YES; TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic; SWIFT_VERSION = 5.0; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Tourdy.app/Tourdy"; BUNDLE_LOADER = "$(TEST_HOST)";')}
}; rootObject = ${id(1)}; }
`);
console.log('iOS project prepared: ios/Tourdy.xcodeproj');
const schemeDir=path.join(project,'xcshareddata','xcschemes');fs.mkdirSync(schemeDir,{recursive:true});
const ref=(target,name)=>`<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${id(target)}" BuildableName="${name}" BlueprintName="${name.replace(/\.(app|xctest)$/,'')}" ReferencedContainer="container:Tourdy.xcodeproj"/>`;
fs.writeFileSync(path.join(schemeDir,'Tourdy.xcscheme'),`<?xml version="1.0" encoding="UTF-8"?><Scheme LastUpgradeVersion="2600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">${ref(4,'Tourdy.app')}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">${ref(40,'TourdyNativeTests.xctest')}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">${ref(4,'Tourdy.app')}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">${ref(4,'Tourdy.app')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>`);
