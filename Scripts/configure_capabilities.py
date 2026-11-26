"""Configure owner-provided public signing identifiers; no certificates or passwords are stored."""
import argparse,json,re,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--team-id',required=True)
p.add_argument('--bundle-id',required=True)
p.add_argument('--game-center',action='store_true')
args=p.parse_args()
if not re.fullmatch(r'[A-Z0-9]{10}',args.team_id):p.error('Team ID must contain 10 uppercase letters/digits')
if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+',args.bundle_id):p.error('Invalid bundle identifier')
(root/'Configuration/Capabilities.json').write_text(json.dumps(dict(bundleIdentifier=args.bundle_id,teamID=args.team_id,gameCenter=args.game_center),indent=2)+'\n')
subprocess.check_call([sys.executable,str(root/'Scripts/generate_project.py')])
