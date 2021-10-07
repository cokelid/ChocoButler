# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted
# Code taken from: https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-powershell-1.0/ff730952(v=technet.10)

$VERSION = 'v0.1.9-beta'

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

if ((Get-Host).Version -lt '4.0') {    
    Write-Host "ChocoButler requires Powershell 4.0 or above."
    [System.Windows.Forms.MessageBox]::Show("ChocoButler requires Powershell 4.0 or above.`nChocoButler will now exit.", "Powershell Version Error", 'OK', 'Error')
    Exit 1
}

Write-Host "[$((Get-Date).toString())] ChocoButler $VERSION starting... [$PSScriptRoot]"
Write-Host "[$((Get-Date).toString())] PID: $pid"


# INIT outer vars (Script scope) used in functions.
$objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$next_check_time = Get-Date
$timer = New-Object System.Windows.Forms.Timer
[array]$outdated = @()

# Default settings
$settings = [PSCustomObject]@{check_delay_hours=12; auto_install=$False; silent=$False; exit_if_no_outdated=$False; immediate_first_check=$False; test_mode=$False}

function assert($condition, $message, $title, $keep_pid) {
    if (-Not $condition) {
        $timer.Stop()
        Write-Host $message
        Write-Host '(Click OK in dialog box to Exit)'
        [System.Windows.Forms.MessageBox]::Show($message, $title, 'OK', 'Error')
        $objNotifyIcon.Dispose()
        $timer.Dispose()
        if ($keep_pid -ne $true) { Remove-Item -Path $pid_file }
        if ($settings.test_mode) { Exit 1 } else { Stop-Process $pid }
    }
}


# Store a file with the process ID so we can kill existing instances on upgrade
$pid_dir = $ENV:LOCALAPPDATA
$pid_file ="$pid_dir\ChocoButler.pid"
function pid_file_check {
    # Check if there's already a $pid file, and if not make one
    # This will be called every minute (by tick_check) but should be lightweight enough not to matter
    # This PID file is used when ChocoButler gets updated.
    if (Test-Path $pid_file) {
        $pid_from_file = Get-Content -Path $pid_file
        if ($pid_from_file -ne $pid) {
            # The PID in the file doesn't match this PID?
            # Either it's an old file OR we have two ChocoButlers running
            $pid2 = Get-Process -Id $pid_from_file
            if ($null -eq $pid2) {
                # There is no such process, it must be an old .pid file. Overwrite it!
                Write-Host "[$((Get-Date).toString())] Existing PID file contains unknown PID ($pid_from_file). Updating file. $pid_file"
                Set-Content -Path $pid_file $pid
            } Else {
                # It's a Powershell process, if so assume it's another ChocoButler!
                assert ($pid2.ProcessName -ne "powershell") "More than one ChocoButler instance is running.`nThere can be only one.`nThis instance will now Exit." "Multiple ChocoButlers" $true
                # Must be an old file, so overwrite the existing one
                Write-Host "[$((Get-Date).toString())] Existing PID file contains non-powershell process ($pid_from_file). Updating file. $pid_file"
                Set-Content -Path $pid_file $pid
            }
        }
    } Else {
        # No file, so create one
        Write-Host "[$((Get-Date).toString())] Creating PID file: $pid_file"
        Set-Content -Path $pid_file $pid
    }
}
pid_file_check  # Create a .pid file containg the process id

$settings_dir = "$ENV:APPDATA\ChocoButler"
$settings_file = "$settings_dir\settings.json"
function load_settings {
    if (-Not(Test-Path $settings_file)) {
        Write-Host "[$((Get-Date).toString())] No settings.json file found (at $settings_file). Using defaults."
        Write-Host "[$((Get-Date).toString())] Default Settings: $settings"
        return $settings
    }
    Write-Host "[$((Get-Date).toString())] Reading settings from file: $settings_file"    
    $s = Get-Content -Raw -Path $settings_file | ConvertFrom-Json  # Will not fail if file missing
    $ok = ($s -is [System.Object])
    assert $ok "Cannot load settings.json file. Syntax Error?:`n$($settings_file)`nChocoButler will now exit." "ChocoButler Settings Error"
    # Ensure $s has same settings (Properties) as existing $settings
    Foreach ($k in $settings.PSObject.Properties.Name) {
        if (-Not(Get-Member -InputObject $s -Name $k)) {
            Write-Host "[$((Get-Date).toString())] No entry for ""$k"" found in settings file. Adding to settings.json with default: $($settings.($k))"
            $s | Add-Member -NotePropertyName $k -NotePropertyValue $settings.($k)
            # Write out the new settings file, this may be repetative for multiple new settings but meh
            $s | ConvertTo-Json | Set-Content -Path $settings_file
        }
    }
    Foreach ($k in $s.PSObject.Properties.Name) {
        assert (Get-Member -InputObject $settings -Name $k) "Unexpected setting '$k' in settings.json file" "ChocoButler Settings Error"
    }
    Write-Host "[$((Get-Date).toString())] Settings: $s"
    return $s
}
$settings = load_settings



