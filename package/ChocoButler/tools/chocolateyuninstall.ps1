$ErrorActionPreference = 'Stop'; # stop on all errors

# Copy link to shim to startup
$batName = "chocobutler.bat"
$linkName = 'ChocoButler.lnk'

# Remove startup shortcut (if it exists)
$startupDir = [Environment]::GetFolderPath('Startup')
$shortcutPath1 = Join-Path $startupDir $linkName 
if (Test-Path $shortcutPath1) {
    Remove-Item $shortcutPath1
}

# Remove the Start Menu startup (if it exists)
$programs = [environment]::GetFolderPath([environment+specialfolder]::Programs)
$shortcutPath2 = Join-Path $programs $linkName
if (Test-Path $shortcutPath2) {
    Remove-Item $shortcutPath2
}


# The chocobutler.bat file would have been "installed" as a "shim" by Install-Binfile
Uninstall-BinFile -Name $batName