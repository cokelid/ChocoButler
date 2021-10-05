$ErrorActionPreference = 'Stop'; # stop on all errors

# Copy link to shim to startup
$batName = "chocobutler.bat"

# Remove startup shortcut
$startupDir = [Environment]::GetFolderPath('Startup')
$shortcutPath = "$startupDir\ChocoButler.lnk"
Remove-Item $shortcutPath

# The chocobutler.bat file would have been "installed" as a "shim" by Install-Binfile
Uninstall-BinFile -Name $batName