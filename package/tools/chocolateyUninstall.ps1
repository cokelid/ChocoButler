$ErrorActionPreference = 'Stop'

$packageName = 'chocobutler'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Stop any running instances of ChocoButler
$processes = Get-Process -Name "ChocoButler" -ErrorAction SilentlyContinue
if ($processes) {
    Write-Host "Stopping running ChocoButler processes..." -ForegroundColor Yellow
    foreach ($process in $processes) {
        try {
            $process.CloseMainWindow()
            if (-not $process.WaitForExit(5000)) {
                $process.Kill()
                Write-Host "Forcefully terminated ChocoButler process (PID: $($process.Id))" -ForegroundColor Yellow
            } else {
                Write-Host "Gracefully stopped ChocoButler process (PID: $($process.Id))" -ForegroundColor Green
            }
        } catch {
            Write-Warning "Failed to stop ChocoButler process (PID: $($process.Id)): $($_.Exception.Message)"
        }
    }
}

# Remove desktop shortcut
$desktop = [System.Environment]::GetFolderPath('Desktop')
$shortcut = Join-Path $desktop 'ChocoButler.lnk'
if (Test-Path $shortcut) {
    try {
        Remove-Item $shortcut -Force
        Write-Host "Removed desktop shortcut: $shortcut" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to remove desktop shortcut: $($_.Exception.Message)"
    }
}

# Remove startup shortcut if it exists
$startup = [System.Environment]::GetFolderPath('Startup')
$startupShortcut = Join-Path $startup 'ChocoButler.lnk'
if (Test-Path $startupShortcut) {
    try {
        Remove-Item $startupShortcut -Force
        Write-Host "Removed startup shortcut: $startupShortcut" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to remove startup shortcut: $($_.Exception.Message)"
    }
}

# Clean up any remaining files in the tools directory
$exePath = Join-Path $toolsDir 'ChocoButler.exe'
if (Test-Path $exePath) {
    try {
        Remove-Item $exePath -Force
        Write-Host "Removed executable: $exePath" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to remove executable: $($_.Exception.Message)"
    }
}

# Remove any associated DLL files
$dllFiles = Get-ChildItem -Path $toolsDir -Filter "*.dll" -ErrorAction SilentlyContinue
foreach ($dll in $dllFiles) {
    try {
        Remove-Item $dll.FullName -Force
        Write-Host "Removed: $($dll.Name)" -ForegroundColor Gray
    } catch {
        Write-Warning "Failed to remove $($dll.Name): $($_.Exception.Message)"
    }
}

# Remove any associated PDB files
$pdbFiles = Get-ChildItem -Path $toolsDir -Filter "*.pdb" -ErrorAction SilentlyContinue
foreach ($pdb in $pdbFiles) {
    try {
        Remove-Item $pdb.FullName -Force
        Write-Host "Removed: $($pdb.Name)" -ForegroundColor Gray
    } catch {
        Write-Warning "Failed to remove $($pdb.Name): $($_.Exception.Message)"
    }
}

Write-Host "`nChocoButler has been uninstalled successfully!" -ForegroundColor Green
Write-Host "All shortcuts and files have been removed." -ForegroundColor Cyan 