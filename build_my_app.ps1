$time = Get-Date -Format "dd/MM/yyyy HH:mm"
flutter build apk --dart-define=BUILD_TIME="$time"
Write-Host "Done! Your APK is ready in build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green