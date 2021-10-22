
$ErrorActionPreference = 'Stop'; # stop on all errors

$pp = Get-PackageParameters

$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$batName = "chocobutler.bat"
$batPath = Join-Path $toolsDir $batName

# "Install" the bat file with a "shim" to add it to the path. Will create a .bat.exe file
Install-BinFile -Name $batName -Path $batPath

$linkName = 'ChocoButler.lnk'

# Create a Startup shortcut
if (!$pp['NoStartup'])  {
    Write-Host "[$((Get-Date).toString())] Adding Startup shortcut for ChocoButler. Suppress this with /NoStartup Parameter."
    $startupDir = [Environment]::GetFolderPath('Startup')
    $iconPath =  "$($env:ChocolateyInstall)\lib\chocobutler\tools\chocobutler_red.ico"
    $shim = Get-Command "$batName.exe"
    $shortcutPath1 = Join-Path $startupDir $linkName 
    Install-ChocolateyShortcut -ShortcutFilePath $shortcutPath1 -TargetPath $shim.Path -Description "ChocoButler" -IconLocation $iconPath -WindowStyle 0
}

# Create a Start-Menu shortcut
if (!$pp['NoStartMenu']) {
    Write-Host "[$((Get-Date).toString())] Adding Start-Menu shortcut for ChocoButler. Suppress this with /NoStartMenu Parameter."
    $shim = Get-Command "$batName.exe"
    $iconPath =  "$($env:ChocolateyInstall)\lib\chocobutler\tools\chocobutler_red.ico"
    $programs = [environment]::GetFolderPath([environment+specialfolder]::Programs)
    $shortcutPath2 = Join-Path $programs $linkName 
    Install-ChocolateyShortcut -shortcutFilePath $shortcutPath2 -TargetPath $shim.Path -Description "ChocoButler" -IconLocation $iconPath -WindowStyle 0
}


# Start up chocobutler
Start-Process "$batName.exe"