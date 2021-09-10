:: The batch file starts ChocoButler with a hidden console window.
:: If you want to see logging message in the console use choco_butler_visible.bat
@ECHO OFF
SET ThisDir=%~dp0
SET ScriptPath=%ThisDir%choco_butler.ps1
PowerShell -NoProfile -ExecutionPolicy Bypass -windowstyle hidden -Command "& '%ScriptPath%'";