# Check that choco is installed and it's recent
$choco = Get-Command choco
assert ($choco.Count -gt 0) "Cannot find a choco installation.`nEnsure 'choco.exe' is on your path.`nChocoButler will now exit." "Chocolately Not Installed"
# Check Chocolately version. Don't use -v since that's not available in all versions of choco
assert ((choco -? | Out-String) -match '(?m)^Chocolatey v([\d\.]+)') "Requires Chocolatey Version 0.11.1 or higher. Cannot determine your version.`nChocoButler will now exit" "Chocolately Version Error"  # (?m) modifies regex for multiline match
$choco_ver = $Matches[1]  # The previous -match will populate $Matches if True
assert ([System.Version]::Parse($choco_ver) -ge '0.11.1') "Requires Chocolatey Version 0.11.1 or higher.`nYou have $($Matches[0]).`nChocoButler will now exit." "Chocolately Version Error"
      


function check_for_choco_old_problem {
    # Check for the dreaded "choco.exe.old" problem...
    # If chocolately updates itself it can start issuing errorts/warnings that prevent us from parsing choco's output correctly.
    # Check for this by running trivial 'choco source' command.
    # If it's goes wrong you'll see something like:
    #         "Access to the path 'C:\ProgramData\chocolatey\choco.exe.old' is denied."
    # Here choco is trying to delete the old .exe file but can't, so run choco as admin to give it the permissions it needs.
    $res = (choco source | Select-String 'choco.exe.old'' is denied')
    if ($res.Count -gt 0){
        $choco_exe_old = Get-Command 'choco.exe.old'
        if ($choco_exe_old.Count -gt 0) {
            $msg = "Chocolatey has encountered the dreaded 'choco.exe.old' error.`nClick Yes to attempt repair...."
            $btn =  [System.Windows.Forms.MessageBox]::Show($msg, 'Repair Chocolatey?', 'YesNo', 'Question')
            if ($btn -eq 'Yes') {
                # Here we run a trivial choco command with elevated permissions, to allow choco itself to delete the errant file...
                Start-Process -FilePath "choco" -ArgumentList "source" -Verb RunAs -Wait
                # Did it work?
                $res = (choco source | Select-String 'choco.exe.old'' is denied')
            }
        }
    }
    assert (-Not ($res.Count -gt 0)) "Chocolately is no longer working properly!`n`nIt is issuing warnings that prevents ChocoButler from parsing choco's data.`nThis is caused by Chocolatey updating itself.`nTry deleting the 'choco.exe.old' file as admin (see warning below for details).`n`nChocoButler will now exit.`n`nWARNING:`n$($res | Out-String)" "Chocolately Error"
}
check_for_choco_old_problem



Try {$gui_obj = Get-Command 'chocolateygui' -ErrorAction Stop} Catch {$gui_obj = $null}  # Returns an object
if ( $gui_obj.Count -gt 0 ) {
    $gui = $gui_obj.Source  # This is the path
} else {
    $gui = "C:\Program Files (x86)\Chocolatey GUI\ChocolateyGui.exe"
    if (-Not (Test-Path $gui)) {
        $gui = "C:\Program Files\Chocolatey GUI\ChocolateyGui.exe"
        if (-Not (Test-Path $gui)) {
            $lnk = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Chocolatey GUI.lnk"
            if (Test-Path $lnk) {
                $sh = New-Object -ComObject WScript.Shell
                $gui = $sh.CreateShortcut($lnk).TargetPath
                if (-Not (Test-Path $gui)) {
                    $gui = ""
                }
            } Else {
                $gui = ''
            }
        }
    }
}

