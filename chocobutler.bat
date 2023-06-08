:: The batch file starts ChocoButler with a hidden console window.
:: If you want to see logging message in the console use chocobutler_visible.bat
@ECHO OFF
SET ThisDir=%~dp0
SET ScriptPath=%ThisDir%chocobutler.ps1
:: The following fails to hide the window in Windows 11, see: https://github.com/microsoft/terminal/issues/12464
:: Can we start the powershell script without using a .bat file? Chocobutler has a wrapper for .bat to .exe?
:: See: https://stackoverflow.com/questions/69259601/shim-a-bat-file-in-chocolatey
:: The shim functionality: https://docs.chocolatey.org/en-us/create/functions/install-binfile
:: Maybe try to convert the .ps1 to and .exe with https://github.com/MScholtes/PS2EXE
PowerShell -NoProfile -ExecutionPolicy Bypass -WindowStyle hidden -Command "& '%ScriptPath%'";
