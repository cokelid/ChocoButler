:: This batch file starts ChocoButler with a visible console window (so you can see logging messages)
@ECHO OFF
SET ThisDir=%~dp0
SET ScriptPath=%ThisDir%choco_butler.ps1
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%ScriptPath%'";