# Create the menu entry for opening Chocolatey GUI
$mnuOpen = New-Object System.Windows.Forms.MenuItem
if ( ($gui -ne '') -and (Test-Path $gui) ) {
    $mnuOpen.Text = "Open Chocolately GUI"
    $mnuOpen.add_Click({
        Start-Process -FilePath $gui
    })
} Else {
    $mnuOpen.Text = '(Chocolately GUI not installed)'
    $mnuOpen.Enabled = $false
}


$mnuCheck = New-Object System.Windows.Forms.MenuItem
$mnuCheck.Text = "Check for outdated packages now"
$mnuCheck.add_Click({
    $ok = check_for_outdated
    $end_time = Get-Date
    if ($ok) {
        # If the check failed, don't update time so it happens again in a minute
        $next_check_time = $end_time + (New-TimeSpan -Hours $settings.check_delay_hours)
        Write-Host "[$($end_time.toString())] Next outdated-check will be in $($settings.check_delay_hours) hours at approx: $($next_check_time.toString())"
        Set-Variable -Name "next_check_time" -Value $next_check_time -Scope Script  # Store the new next_time in the outer scope
        if ($outdated.Count -eq 0) {
            # For manually instigated checks, show a zero result
            $objNotifyIcon.BalloonTipIcon = "Info" # Should be one of: None, Info, Warning, Error  
            $objNotifyIcon.BalloonTipText = "No outdated chocolatey pacakages found"
            $objNotifyIcon.BalloonTipTitle = "No Outdated Packages"
            if (-Not($settings.silent)) {$objNotifyIcon.ShowBalloonTip(5000)}
        }
    } Else {
        Write-Host "[$(($end_time).toString())] Following error, next outdated-check will be in 1 minute"
    }
    
})

$mnuMsg = New-Object System.Windows.Forms.MenuItem
$mnuMsg.Text = "Updates available: <Not Checked>"
$mnuMsg.Enabled = $false

$mnuDate = New-Object System.Windows.Forms.MenuItem
$mnuDate.Text = "Last checked: <Not Checked>"
$mnuDate.Enabled = $false

$mnuExit = New-Object System.Windows.Forms.MenuItem
$mnuExit.Text = "Exit"
$mnuExit.add_Click({
    $objNotifyIcon.Dispose()
    $timer.Dispose()
    Remove-Item -Path $pid_file
    if ($settings.test_mode) { Exit 1 } else { Stop-Process $pid }
})

$mnuInstall = New-Object System.Windows.Forms.MenuItem
$mnuInstall.Text = If ($settings.test_mode) {"[TEST MODE] Install upgrades..."} Else {"Install upgrades..."}
$mnuInstall.Enabled = $false
$mnuInstall.add_Click({
   do_upgrade_dialog   
})

$mnuAdvanced = New-Object System.Windows.Forms.MenuItem
$mnuAdvanced.Text = "Advanced"
$mnuAdvanced.Enabled = $true

$mnuShowLog = New-Object System.Windows.Forms.MenuItem
$log_file_path = 'C:\ProgramData\chocolatey\logs\chocolatey.log'  # Is there a way to discover this?
if (Test-Path $log_file_path) {
    $mnuShowLog.Text = "Show Chocolatey log file"
    $mnuShowLog.Enabled = $true
    $mnuShowLog.add_Click({ Invoke-Item $log_file_path })
} Else {
    $mnuShowLog.Text = "(Log file not found?)"
    $mnuShowLog.Enabled = $false
}

$mnuAbout = New-Object System.Windows.Forms.MenuItem
$mnuAbout.Text = "ChocoButler $VERSION"
$mnuAbout.Enabled = $false


$mnuEditSettings = New-Object System.Windows.Forms.MenuItem
$mnuEditSettings.Text = "Edit ChocoButler Settings file"
$mnuEditSettings.Enabled = $true
$mnuEditSettings.add_Click({
    # Create a settings file if one doesn't exist
    # First create the dir
    if (-Not(Test-Path $settings_dir)) {
        Write-Host "[$((Get-Date).toString())] Creating directory for settings: $settings_dir"
        mkdir $settings_dir
        if (-Not(Test-Path $settings_dir)) {
            Write-Host "[$((Get-Date).toString())] Unable to create directory for settings: $settings_dir"
            [System.Windows.Forms.MessageBox]::Show("Unable to create directory for settings:`n$settings_dir", "Settings Error", 'OK', 'Error')
            return
        }
    }
    if (-Not(Test-Path $settings_file)) {
        Write-Host "[$((Get-Date).toString())] No settings.json file found (at $settings_file). Creating one with defaults."
        $settings | ConvertTo-Json | Set-Content -Path $settings_file
    }
    if (-Not(Test-Path $settings_file)) {
        Write-Host "[$((Get-Date).toString())] Unable to create settings file: $settings_file"
        [System.Windows.Forms.MessageBox]::Show("Unable to create settings file:`n$settings_file", "Settings Error", 'OK', 'Error')
        return
    }
    [System.Windows.Forms.MessageBox]::Show("You must restart ChocoButler via 'Advanced' menu for settings-changes to take effect.", 'Restart ChocoButler', 'OK', 'Info')
    Invoke-Item $settings_file
})

