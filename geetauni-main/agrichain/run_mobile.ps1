# AgriChain Mobile Runner - Passes all API keys via --dart-define
param([string]$Device = "")

$envVars = @{}
if (Test-Path ".\.env") {
    Get-Content ".\.env" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $envVars[$matches[1].Trim()] = $matches[2].Trim()
        }
    }
}

$dartDefines = @(
    "--dart-define=GEMINI_API_KEY=$($envVars["GEMINI_API_KEY"])",
    "--dart-define=FAST2SMS_API_KEY=$($envVars["FAST2SMS_API_KEY"])",
    "--dart-define=TWILIO_ACCOUNT_SID=$($envVars["TWILIO_ACCOUNT_SID"])",
    "--dart-define=TWILIO_AUTH_TOKEN=$($envVars["TWILIO_AUTH_TOKEN"])",
    "--dart-define=TWILIO_VERIFY_SERVICE_SID=$($envVars["TWILIO_VERIFY_SERVICE_SID"])",
    "--dart-define=BACKEND_URL=https://agrichain-whatsapp-api.onrender.com"
)

Write-Host "=========================================" -ForegroundColor Green
Write-Host "  AgriChain Mobile Runner with Twilio" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

if ($Device -ne "") {
    flutter run -d $Device @dartDefines
} else {
    flutter run @dartDefines
}
