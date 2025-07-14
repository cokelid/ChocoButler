$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$exePath = Join-Path $toolsDir 'ChocoButler.exe'

# Parse Chocolatey package parameters
$pp = $env:chocolateyPackageParameters
$createDesktopShortcut = $true
$createStartupShortcut = $true
if ($pp) {
    if ($pp -match "/NoStartMenu") { $createDesktopShortcut = $false } # legacy param
    if ($pp -match "/NoStartUp") { $createStartupShortcut = $false } # legacy param
}

# Create desktop shortcut if requested
if ($createDesktopShortcut -and (Test-Path $exePath)) {
    $desktop = [System.Environment]::GetFolderPath('Desktop')
    $shortcut = Join-Path $desktop 'ChocoButler.lnk'
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcut)
    $Shortcut.TargetPath = $exePath
    $Shortcut.WorkingDirectory = Split-Path $exePath
    $Shortcut.Description = 'ChocoButler - Chocolatey Package Monitor'
    $Shortcut.Save()
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
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($startupShortcut)
    $Shortcut.TargetPath = $exePath
    $Shortcut.WorkingDirectory = Split-Path $exePath
    $Shortcut.Description = 'ChocoButler - Chocolatey Package Monitor (Startup)'
    $Shortcut.Save()
    Write-Host "Startup shortcut created: $startupShortcut" -ForegroundColor Green
} elseif (-not $createStartupShortcut) {
    Write-Host "Startup shortcut creation skipped due to package parameter." -ForegroundColor Yellow
}


Write-Host "`nChocoButler has been installed successfully!" -ForegroundColor Green
Write-Host "The application will start automatically and appear in your system tray. This can be changed in the settings." -ForegroundColor Cyan
Write-Host "Right-click the tray icon to access options and settings." -ForegroundColor Cyan 