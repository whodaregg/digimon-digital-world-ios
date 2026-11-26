"""Generate a deterministic, dependency-free Xcode project for the iOS application."""
from pathlib import Path
import hashlib
import json
import plistlib

ROOT=Path(__file__).resolve().parents[1]
capabilities=json.loads((ROOT/'Configuration/Capabilities.json').read_text())
assert not capabilities['gameCenter'] or capabilities['teamID'],'Game Center requires an Apple developer team'
PROJECT=ROOT/'DigitalWorld.xcodeproj'
PROJECT.mkdir(exist_ok=True)

def uid(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def q(value): return json.dumps(str(value))
objects=[]
def obj(name, body):
    objects.append(f'{uid(name)} = {{ {body} }};')
    return uid(name)
def refs(names): return '('+','.join(uid(n) for n in names)+',)'

app_files=sorted(str(p.relative_to(ROOT)) for p in (ROOT/'iOS').rglob('*.swift'))
test_files=sorted(str(p.relative_to(ROOT)) for p in (ROOT/'iOSUITests').rglob('*.swift'))
for file in app_files+test_files:
    obj('ref:'+file,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(file)}; sourceTree = SOURCE_ROOT;')
    obj('build:'+file,f'isa = PBXBuildFile; fileRef = {uid("ref:"+file)};')
resources=['iOS/Resources/Assets.xcassets','iOS/Resources/PrivacyInfo.xcprivacy'] + sorted(str(p.relative_to(ROOT)) for p in (ROOT/'iOS/Resources/Fonts').glob('*.ttf')) + ['iOS/Resources/FontLicenses']
for file in resources:
    filetype='folder.assetcatalog' if file.endswith('xcassets') else 'file' if file.endswith('ttf') else 'folder' if file.endswith('FontLicenses') else 'text.xml'
    obj('ref:'+file,f'isa = PBXFileReference; lastKnownFileType = {filetype}; path = {q(file)}; sourceTree = SOURCE_ROOT;')
    obj('build:'+file,f'isa = PBXBuildFile; fileRef = {uid("ref:"+file)};')
privacy_strings={
    'zh-Hans':('用于发现附近玩家，并在双方确认后进行本地对战。','仅在主动开始Sandbox摇晃输入测试时读取加速度，数据不上传。'),
    'zh-Hant':('用於尋找附近玩家，並在雙方確認後進行本機對戰。','僅在主動開始Sandbox搖晃輸入測試時讀取加速度，資料不會上傳。'),
    'en':('Find nearby players and battle after both players confirm.','Read acceleration only during Sandbox motion input testing. Motion data is not uploaded.'),
    'ja':('近くのプレイヤーを検索し、双方の確認後に対戦します。','Sandboxの振動入力テスト中のみ加速度を読み取ります。データは送信しません。')}
localized_refs=[]
for language,strings in privacy_strings.items():
    path=f'iOS/Resources/{language}.lproj/InfoPlist.strings'
    file=ROOT/path;file.parent.mkdir(exist_ok=True)
    file.write_text('\n'.join(json.dumps(key)+' = '+json.dumps(value,ensure_ascii=False)+';' for key,value in zip(['NSLocalNetworkUsageDescription','NSMotionUsageDescription'],strings))+'\n')
    localized_refs.append('ref:'+path)
    obj('ref:'+path,f'isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = {q(language)}; path = {q(path)}; sourceTree = SOURCE_ROOT;')
obj('ref:localization',f'isa = PBXVariantGroup; children = {refs(localized_refs)}; name = InfoPlist.strings; sourceTree = "<group>";')
obj('build:localization',f'isa = PBXBuildFile; fileRef = {uid("ref:localization")};')
obj('product:app','isa = PBXFileReference; explicitFileType = wrapper.application; path = DigitalWorld.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('product:uitest','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = DigitalWorldUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj('group:app',f'isa = PBXGroup; name = iOS; children = {refs(["ref:"+f for f in app_files+resources])}; sourceTree = "<group>";')
obj('group:tests',f'isa = PBXGroup; name = UITests; children = {refs(["ref:"+f for f in test_files])}; sourceTree = "<group>";')
obj('group:products',f'isa = PBXGroup; name = Products; children = {refs(["product:app","product:uitest"])}; sourceTree = "<group>";')
obj('group:main',f'isa = PBXGroup; children = {refs(["group:app","group:tests","group:products"])}; sourceTree = "<group>";')
obj('package','isa = XCLocalSwiftPackageReference; relativePath = ".";')
obj('package:core',f'isa = XCSwiftPackageProductDependency; package = {uid("package")}; productName = DigitalWorldCore;')
obj('build:core',f'isa = PBXBuildFile; productRef = {uid("package:core")};')
for kind,files in [('app',app_files),('uitest',test_files)]:
    obj(f'sources:{kind}',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {refs(["build:"+f for f in files])}; runOnlyForDeploymentPostprocessing = 0;')
    resource_refs=refs(['build:'+f for f in resources]+['build:localization']) if kind=='app' else '()'
    obj(f'resources:{kind}',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {resource_refs}; runOnlyForDeploymentPostprocessing = 0;')
    framework_refs=refs(['build:core']) if kind=='app' else '()'
    obj(f'frameworks:{kind}',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {framework_refs}; runOnlyForDeploymentPostprocessing = 0;')
obj('proxy',f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("target:app")}; remoteInfo = DigitalWorld;')
obj('dependency',f'isa = PBXTargetDependency; target = {uid("target:app")}; targetProxy = {uid("proxy")};')

def settings(values): return '{ '+' '.join(f'{k} = {q(v)};' for k,v in values.items())+' }'
for config in ['Debug','Release']:
    common=dict(ALWAYS_SEARCH_USER_PATHS='NO', CLANG_ENABLE_MODULES='YES', CLANG_ENABLE_OBJC_ARC='YES',
                IPHONEOS_DEPLOYMENT_TARGET='17.0', SDKROOT='iphoneos', SWIFT_VERSION='5.0',
                ENABLE_USER_SCRIPT_SANDBOXING='YES', GCC_C_LANGUAGE_STANDARD='gnu17',
                DEBUG_INFORMATION_FORMAT='dwarf' if config=='Debug' else 'dwarf-with-dsym',
                SWIFT_OPTIMIZATION_LEVEL='-Onone' if config=='Debug' else '-O',
                ENABLE_TESTABILITY='YES' if config=='Debug' else 'NO',
                ONLY_ACTIVE_ARCH='YES' if config=='Debug' else 'NO',
                SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG' if config=='Debug' else '',
                GCC_PREPROCESSOR_DEFINITIONS='DEBUG=1 $(inherited)' if config=='Debug' else '$(inherited)')
    obj('config:project:'+config,f'isa = XCBuildConfiguration; buildSettings = {settings(common)}; name = {config};')
    for target in ['app','uitest']:
        values=dict(PRODUCT_NAME='$(TARGET_NAME)',PRODUCT_BUNDLE_IDENTIFIER=capabilities['bundleIdentifier']+('.uitests' if target=='uitest' else ''),
                    CURRENT_PROJECT_VERSION='7',MARKETING_VERSION='0.7.0',CODE_SIGN_STYLE='Automatic',
                    TARGETED_DEVICE_FAMILY='1,2',SWIFT_EMIT_LOC_STRINGS='YES',
                    SUPPORTED_PLATFORMS='iphoneos iphonesimulator',SUPPORTS_MACCATALYST='NO')
        if target=='app':
            if capabilities['teamID']: values['DEVELOPMENT_TEAM']=capabilities['teamID']
            if capabilities['gameCenter']: values['CODE_SIGN_ENTITLEMENTS']='iOS/Resources/DigitalWorld.entitlements'
            values.update(INFOPLIST_FILE='iOS/Resources/Info.plist',GENERATE_INFOPLIST_FILE='NO',
                          ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME='AccentColor',
                          LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks')
        else:
            values.update(GENERATE_INFOPLIST_FILE='YES',TEST_TARGET_NAME='DigitalWorld',
                          LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks @loader_path/Frameworks')
        obj('config:'+target+':'+config,f'isa = XCBuildConfiguration; buildSettings = {settings(values)}; name = {config};')
for target in ['project','app','uitest']:
    obj('configs:'+target,f'isa = XCConfigurationList; buildConfigurations = {refs(["config:"+target+":"+c for c in ["Debug","Release"]])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
for target,name in [('app','DigitalWorld'),('uitest','DigitalWorldUITests')]:
    dependencies=refs(['dependency']) if target=='uitest' else '()'
    products=refs(['package:core']) if target=='app' else '()'
    obj('target:'+target,f'''isa = PBXNativeTarget; buildConfigurationList = {uid("configs:"+target)};
        buildPhases = {refs(["sources:"+target,"frameworks:"+target,"resources:"+target])}; buildRules = ();
        dependencies = {dependencies}; name = {name}; productName = {name};
        packageProductDependencies = {products}; productReference = {uid("product:"+target)};
        productType = {q('com.apple.product-type.application' if target=='app' else 'com.apple.product-type.bundle.ui-testing')};''')
obj('project',f'''isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600;
    TargetAttributes = {{ {uid("target:app")} = {{ CreatedOnToolsVersion = 16.0; }};
    {uid("target:uitest")} = {{ CreatedOnToolsVersion = 16.0; TestTargetID = {uid("target:app")}; }}; }}; }};
    buildConfigurationList = {uid("configs:project")}; compatibilityVersion = "Xcode 14.0";
    developmentRegion = "zh-Hans"; hasScannedForEncodings = 0; knownRegions = (en,"zh-Hans","zh-Hant",ja,Base);
    mainGroup = {uid("group:main")}; productRefGroup = {uid("group:products")};
    packageReferences = {refs(["package"])}; projectDirPath = ""; projectRoot = "";
    targets = {refs(["target:app","target:uitest"])};''')
(PROJECT/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+
    '\n'.join(objects)+'\n}; rootObject = '+uid('project')+'; }\n')
schemes=PROJECT/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
def buildable(target,name,product):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+target)}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:DigitalWorld.xcodeproj"/>'
app=buildable('app','DigitalWorld','DigitalWorld.app')
tests=buildable('uitest','DigitalWorldUITests','DigitalWorldUITests.xctest')
(schemes/'DigitalWorld.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
<Testables><TestableReference skipped="NO">{tests}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
<BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')

plist=dict(CFBundleDevelopmentRegion='zh-Hans',CFBundleDisplayName='Digital World',
    CFBundleExecutable='$(EXECUTABLE_NAME)',CFBundleIdentifier='$(PRODUCT_BUNDLE_IDENTIFIER)',
    CFBundleInfoDictionaryVersion='6.0',CFBundleName='$(PRODUCT_NAME)',CFBundlePackageType='APPL',
    CFBundleShortVersionString='$(MARKETING_VERSION)',CFBundleVersion='$(CURRENT_PROJECT_VERSION)',
    UIAppFonts=[p.name for p in sorted((ROOT/'iOS/Resources/Fonts').glob('*.ttf'))],
    NSLocalNetworkUsageDescription='用于发现附近玩家，并在双方确认后进行本地对战。',
    NSBonjourServices=['_world-pets._tcp'],
    NSMotionUsageDescription='仅在主动开始Sandbox摇晃输入测试时读取加速度，数据不上传。',
    GameCenterEnabled=capabilities['gameCenter'],
    LSRequiresIPhoneOS=True,UIApplicationSceneManifest=dict(UIApplicationSupportsMultipleScenes=False),
    UILaunchScreen={},UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait'],
    **{'UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight']})
resources_dir=ROOT/'iOS/Resources'
(resources_dir/'Info.plist').write_bytes(plistlib.dumps(plist))
(resources_dir/'DigitalWorld.entitlements').write_bytes(plistlib.dumps({'com.apple.developer.game-center':True} if capabilities['gameCenter'] else {}))
(resources_dir/'PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps(dict(NSPrivacyTracking=False,
    NSPrivacyTrackingDomains=[],NSPrivacyCollectedDataTypes=[],NSPrivacyAccessedAPITypes=[])))
print(f'Generated DigitalWorld.xcodeproj: {len(app_files)} app sources, {len(test_files)} UI test sources.')
