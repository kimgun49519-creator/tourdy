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
  ...array('travel-world.js','NATIONS').map(x=>({id:x[0],name:x[1],region:x[2],world:'world',latitude:x[3],longitude:x[4],cost:0,zone:0})),
  ...array('travel-space.js','SPACE').map(x=>({id:x[0],name:x[1],region:x[6],world:'space',latitude:0,longitude:0,cost:x[4],zone:x[3]}))
];
fs.writeFileSync(path.join(resources,'places.json'),JSON.stringify(places,null,2));
const project=path.join(ios,'Tourdy.xcodeproj');fs.mkdirSync(project,{recursive:true});
// Stable IDs keep generated project diffs reviewable; resources use a folder reference.
const id=n=>String(n).padStart(24,'0');
const configs=(owner,extra)=>[20,21].map((n,i)=>`${id(owner+n)} = {isa = XCBuildConfiguration; buildSettings = {${extra}}; name = ${i?'Release':'Debug'};};`).join('\n');
fs.writeFileSync(path.join(project,'project.pbxproj'),`// !$*UTF8*$!
{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {
${id(1)} = {isa = PBXProject; attributes = {LastUpgradeCheck = 2600;}; buildConfigurationList = ${id(10)}; compatibilityVersion = "Xcode 14.0"; developmentRegion = ko; knownRegions = (ko, en, Base); mainGroup = ${id(2)}; productRefGroup = ${id(3)}; projectDirPath = ""; projectRoot = ""; targets = (${id(4)});};
${id(2)} = {isa = PBXGroup; children = (${id(5)},${id(6)},${id(3)}); sourceTree = "<group>";};
${id(3)} = {isa = PBXGroup; children = (${id(7)}); name = Products; sourceTree = "<group>";};
${id(4)} = {isa = PBXNativeTarget; buildConfigurationList = ${id(11)}; buildPhases = (${id(8)},${id(9)}); buildRules = (); dependencies = (); name = Tourdy; productName = Tourdy; productReference = ${id(7)}; productType = "com.apple.product-type.application";};
${id(5)} = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tourdy/NativeApp.swift; sourceTree = "<group>";};
${id(6)} = {isa = PBXFileReference; lastKnownFileType = text.json; path = Tourdy/Resources/places.json; sourceTree = "<group>";};
${id(7)} = {isa = PBXFileReference; explicitFileType = wrapper.application; path = Tourdy.app; sourceTree = BUILT_PRODUCTS_DIR;};
${id(8)} = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${id(12)}); runOnlyForDeploymentPostprocessing = 0;};
${id(9)} = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (${id(13)}); runOnlyForDeploymentPostprocessing = 0;};
${id(12)} = {isa = PBXBuildFile; fileRef = ${id(5)};};
${id(13)} = {isa = PBXBuildFile; fileRef = ${id(6)};};
${id(10)} = {isa = XCConfigurationList; buildConfigurations = (${id(120)},${id(121)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
${id(11)} = {isa = XCConfigurationList; buildConfigurations = (${id(220)},${id(221)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;};
${configs(100,'SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 26.0; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES;')}
${configs(200,'PRODUCT_BUNDLE_IDENTIFIER = com.example.tourdy; PRODUCT_NAME = "$(TARGET_NAME)"; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_CFBundleDisplayName = TOURDY; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic; MARKETING_VERSION = 0.1.0; CURRENT_PROJECT_VERSION = 1; SWIFT_VERSION = 5.0;')}
}; rootObject = ${id(1)}; }
`);
console.log('iOS project prepared: ios/Tourdy.xcodeproj');