$mnuShowReadme = New-Object System.Windows.Forms.MenuItem
$mnuShowReadme.Text = "Open ChocoButler README (on web)"
$mnuShowReadme.Enabled = $true
$mnuShowReadme.add_Click({ Start-Process 'https://github.com/cokelid/ChocoButler#readme' })

$mnuRestart = New-Object System.Windows.Forms.MenuItem
$mnuRestart.Text = "Restart ChocoButler"
$mnuRestart.Enabled = $true
$mnuRestart.add_Click({
    $bat_path = "$PSScriptRoot\chocobutler.bat"
    if (Test-Path $bat_path) {
        $objNotifyIcon.Dispose()
        $timer.Dispose()
        Remove-Item -Path $pid_file        
        Start-Process -FilePath $bat_path
        if ($settings.test_mode) { Exit 1 } else { Stop-Process $pid }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Unable to restart ChocoButler?`nCannot locate .bat file:`n$bat_path", 'Restart not possible', 'OK', 'Error')
    }
})


$context_menu = New-Object System.Windows.Forms.ContextMenu

function build_menus {
    $objNotifyIcon.ContextMenu = $context_menu
    $objNotifyIcon.contextMenu.MenuItems.AddRange($mnuInstall)
    $objNotifyIcon.contextMenu.MenuItems.AddRange($mnuMsg)
    $objNotifyIcon.contextMenu.MenuItems.AddRange($mnuDate)
    $objNotifyIcon.contextMenu.MenuItems.AddRange($mnuCheck)
    $objNotifyIcon.contextMenu.MenuItems.AddRange($mnuOpen)
    $objNotifyIcon.contextMenu.MenuItems.AddRange($mnuAdvanced)
    $mnuAdvanced.MenuItems.AddRange($mnuAbout)
    $mnuAdvanced.MenuItems.AddRange($mnuEditSettings)
    $mnuAdvanced.MenuItems.AddRange($mnuShowReadme)
    $mnuAdvanced.MenuItems.AddRange($mnuShowLog)
    $mnuAdvanced.MenuItems.AddRange($mnuRestart)
    $objNotifyIcon.contextMenu.MenuItems.AddRange($mnuExit)
}
build_menus

function show_icon {
    # Use this if we have to create a new icon after choconutler updates itself
    $objNotifyIcon.Icon = $icon
    $objNotifyIcon.Text = "ChocoButler"
    $objNotifyIcon.Visible = $true
}


