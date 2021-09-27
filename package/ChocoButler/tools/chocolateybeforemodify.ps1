# Kill any existing ChocoButlers by looking for the PID file
$pid_file ="$ENV:Temp\ChocoButler.pid"
if (Test-Path $pid_file) {
    $pid_from_file = Get-Content -Path $pid_file
    Write-Host "[$((Get-Date).toString())] Killing existing ChocoButler session prior to update. PID = $pid_from_file"
    Stop-Process -ID $pid_from_file
    Remove-Item -Path $pid_file
} Else {
    Write-Host "[$((Get-Date).toString())] No existing ChocoButler PID found (i.e. no PID File: $pid_file)"
}

