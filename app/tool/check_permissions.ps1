# Fails unless the built APK asks for exactly the permissions Akatabo is allowed:
# POST_NOTIFICATIONS and USE_BIOMETRIC. AndroidX adds one app-private signature permission
# (<package>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION) that the person never sees; it is allowed.
#
# Usage: pwsh tool/check_permissions.ps1 [path-to-apk]
param([string]$Apk = "build/app/outputs/flutter-apk/app-release.apk")

$ErrorActionPreference = "Stop"
if (-not (Test-Path $Apk)) { Write-Error "APK not found: $Apk. Run 'flutter build apk --release' first." }

$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) { Write-Error "ANDROID_HOME is not set." }

# apkanalyzer needs a JDK; use the one Flutter is configured with when JAVA_HOME is unset.
if (-not $env:JAVA_HOME) {
    $jdk = (flutter config --machine | ConvertFrom-Json).'jdk-dir'
    if ($jdk) {
        $env:JAVA_HOME = $jdk
        $env:PATH = (Join-Path $jdk "bin") + [IO.Path]::PathSeparator + $env:PATH
    }
}

# Works on Windows, Linux and macOS, in PowerShell 7 and Windows PowerShell 5.1 (which has
# no $IsWindows).
$onWindows = [IO.Path]::DirectorySeparatorChar -eq [char]92
$tool = if ($onWindows) { "apkanalyzer.bat" } else { "apkanalyzer" }
$analyzer = [IO.Path]::Combine($sdk, "cmdline-tools", "latest", "bin", $tool)
$found = & $analyzer manifest permissions $Apk | ForEach-Object { $_.Trim() } | Where-Object { $_ }

$allowed = @(
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.USE_BIOMETRIC",
    "com.persmon.akatabo.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"
)
$extra = $found | Where-Object { $_ -notin $allowed }

Write-Output "Permissions in ${Apk}:"
$found | ForEach-Object { Write-Output "  $_" }
if ($extra) {
    Write-Output "FAIL: not allowed: $($extra -join ', ')"
    exit 1
}
Write-Output "PASS: only allowed permissions."