function do_upgrade {
    $timer.Stop()
    $old_mnuInstall_Enabled = $mnuInstall.Enabled
    $mnuInstall.Enabled = $false
    $mnuCheck.Enabled = $false
    $objNotifyIcon.Text = "ChocoButler`nUpgrading Packages..."
    $mnuMsg.Text = "Upgrading $($outdated.Count) packages..."
    
    if ($outdated.name -contains 'chocobutler') {
        Write-Host "[$((Get-Date).toString())] NOTE: Upgrade list contains ChocoButler itself... Killing icon and upgrading chocobutler last of all."
        $do_chocobutler_upgrade = $true
        # Since we're updating chocobutler, we need to kill the system tray icon since we'll be starting a new process
        # and ensure that chocobutler is updated last of all
        for ($i=0; $i -le $outdated.Length-1; $i++) {
            if ($outdated[$i].name -eq 'chocobutler') {$so = ($outdated.Length+100)} else {$so = $i}
            # Add sort-order
            Add-Member -InputObject $outdated[$i] -NotePropertyName "sort_order" -NotePropertyValue $so
        }
        $outdated = ($outdated | Sort-Object -Property sort_order)  # Sort chocobutler last
        # Kill system tray icon before we update chocobutler
        $objNotifyIcon.Dispose()
    } else {
        $do_chocobutler_upgrade = $false
    }

    $outdated_packages = $outdated.name -join ' '  # Space-separated list of packages
    $upgradeStart = Get-Date
    $mnuDate.Text = "Upgrading began: $($upgradeStart.toString())"
    Write-Host "[$($upgradeStart.toString())] Upgrading packages: $outdated_packages"
    # Run the choco command as admin.
    If ($settings.test_mode) {
        Write-Host "[$($upgradeStart.toString())] TEST MODE! Nothing will be updated. Running with --noop."
        $arg_list = "upgrade $outdated_packages --yes --noop"
    } Else {
        $arg_list = "upgrade $outdated_packages --yes"
    }
    try {
        $proc = (Start-Process -FilePath "choco" -Verb RunAs -ArgumentList $arg_list -Wait -PassThru)
        $exitCode = $proc.ExitCode # Exit codes: https://docs.chocolatey.org/en-us/choco/commands/upgrade#exit-codes
    } catch [System.InvalidOperationException]{
        # If the user doesn't click yes to elevated rights
        $exitCode = -999
        Write-Host "[$((Get-Date).toString())] Upgrade cancelled. User did not agree to elevated admin rights?"
    } catch {
        Write-Host "[$((Get-Date).toString())] An unknown error occurred:"
        Write-Host $_.Exception
        Write-Host $_.ErrorDetails
        Write-Host $_.ScriptStackTrace
        $exitCode = -1
    }
    if ($do_chocobutler_upgrade) {
        # We shouldn't really ever get here, since during the chocobutler upgrade, the current process should have been killed.
        # BUT if the upgrade fails, or user didn't click Yes, and we're still alive, recreate the $objNotifyIcon
        $objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon
        Set-Variable -Name "objNotifyIcon" -Value $objNotifyIcon -Scope Script
        build_menus
        show_icon
    }

    $upgradeEnd = Get-Date
    Write-Host "[$($upgradeEnd.toString())] Upgrade ended with Exit Code: $exitCode. (0 is good!)"
    $mnuDate.Text = "Upgrade ended: $($upgradeEnd.toString())"
    $objNotifyIcon.Text = "ChocoButler"
    if ($exitCode -eq 0) {  
        $mnuMsg.Text = "Upgrade successful!"
        $objNotifyIcon.BalloonTipIcon = "Info" # Should be one of: None, Info, Warning, Error  
        $objNotifyIcon.BalloonTipText = "Chocolately UPGRADE SUCCESS!"
        $objNotifyIcon.BalloonTipTitle = "ChocoButler"
        if (-Not($settings.silent)) {$objNotifyIcon.ShowBalloonTip(4000)}
        $mnuInstall.Enabled = $false  # Worked, so don't want to rerun.
        $objNotifyIcon.Icon = $icon  # regular icon
        Set-Variable -Name "outdated" -Value @() -Scope Script # Reset the outdated list to empty in the outer scope
    } Else {
        # Something happened so we want to shout about it
        If ($exitCode -eq 1641) {
            $msg = "Upgrade successful. Reboot Initiated..."
            $type = "Warning"
        } ElseIf ($exitCode -eq 3010) {
            $msg = "Upgrade successful. Reboot Required..."
            $type = "Warning"
        } ElseIf ($exitCode -eq 350) {
            $msg = "Upgrade successful. Exit code 350. Pending reboot detected, no action has occurred."
            $type = "Warning"
        } ElseIf ($exitCode -eq 1604) {
            $msg = "Upgrade error. Exit code 1604: Install suspended, incomplete."
            $type = "Error"
        } ElseIf ($exitCode -eq -999) {
            $msg = "User cancelled upgrade. Admin rights required!"
            $type = "Error"
        } ElseIf ($exitCode -eq -1) {
            $msg = "Error occurred during upgrade. Update manually. (Exit code -1)"
            $type = "Error"
        } Else {
            $msg = "Unknown error occurred. Exit code: $exitCode`n$($_.Exception)`nSee Log File for details"
            $type = "Error"
        }
        $mnuMsg.Text = $msg
        $objNotifyIcon.BalloonTipIcon = $type # Should be one of: None, Info, Warning, Error  
        $objNotifyIcon.BalloonTipText = $msg
        $objNotifyIcon.BalloonTipTitle = "Chocolately Upgrade (ChocoButler)" 
        $objNotifyIcon.ShowBalloonTip(30000)  # Possible error so show if silent
        $mnuInstall.Enabled = $old_mnuInstall_Enabled # Restore the previous state if it didn't work
    }
    check_for_choco_old_problem

    $mnuCheck.Enabled = $true
    $timer.Start()
}

