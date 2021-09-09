@ECHO OFF
SET ThisDir=%~dp0
SET ScriptPath=%ThisDir%choco_butler.ps1
PowerShell -NoProfile -ExecutionPolicy Bypass -windowstyle hidden -Command "& '%ScriptPath%'";
