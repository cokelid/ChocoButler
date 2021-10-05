
$ErrorActionPreference = 'Stop'; # stop on all errors

$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$batName = "chocobutler.bat"
$batPath = Join-Path $toolsDir $batName

# "Install" the bat file with a "shim" to add it to the path. Will create a .bat.exe file
Install-BinFile -Name $batName -Path $batPath

# Create short-cut to shim in startup
$startupDir = [Environment]::GetFolderPath('Startup')
$iconPath =  "$($env:ChocolateyInstall)\lib\chocobutler\tools\chocolatey_red.ico"
$shim = Get-Command "$batName.exe"
$shortcutPath = "$startupDir\ChocoButler.lnk"
Install-ChocolateyShortcut -ShortcutFilePath $shortcutPath -TargetPath $shim.Path -Description "ChocoButler" -IconLocation $iconPath -WindowStyle 0


# Start up chocobutler
Start-Process "$batName.exe"