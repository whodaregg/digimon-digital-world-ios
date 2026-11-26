"""Verify runtime resource declarations that a successful Swift compile cannot detect."""
from pathlib import Path
import plistlib,json
root=Path(__file__).resolve().parents[1]
info=plistlib.loads((root/'iOS/Resources/Info.plist').read_bytes())
fonts=sorted(p.name for p in (root/'iOS/Resources/Fonts').glob('*.ttf'))
assert len(fonts)==3 and sorted(info.get('UIAppFonts',[]))==fonts,'Pixel fonts must be registered, not just copied'
project=(root/'DigitalWorld.xcodeproj/project.pbxproj').read_text()
for font in fonts: assert font in project, 'Missing font resource: '+font
assert info.get('NSBonjourServices')==['_world-pets._tcp']
assert info.get('NSLocalNetworkUsageDescription') and info.get('NSMotionUsageDescription')
capabilities=json.loads((root/'Configuration/Capabilities.json').read_text())
assert info.get('GameCenterEnabled')==capabilities['gameCenter']
assert not capabilities['gameCenter'] or capabilities['teamID'],'Unconfigured Game Center must stay disabled'
entitlements=plistlib.loads((root/'iOS/Resources/DigitalWorld.entitlements').read_bytes())
assert bool(entitlements.get('com.apple.developer.game-center'))==capabilities['gameCenter']
assert (root/'iOS/Resources/FontLicenses/FusionPixel-OFL.txt').is_file()
print('Validated pixel fonts, local-network/motion declarations and Game Center default')
