
$ErrorActionPreference = 'Stop'; # stop on all errors

$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$batName = "chocobutler.bat"
$batPath = Join-Path $toolsDir $batName

# "Install" the bat file with a "shim" to add it to the path. Will create a .bat.exe file
Install-BinFile -Name $batName -Path $batPath

# Create short-cut to shim in startup
$startupDir = [Environment]::GetFolderPath('Startup')
$shim = Get-Command "$batName.exe"
$shortcutPath = "$startupDir\ChocoButler.lnk"
$WshShell = New-Object -comObject WScript.Shell
$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $shim.Path
$shortcut.Save()

# Start up chocobutler
Start-Process "$batName.exe"