#!/usr/bin/env bash
# One-time setup of the Android and iOS project folders for ZapWise.
# Run from the app/ folder:   bash tool/setup_platforms.sh
# Works on macOS and Linux (uses perl for in-place edits; PlistBuddy only on macOS).
set -euo pipefail

if [ ! -f pubspec.yaml ]; then
  echo "Run this from the app/ folder (where pubspec.yaml is)." >&2
  exit 1
fi

# 1. Generate android/ and ios/ without touching lib/ or assets/
flutter create --org org.zapwise --project-name zapwise --platforms=android,ios .
rm -f test/widget_test.dart  # flutter create adds a counter-app test that does not apply to ZapWise

# 2. Android: minSdk 26 (tflite_flutter README asks for API 26; camera needs 24, ML Kit 21)
for g in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$g" ]; then
    perl -pi -e 's/minSdk\s*=\s*flutter\.minSdkVersion/minSdk = 26/; s/minSdkVersion\s+flutter\.minSdkVersion/minSdkVersion 26/' "$g"
    echo "Android minSdk set to 26 in $g"
  fi
done
perl -pi -e 's/android:label="[^"]*"/android:label="ZapWise"/' android/app/src/main/AndroidManifest.xml

# 3. iOS: deployment target 15.5 (ML Kit), camera purpose strings, display name
perl -pi -e "s/^#?\s*platform :ios, .*/platform :ios, '15.5'/" ios/Podfile
if grep -q "post_install do |installer|" ios/Podfile; then
  perl -0pi -e "s/flutter_additional_ios_build_settings\(target\)/flutter_additional_ios_build_settings(target)\n    target.build_configurations.each do |config|\n      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.5'\n    end/" ios/Podfile
fi
PLIST=ios/Runner/Info.plist
if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Delete :NSCameraUsageDescription" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string 'ZapWise uses the camera to read food boxes, tray markings and your microwave label.'" "$PLIST"
  /usr/libexec/PlistBuddy -c "Delete :NSMicrophoneUsageDescription" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string 'ZapWise does not record audio. The camera plugin requires this entry.'" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ZapWise" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string ZapWise" "$PLIST"
  echo "iOS Info.plist updated"
else
  echo "Not on macOS: add NSCameraUsageDescription and NSMicrophoneUsageDescription to $PLIST by hand (see README)."
fi

# 4. App icons (the final LED-face Zappy). Only files whose names already exist are replaced.
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  src="branding/android/mipmap-$d/ic_launcher.png"
  dst="android/app/src/main/res/mipmap-$d/ic_launcher.png"
  if [ -f "$dst" ]; then cp "$src" "$dst"; fi
done
IOSSET=ios/Runner/Assets.xcassets/AppIcon.appiconset
for f in branding/ios/AppIcon.appiconset/*.png; do
  n=$(basename "$f")
  if [ -f "$IOSSET/$n" ]; then cp "$f" "$IOSSET/$n"; fi
done
echo "App icons copied"

# 5. Packages
# tflite_flutter compiles Java for 11 and Kotlin for 17; let Gradle accept the mix
grep -q 'kotlin.jvm.target.validation.mode' android/gradle.properties || printf '\nkotlin.jvm.target.validation.mode=IGNORE\n' >> android/gradle.properties
grep -q 'android.enableR8.fullMode' android/gradle.properties || printf '\nandroid.enableR8.fullMode=false\n' >> android/gradle.properties

# R8 rules for ML Kit and TensorFlow Lite, used by the release build
cp tool/android/proguard-rules.pro android/app/proguard-rules.pro
grep -q 'proguard-rules.pro' android/app/build.gradle.kts || python3 - <<'PY'
p = 'android/app/build.gradle.kts'
s = open(p).read()
s = s.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("debug")\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")', 1)
open(p, 'w').write(s)
PY

flutter pub get
echo
echo "Done. Next: flutter test, then flutter run on a real phone (the camera and ML Kit need a device)."
echo "Store images: branding/store/ (Play icon 512, feature graphic 1024x500, App Store icon 1024)."
