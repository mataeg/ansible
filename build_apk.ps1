# ════════════════════════════════════════════════════════════════════
# EasyBill Fleet App - Automated Windows Build Script
# ════════════════════════════════════════════════════════════════════
Write-Host "🚀 بدء عملية بناء تطبيق الاندرويد الاحترافي..." -ForegroundColor Cyan

# 1. التحقق من تثبيت Flutter
if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "❌ لم يتم العثور على Flutter مثبت على هذا الجهاز!" -ForegroundColor Red
    Write-Host "💡 يرجى تثبيت Flutter وإضافته للمتغيرات البيئية (PATH) أولاً." -ForegroundColor Yellow
    Exit
}

# 2. التحقق من تثبيت Java
if (!(Get-Command java -ErrorAction SilentlyContinue)) {
    Write-Host "❌ لم يتم العثور على Java SDK (مطلوب لبناء الاندرويد)!" -ForegroundColor Red
    Exit
}

Write-Host "✅ تم التحقق من البيئة بنجاح." -ForegroundColor Green

# 3. تحديث رابط الـ API تلقائياً في الكود
$apiFile = "lib/core/api_client.dart"
if (Test-Path $apiFile) {
    Write-Host "⚙️ جاري تحديث رابط السيرفر إلى: https://nizol.motaigi.com ..." -ForegroundColor Yellow
    $content = Get-Content $apiFile
    $newContent = $content -replace "StateProvider<String>\(\(ref\) => '[^']+'\)", "StateProvider<String>((ref) => 'https://nizol.motaigi.com')"
    Set-Content $apiFile $newContent
    Write-Host "✅ تم تحديث الرابط في ملف api_client.dart بنجاح." -ForegroundColor Green
} else {
    Write-Host "⚠️ تحذير: لم يتم العثور على ملف api_client.dart لتحديث الرابط تلقائياً!" -ForegroundColor Orange
}

# 4. تثبيت المكتبات (Get Packages)
Write-Host "📦 جاري تحميل وتثبيت المكتبات المطلوبة..." -ForegroundColor Yellow
flutter pub get

# 5. بناء الـ APK
Write-Host "🏗️ جاري بناء تطبيق الاندرويد (Release APK)..." -ForegroundColor Yellow
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "🎉 تم بناء التطبيق بنجاح واحترافية!" -ForegroundColor Green
    Write-Host "📍 مسار ملف الـ APK النهائي:" -ForegroundColor Green
    Write-Host "$(Get-Location)\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Cyan
} else {
    Write-Host "❌ فشلت عملية البناء. يرجى مراجعة الأخطاء أعلاه." -ForegroundColor Red
}
