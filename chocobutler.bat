:: The batch file starts ChocoButler with a hidden console window.
:: If you want to see logging message in the console use chocobutler_visible.bat
@ECHO OFF
SET ThisDir=%~dp0
SET ScriptPath=%ThisDir%chocobutler.ps1
PowerShell -NoProfile -ExecutionPolicy Bypass -windowstyle hidden -Command "& '%ScriptPath%'";
