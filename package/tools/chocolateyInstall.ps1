$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$exePath = Join-Path $toolsDir 'ChocoButler.exe'

# Parse Chocolatey package parameters
$pp = $env:chocolateyPackageParameters
$createDesktopShortcut = $true
$createStartupShortcut = $true
if ($pp) {
    if ($pp -match "/NoStartMenu") { $createDesktopShortcut = $false }
    if ($pp -match "/NoStartUp") { $createStartupShortcut = $false }
}

# Create desktop shortcut if requested
if ($createDesktopShortcut -and (Test-Path $exePath)) {
    $desktop = [System.Environment]::GetFolderPath('Desktop')
    $shortcut = Join-Path $desktop 'ChocoButler.lnk'
    Install-ChocolateyShortcut -ShortcutFilePath $shortcut -TargetPath $exePath -WorkingDirectory (Split-Path $exePath) -Description 'ChocoButler - Chocolatey Package Monitor'
    Write-Host "Desktop shortcut created: $shortcut" -ForegroundColor Green
} elseif (-not $createDesktopShortcut) {
    Write-Host "Desktop shortcut creation skipped due to package parameter." -ForegroundColor Yellow
} else {
    Write-Warning "ChocoButler.exe not found at expected location: $exePath"
}

# Create startup shortcut if requested
if ($createStartupShortcut -and (Test-Path $exePath)) {
    $startup = [System.Environment]::GetFolderPath('Startup')
    $startupShortcut = Join-Path $startup 'ChocoButler.lnk'
    Install-ChocolateyShortcut -ShortcutFilePath $startupShortcut -TargetPath $exePath -WorkingDirectory (Split-Path $exePath) -Description 'ChocoButler - Chocolatey Package Monitor (Startup)'
    Write-Host "Startup shortcut created: $startupShortcut" -ForegroundColor Green
} elseif (-not $createStartupShortcut) {
    Write-Host "Startup shortcut creation skipped due to package parameter." -ForegroundColor Yellow
}

# Launch ChocoButler after installation if the executable exists
if (Test-Path $exePath) {
    Start-Process $exePath
    Write-Host "ChocoButler started automatically after installation." -ForegroundColor Green
    Write-Host "`nChocoButler has been installed successfully!" -ForegroundColor Green
    Write-Host "The application will start automatically and appear in your system tray. This can be changed in the settings." -ForegroundColor Cyan
    Write-Host "Right-click the tray icon to access options and settings." -ForegroundColor Cyan 
} else {
    Write-Warning "ChocoButler.exe not found, could not start application automatically."
}