function do_upgrade_dialog {
    # Present a dialog asking if upgrade should proceed
    if ($outdated.Count -gt 0) {
        $timer.Stop()
        $msg = "Proceed with package upgrades?`n$($outdated.Count) packages are available to upgrade:`n$($outdated.name -join ', ')"
        $res = [System.Windows.Forms.MessageBox]::Show($msg,'ChocoButler','YesNo','Question')
        if ($res -eq 'Yes') {
            do_upgrade
            $next_check_time = (Get-Date) + (New-TimeSpan -Hours $settings.check_delay_hours)
            Write-Host "[$((Get-Date).toString())] Next outdated-check will be in $($settings.check_delay_hours) hours at approx: $($next_check_time.toString())"
            Set-Variable -Name "next_check_time" -Value $next_check_time -Scope Script  # Set the next time in the outer scope
        }
        $timer.Start()
    } else {
        # Do nothing! 
        Write-Host "[$((Get-Date).toString())] Clicked to upgrade, but nothing to upgrade, so nothing to do..."
    }
}

function check_for_outdated {
    $timer.Stop()
    $mnuCheck.Enabled = $false
    $mnuInstall.Enabled = $false
    $checkDate = Get-Date
    $objNotifyIcon.Text = "ChocoButler`nChecking for outdated packages..."
    $mnuMsg.Text = "Checking for outdated packages..."
    $mnuDate.Text = "Checking started: $($checkDate.toString())"
    Write-Host "[$($checkDate.toString())] Outdated-check started"
    check_for_choco_old_problem

    $outdated_raw = choco outdated -r --ignore-pinned  
    # Exit codes: https://docs.chocolatey.org/en-us/choco/commands/outdated#exit-codes
    if ($null -eq $outdated_raw) {
        $outdated = @()
    } Else {
        [array]$outdated = (ConvertFrom-Csv -InputObject $outdated_raw -Delimiter '|' -Header 'name','current','available','pinned')
        # For packages installed from files (i.e. during testing) they can show up as outdated, even though current==available. So filter these.
        [array]$outdated = $outdated.where( { [System.Version]$_.current -lt [System.Version]$_.available } )
    }
    if ($settings.test_mode) {
        if (-Not ($outdated.Count -gt 0)) {
            Write-Host "[$((Get-Date).toString())] TEST MODE! Faking an outdated package: 'GoogleChrome'"
            # We're in TEST MODE so, and there are no updates, so fake an outdated package (an @array containing one object)
            $outdated = @([PSCustomObject]@{
                name     = 'GoogleChrome'
                current  = '1.0'
                available = '1.1'
                pinned = $false
            })
        }
    }
    $outdated_csv = $outdated.name -join ', '  # For display in bubble
    $mnuDate.Text = "Last outdated check: $($checkDate.toString())"
    Set-Variable -Name "outdated" -Value $outdated -Scope Script  # Store the $outdated in the outer scope so it can be used by do_upgrade_dialog
    If ($outdated_csv -match 'Error retrieving') {
        Write-Host "[$((Get-Date).toString())] Error retrieving data"
        Write-Host $outdated_csv
        $objNotifyIcon.Text = "ChocoButler`nError retrieving data"
        $mnuMsg.Text = "Error retrieving data (see log file, via Advanced menu)"
        $mnuDate.Text = "Error occurred: $($checkDate.toString())"
        $objNotifyIcon.Icon = $icon_red        
        $ok = $false
    } Else {
        if ($outdated.Count -gt 0) {
            if ($outdated.Count -eq 1) {$plural = ""} Else {$plural = "s"}
            $objNotifyIcon.Icon = $icon_red
            $mnuInstall.Enabled = $true
            $objNotifyIcon.BalloonTipIcon = "Info" # Should be one of: None, Info, Warning, Error  
            $objNotifyIcon.BalloonTipText = "$($outdated.Count) outdated package$($plural):`n$outdated_csv"
            $objNotifyIcon.BalloonTipTitle = "Chocolately Outdated Packages"
            # register-objectevent $objNotifyIcon BalloonTipClicked BalloonClicked_event -Action { do_upgrade_dialog }        
            if (-Not($settings.silent)) {$objNotifyIcon.ShowBalloonTip(10000)}
            Write-Host "[$((Get-Date).toString())] Outdated-check complete; 'choco outdated' exit code: $($LastExitCode)"
            Write-Host "[$((Get-Date).toString())] $($outdated.Count) outdated package$($plural): $outdated_csv"
            
            if ($outdated_csv.length -gt 29) {
                $outdated_csv_short = $outdated_csv.SubString(0, 25)
                $outdated_csv_short = "$outdated_csv_short ..."   
            } Else {
                $outdated_csv_short = $outdated_csv
            }
            
            $objNotifyIcon.Text = "ChocoButler`n$($outdated.Count) outdated package$($plural): $outdated_csv_short"
            $mnuMsg.Text = "$($outdated.Count) outdated package$($plural): $outdated_csv_short"
            if ($settings.auto_install) { do_upgrade }

        } else {
            $objNotifyIcon.Text = "ChocoButler`nNo outdated packages"
            Write-Host "[$((Get-Date).toString())] No outdated packages found"
            $mnuMsg.Text = "No outdated packages"
            $objNotifyIcon.Icon = $icon
            $mnuInstall.Enabled = $false
        }
        $ok = $true
    }
    
    If ($settings.exit_if_no_outdated) {
        if ($outdated.Count -eq 0) {
            Write-Host "[$((Get-Date).toString())] Exiting since exit_if_no_outdated=True"
            if ($settings.test_mode) { Exit 1 } else { Stop-Process $pid }
        }
    }


    $timer.Start()
    $mnuCheck.Enabled = $true
    return $ok

}

