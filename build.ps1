# TradeScalp Build Script
# Asks about trial and builds the exe

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "       TradeScalp Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Ask about trial
$trialChoice = Read-Host "Enable TRIAL mode? (y/n)"

$env:TRIAL_EXPIRY_TIMESTAMP = ""

if ($trialChoice -eq "y" -or $trialChoice -eq "Y") {
    $days = Read-Host "Trial for how many days?"

    # Calculate expiry timestamp (milliseconds)
    $expiryDate = (Get-Date).AddDays([int]$days)
    $expiryTimestamp = [long]([DateTimeOffset]$expiryDate).ToUnixTimeMilliseconds()

    # Obfuscate: split into two parts
    $part1 = [long]1000000000000
    $part2 = $expiryTimestamp - $part1

    Write-Host ""
    Write-Host "Trial expires: $($expiryDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
    Write-Host "Timestamp: $expiryTimestamp" -ForegroundColor Gray
    Write-Host ""

    # Set environment variables for build
    $env:TRIAL_ENABLED = "1"
    $env:TRIAL_PART1 = $part1.ToString()
    $env:TRIAL_PART2 = $part2.ToString()
} else {
    Write-Host ""
    Write-Host "Building WITHOUT trial (full version)" -ForegroundColor Green
    Write-Host ""

    $env:TRIAL_ENABLED = "0"
    $env:TRIAL_PART1 = "0"
    $env:TRIAL_PART2 = "0"
}

# Build
Write-Host "Building release..." -ForegroundColor Cyan
Write-Host ""

cargo build --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "       BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Exe location: target\release\tradescalp.exe" -ForegroundColor White

    if ($env:TRIAL_ENABLED -eq "1") {
        Write-Host "Trial: $days days (expires $($expiryDate.ToString('yyyy-MM-dd')))" -ForegroundColor Yellow
    } else {
        Write-Host "Trial: DISABLED (full version)" -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "BUILD FAILED!" -ForegroundColor Red
}
