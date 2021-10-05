# Kill any existing ChocoButlers by looking for the PID file

# When chocolately installs on Windows 2012 the $ENV:Temp can include a "chocolately" subdir, but not when started normally?!
# So do something hacky to try and handle this
$tmp1 = (Get-Item -force $ENV:Temp).FullName # Convert C:\Users\ADMINI~1\AppData\Local\Temp TO C:\Users\Administrator\AppData\Local\Temp
$tmp2 = (Get-Item -force "$ENV:userprofile\AppData\Local\Temp").FullName
if ($tmp1.Contains($tmp2) -and ($tmp1.Length -gt $tmp2.Length)) {
    # This is the 2012 style we're seeing where $ENV:Temp = C:\Users\Administrator\AppData\Local\Temp\1\chocolatey
    $pid_dir = $tmp2
} else {
    $pid_dir = $tmp1
}
$pid_file ="$pid_dir\ChocoButler.pid"

if (Test-Path $pid_file) {
    $pid_from_file = Get-Content -Path $pid_file
    Write-Host "[$((Get-Date).toString())] Killing existing ChocoButler session prior to update. PID = $pid_from_file [$pid_file]"
    Stop-Process -ID $pid_from_file
    Remove-Item -Path $pid_file
} Else {
    Write-Host "[$((Get-Date).toString())] No existing ChocoButler PID found (i.e. no PID File: $pid_file)"
}

