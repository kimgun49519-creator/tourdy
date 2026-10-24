const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),app=path.join(root,'capacitor/ios/App');
const xcode=require(require.resolve('xcode',{paths:[path.dirname(require.resolve('@capacitor/cli/package.json'))]}));
const project=xcode.project(path.join(app,'App.xcodeproj/project.pbxproj'));project.parseSync();
const appId='504EC3031FED79650016851F',mainTarget=project.pbxNativeTargetSection()[appId];
const oldDependencies=[...mainTarget.dependencies];
const target=project.addTarget('TourdyNavigationTests','unit_test_bundle','UITests','com.example.tourdy.navigationtests');
mainTarget.dependencies=oldDependencies;
target.pbxNativeTarget.productType='"com.apple.product-type.bundle.ui-testing"';
project.addTargetDependency(target.uuid,[appId]);
project.addBuildPhase([],'PBXSourcesBuildPhase','Sources',target.uuid);
const group=project.addPbxGroup([],'UITests','UITests');
project.addToPbxGroup(group.uuid,project.getFirstProject().firstProject.mainGroup);
fs.mkdirSync(path.join(app,'UITests'),{recursive:true});
fs.copyFileSync(path.join(root,'native/ios/NavigationUITests.swift'),path.join(app,'UITests/NavigationUITests.swift'));
project.addSourceFile('NavigationUITests.swift',{target:target.uuid},group.uuid);
const configs=project.pbxXCBuildConfigurationSection();
for(const config of Object.values(configs))if(config?.buildSettings?.PRODUCT_NAME==='"TourdyNavigationTests"'){
  Object.assign(config.buildSettings,{GENERATE_INFOPLIST_FILE:'YES',SWIFT_VERSION:'5.0',IPHONEOS_DEPLOYMENT_TARGET:'16.0',TARGETED_DEVICE_FAMILY:'"1,2"',TEST_TARGET_NAME:'App',CODE_SIGN_STYLE:'Automatic'});
  delete config.buildSettings.INFOPLIST_FILE;
}
fs.writeFileSync(path.join(app,'App.xcodeproj/project.pbxproj'),project.writeSync());
const schemeDir=path.join(app,'App.xcodeproj/xcshareddata/xcschemes');fs.mkdirSync(schemeDir,{recursive:true});
const ref=(id,name)=>`<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${id}" BuildableName="${name}" BlueprintName="${name.replace(/\.(app|xctest)$/,'')}" ReferencedContainer="container:App.xcodeproj"/>`;
fs.writeFileSync(path.join(schemeDir,'TourdyNavigationTests.xcscheme'),`<?xml version="1.0" encoding="UTF-8"?><Scheme version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">${ref(appId,'App.app')}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">${ref(target.uuid,'TourdyNavigationTests.xctest')}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB"><BuildableProductRunnable runnableDebuggingMode="0">${ref(appId,'App.app')}</BuildableProductRunnable></LaunchAction></Scheme>`);
