#!/usr/bin/env python3
from pathlib import Path
import json, os, platform, shutil, subprocess, sys, time

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / 'test-results'
RESULTS.mkdir(exist_ok=True)
rows = []

def run(name, cmd, required=True, timeout=180):
    start = time.time()
    try:
        cp = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
        out = (cp.stdout + ('\n' + cp.stderr if cp.stderr else '')).strip()
        status = 'PASS' if cp.returncode == 0 else 'FAIL'
        rows.append({'name': name, 'status': status, 'seconds': round(time.time()-start, 2), 'command': cmd, 'output': out[-12000:]})
        return cp.returncode == 0
    except Exception as e:
        rows.append({'name': name, 'status': 'FAIL' if required else 'BLOCKED', 'seconds': round(time.time()-start, 2), 'command': cmd, 'output': str(e)})
        return False

def blocked(name, reason):
    rows.append({'name': name, 'status': 'BLOCKED', 'seconds': 0, 'command': [], 'output': reason})

run('Source self-check', ['python3', 'tool/source_selfcheck.py'])
run('HTTP protocol contracts', ['python3', 'tool/runtime_contract_test.py'])
run('Learning contracts', ['python3', 'tool/learning_contract_test.py'])

flutter = shutil.which('flutter')
xcode = shutil.which('xcodebuild')
if flutter:
    run('Flutter platform bootstrap', ['bash', 'tool/bootstrap_platforms.sh'], timeout=300)
    run('Flutter analyze', [flutter, 'analyze'], timeout=300)
    run('Flutter tests', [flutter, 'test'], timeout=300)
    ok = run('Android release APK build', [flutter, 'build', 'apk', '--release'], timeout=900)
    if ok:
        apk = ROOT/'build/app/outputs/flutter-apk/app-release.apk'
        if apk.exists():
            target = ROOT/'TavoLink-YunZhao-v1.1.0.apk'
            shutil.copy2(apk, target)
            rows.append({'name': 'Android APK artifact', 'status': 'PASS', 'seconds': 0, 'command': [], 'output': str(target)})
        else:
            rows.append({'name': 'Android APK artifact', 'status': 'FAIL', 'seconds': 0, 'command': [], 'output': 'flutter reported success but APK was not found'})
else:
    blocked('Flutter analyze / tests', 'Flutter SDK is not installed in this execution environment.')
    blocked('Android release APK build', 'Flutter SDK and Android SDK are not installed; external downloads are unavailable from the container.')

if platform.system() == 'Darwin' and flutter and xcode:
    ok = run('iOS release no-codesign build', [flutter, 'build', 'ios', '--release', '--no-codesign'], timeout=1200)
    if ok:
        app = ROOT/'build/ios/iphoneos/Runner.app'
        if app.exists():
            payload = ROOT/'build/final_ipa/Payload'
            if payload.parent.exists(): shutil.rmtree(payload.parent)
            payload.mkdir(parents=True)
            shutil.copytree(app, payload/'Runner.app')
            ipa = ROOT/'TavoLink-YunZhao-v1.1.0-unsigned.ipa'
            if ipa.exists(): ipa.unlink()
            subprocess.run(['zip','-qry',str(ipa),'Payload'], cwd=payload.parent, check=True)
            rows.append({'name': 'Unsigned IPA artifact', 'status': 'PASS', 'seconds': 0, 'command': [], 'output': str(ipa)})
else:
    blocked('iOS release / IPA build', 'IPA compilation requires macOS + Xcode. Current host is %s and xcodebuild=%s.' % (platform.system(), bool(xcode)))

summary = {
    'version': '1.1.0+2',
    'host': {'system': platform.system(), 'release': platform.release(), 'machine': platform.machine()},
    'toolchains': {x: shutil.which(x) for x in ['flutter','dart','java','sdkmanager','adb','xcodebuild']},
    'results': rows,
}
(RESULTS/'final_test.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2))

lines = ['# TavoLink 云昭 v1.1 最终测试报告', '', f'- Host: `{platform.system()} {platform.release()} {platform.machine()}`', '- Version: `1.1.0+2`', '']
for r in rows:
    lines.append(f"- **{r['status']}** — {r['name']}")
    if r['status'] != 'PASS': lines.append(f"  - {r['output']}")
(RESULTS/'FINAL_TEST_REPORT.md').write_text('\n'.join(lines) + '\n')

for r in rows:
    print(f"{r['status']:<8} {r['name']}")
print('\nReport:', RESULTS/'FINAL_TEST_REPORT.md')
# Return failure only for actual FAIL, not environment BLOCKED.
sys.exit(1 if any(r['status']=='FAIL' for r in rows) else 0)
