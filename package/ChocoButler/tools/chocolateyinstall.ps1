
$ErrorActionPreference = 'Stop'; # stop on all errors

$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$batName = "chocobutler.bat"
$batPath = Join-Path $toolsDir $batName

# "Install" the bat file with a "shim" to add it to the path. Will create a .bat.exe file
Install-BinFile -Name $batName -Path $batPath

# Start up chocobutler
Start-Process "$batName.exe"