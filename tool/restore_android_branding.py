from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
source = root / 'tool' / 'android_branding'
res = root / 'android' / 'app' / 'src' / 'main' / 'res'
for folder in ['mipmap-mdpi', 'mipmap-hdpi', 'mipmap-xhdpi', 'mipmap-xxhdpi', 'mipmap-xxxhdpi', 'mipmap-anydpi-v26', 'drawable', 'drawable-v21', 'values', 'values-v31', 'values-night-v31']:
    src = source / folder
    if src.exists():
        dst = res / folder
        dst.mkdir(parents=True, exist_ok=True)
        for item in src.iterdir():
            target = dst / item.name
            if item.is_dir():
                if target.exists(): shutil.rmtree(target)
                shutil.copytree(item, target)
            else:
                shutil.copy2(item, target)

manifest = root / 'android' / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
text = manifest.read_text()
if 'android.permission.INTERNET' not in text:
    text = text.replace('<application', '    <uses-permission android:name="android.permission.INTERNET" />\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n    <application', 1)
text = text.replace('android:label="zenvora"', 'android:label="Zenvora Mart"')
if '<queries>' not in text:
    text = text.replace('    <application', '    <queries>\n    </queries>\n    <application', 1)
if 'android.intent.action.VIEW' not in text:
    text = text.replace('    </queries>', '        <intent><action android:name=\"android.intent.action.VIEW\"/><data android:scheme=\"https\"/></intent>\n    </queries>')
if 'android.intent.action.DIAL' not in text:
    text = text.replace('    </queries>', '        <intent><action android:name=\"android.intent.action.DIAL\"/><data android:scheme=\"tel\"/></intent>\n    </queries>')
manifest.write_text(text)

firebase = root / 'android' / 'app' / 'google-services.json'
if (source / 'google-services.json').exists():
    firebase.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source / 'google-services.json', firebase)

# Flutter create generates this package path for --org com.zenvora --project-name zenvora.
main_activity = root / 'android' / 'app' / 'src' / 'main' / 'kotlin' / 'com' / 'zenvora' / 'zenvora' / 'MainActivity.kt'
main_activity.parent.mkdir(parents=True, exist_ok=True)
main_activity.write_text('package com.zenvora.zenvora\n\nimport io.flutter.embedding.android.FlutterActivity\n\nclass MainActivity : FlutterActivity()\n')