#---------------------------------------------------------------------------------------------------------

$icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSScriptRoot+ "\chocolatey.ico")
$icon_red = [System.Drawing.Icon]::ExtractAssociatedIcon($PSScriptRoot+ "\chocolatey_red.ico")

$objNotifyIcon.Icon = $icon
$objNotifyIcon.Text = "ChocoButler"
$objNotifyIcon.Visible = $true

# Can't get the BalloonTipClicked event to work consistently.
# If you remove the System.Windows.Forms.ApplicationContext below then it works well, but the rest of the script is then flaky.
#Register-ObjectEvent $objNotifyIcon BalloonTipClicked -sourceIdentifier click_event { do_upgrade_dialog } | Out-Null
         
# Create a timer to check every minute if a new check is due.
# Do polling like this to support hibernate/sleep so after come of sleep/hibernate, and if N hours since last check, then one will trigger.
# This does making the timings of the checks less accurate (+- 1 minute) but that doesn't really matter.
function tick_check {
    # This function gets called every time the timer ticks
    pid_file_check  # Check the pid file is present and correct
    $now = Get-Date
    if ($now -gt $next_check_time) {
        $ok = check_for_outdated
        $end_time = Get-Date
        if ($ok) {
            # If the check failed, don't update time so it happens again in a minute
            $next_check_time = $end_time + (New-TimeSpan -Hours $settings.check_delay_hours)
            Write-Host "[$($end_time.toString())] Next outdated-check will be in $($settings.check_delay_hours) hours at approx: $($next_check_time.toString())"
            Set-Variable -Name "next_check_time" -Value $next_check_time -Scope Script  # Store the new next_time in the outer scope
        } Else {
            Write-Host "[$(($end_time).toString())] Following error, next outdated-check will be in 1 minute"
        }
    }
}

$timer.Interval = 60000  
$timer.Add_Tick( {tick_check} )
if ($settings.test_mode) {
    # Check immediately in test mode
    Write-Host "[$((Get-Date).toString())] TEST MODE! Starting outdated-check immediately."
    tick_check  # Do the first "tick" of the timer now
} elseif ($settings.immediate_first_check) {
    Write-Host "[$((Get-Date).toString())] Starting first outdated-check..."
    tick_check # Do the first "tick" of the timer now
} else {    
    Write-Host "[$((Get-Date).toString())] First outdated-check will start in 1 minute..."
}
$timer.Start()  # First check will occur in 1 minute when the timer triggers. Don't do it right away to prevent hammering on start-up.

# See: https://www.systanddeploy.com/2018/12/create-your-own-powershell.html
# [System.GC]::Collect() # Help reduce memory
$appContext = New-Object System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)










