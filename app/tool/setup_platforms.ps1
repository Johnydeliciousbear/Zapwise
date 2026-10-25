# Windows version of setup_platforms.sh (Android only; iOS needs a Mac).
# Run from the app\ folder in PowerShell:   powershell -ExecutionPolicy Bypass -File tool\setup_platforms.ps1
$ErrorActionPreference = 'Stop'
if (-not (Test-Path pubspec.yaml)) { Write-Error 'Run this from the app\ folder (where pubspec.yaml is).' }

# 1. Generate android\ without touching lib\ or assets\
flutter create --org org.zapwise --project-name zapwise --platforms=android .
# flutter create adds a counter-app test that does not apply to ZapWise
if (Test-Path test\widget_test.dart) { Remove-Item test\widget_test.dart }

# 2. minSdk 26 (tflite_flutter), app label
foreach ($g in @('android\app\build.gradle.kts', 'android\app\build.gradle')) {
  if (Test-Path $g) {
    $t = Get-Content $g -Raw
    $t = $t -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 26' -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 26'
    Set-Content $g $t -NoNewline
    Write-Host "Android minSdk set to 26 in $g"
  }
}
$m = 'android\app\src\main\AndroidManifest.xml'
(Get-Content $m -Raw) -replace 'android:label="[^"]*"', 'android:label="ZapWise"' | Set-Content $m -NoNewline

# tflite_flutter compiles Java for 11 and Kotlin for 17; let Gradle accept the mix
$gp = 'android\gradle.properties'
if (-not (Select-String -Path $gp -Pattern 'kotlin.jvm.target.validation.mode' -Quiet)) { Add-Content $gp "`nkotlin.jvm.target.validation.mode=IGNORE" }
# R8 full mode strips classes ML Kit finds by reflection
if (-not (Select-String -Path $gp -Pattern 'android.enableR8.fullMode' -Quiet)) { Add-Content $gp "`nandroid.enableR8.fullMode=false" }

# R8 rules for ML Kit and TensorFlow Lite, used by the release build
Copy-Item tool\android\proguard-rules.pro android\app\proguard-rules.pro -Force
$bg = 'android\app\build.gradle.kts'
$t = Get-Content $bg -Raw
if ($t -notmatch 'proguard-rules.pro') {
  $t = $t -replace 'signingConfig = signingConfigs.getByName\("debug"\)', "signingConfig = signingConfigs.getByName(`"debug`")`n            proguardFiles(getDefaultProguardFile(`"proguard-android-optimize.txt`"), `"proguard-rules.pro`")"
  Set-Content $bg $t -NoNewline
}

# 3. App icons
foreach ($d in @('mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi')) {
  $dst = "android\app\src\main\res\mipmap-$d\ic_launcher.png"
  if (Test-Path $dst) { Copy-Item "branding\android\mipmap-$d\ic_launcher.png" $dst -Force }
}
Write-Host 'App icons copied'

# 4. Packages
flutter pub get
Write-Host ''
Write-Host 'Done. Next: flutter test, then run on a phone or emulator (F5 in VS Code).'
