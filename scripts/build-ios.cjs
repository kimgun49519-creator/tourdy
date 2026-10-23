const fs=require('node:fs');
const path=require('node:path');
const root=path.join(__dirname,'..'),ios=path.join(root,'ios'),web=path.join(ios,'Tourdy','Web');
fs.mkdirSync(web,{recursive:true});
let html=fs.readFileSync(path.join(root,'index.html'),'utf8');
// All app resources ship in the installation. No service worker or remote font dependency.
html=html.replace(/<link[^>]+(?:fonts\.googleapis\.com|fonts\.gstatic\.com)[^>]*>/g,'').replace('<script src="js/pwa.js"></script>','');
fs.writeFileSync(path.join(web,'index.html'),html);
for(const dir of ['js','css'])fs.cpSync(path.join(root,dir),path.join(web,dir),{recursive:true});
for(const file of ['manifest.webmanifest','icon-192.png','icon-512.png','icon-maskable-512.png','apple-touch-icon.png','favicon-64.png'])fs.copyFileSync(path.join(root,file),path.join(web,file));
fs.copyFileSync(path.join(ios,'native-bridge.js'),path.join(web,'native-bridge.js'));
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
${id(5)} = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tourdy/TourdyApp.swift; sourceTree = "<group>";};
${id(6)} = {isa = PBXFileReference; lastKnownFileType = folder; path = Tourdy/Web; sourceTree = "<group>";};
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
