from pathlib import Path
import plistlib

root = Path(__file__).resolve().parents[1]

# Android: network access + arbitrary user-configured local HTTP MCP endpoints.
manifest = root / 'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text(encoding='utf-8')
needle = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
if 'android.permission.INTERNET' not in text:
    text = text.replace(
        needle,
        needle
        + '\n    <uses-permission android:name="android.permission.INTERNET" />'
        + '\n    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />',
    )
if 'android:usesCleartextTraffic=' not in text:
    text = text.replace('<application', '<application\n        android:usesCleartextTraffic="true"', 1)
# Keep the generated application class/name, only change the visible label.
text = text.replace('android:label="tavolink"', 'android:label="TavoLink · 云昭"')
manifest.write_text(text, encoding='utf-8')

# iOS: local network is needed for LAN Tavo MCP servers; ATS still keeps
# ordinary internet traffic under the platform's HTTPS policy.
plist_path = root / 'ios/Runner/Info.plist'
with plist_path.open('rb') as f:
    plist = plistlib.load(f)
plist['CFBundleDisplayName'] = 'TavoLink · 云昭'
plist['NSLocalNetworkUsageDescription'] = 'TavoLink 需要访问本地网络，以连接你主动配置的 Tavo MCP 服务器。'
ats = dict(plist.get('NSAppTransportSecurity') or {})
ats['NSAllowsLocalNetworking'] = True
plist['NSAppTransportSecurity'] = ats
with plist_path.open('wb') as f:
    plistlib.dump(plist, f, sort_keys=False)

print('[TavoLink] Android/iOS permissions and display names patched')
