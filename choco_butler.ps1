# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted
# Code taken from: https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-powershell-1.0/ff730952(v=technet.10)

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

if ((Get-Host).Version -lt '5.1') {
    # Do we need this? Not tested on any other PS version, and not clear if the dialog box would work in older PS?
    Write-Host "ChocoButler requires Powershell 5.1 or above."
    [System.Windows.Forms.MessageBox]::Show("ChocoButler requires Powershell 5.1 or above.`nChocoButler will now exit.", "Powershell Version Error", 'OK', 'Error')
    Exit 1
}

# INIT outer vars (Script scope) used in functions.
$objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$next_check_time = Get-Date
$timer = New-Object System.Windows.Forms.Timer
[array]$outdated = @()
$settings = [PSCustomObject]@{check_delay_hours=12; auto_install=$False; test_mode=$False}

function assert($condition, $message, $title) {
    if (-Not $condition) {
        $timer.Stop()
        Write-Host $message
        Write-Host '(Click OK in dialog box to Exit)'
        [System.Windows.Forms.MessageBox]::Show($message, $title, 'OK', 'Error')
        $objNotifyIcon.Dispose()
        $timer.Dispose()
        if ($settings.test_mode) { Exit 1 } else { Stop-Process $pid }
    }
}

function load_settings {
    $settingsPath = $PSScriptRoot+"\settings.json"
    assert (Test-Path $settingsPath) "Cannot find settings.json file:`n$($settingsPath)`nChocoButler will now exit." "ChocoButler Settings Error"
    $s = Get-Content -Raw -Path $settingsPath | ConvertFrom-Json  # Will not fail if file missing
    $ok = ($s -is [System.Object])
    assert $ok "Cannot load settings.json file. Syntax Error?:`n$($settingsPath)`nChocoButler will now exit." "ChocoButler Settings Error"
    # Ensure $s has same settings (Properties) as existing $settings
    Foreach ($k in $settings.PSObject.Properties.Name) {
        assert (Get-Member -InputObject $s -Name $k) "Could not find '$k' in settings.json file" "ChocoButler Settings Error"
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
# Check Chocolately version. There must be a better way than parsing the whole string?
assert ((choco -? | Out-String) -match '(?m)^Chocolatey v([\d\.]+)') "Requires Chocolatey Version 0.11.1 or higher. Cannot determine your version.`nChocoButler will now exit" "Chocolately Version Error"  # (?m) modifies regex for multiline match
$choco_ver = $Matches[1]  # The pevious -match will populate $Matches if True
assert ([System.Version]::Parse($choco_ver) -ge '0.11.1') "Requires Chocolatey Version 0.11.1 or higher.`nYou have $($Matches[0]).`nChocoButler will now exit." "Chocolately Version Error"
      


# Check we're not getting errors that will prevent parsing the choco command output
function check_choco {
    # If chocolately updates itself it can get confused. Check for this by running trivial 'choco help' command.
    # If it's goes wrong you'll see something like:
    #         "Access to the path 'C:\ProgramData\chocolatey\choco.exe.old' is denied."
    $res = (choco help | Select-String 'choco.exe.old'' is denied')
    assert (-Not ($res.Count -gt 0)) "Chocolately is no longer working properly (it probably updated itself).`nDelete 'choco.exe.old' file.`nReboot is likely required :-(`nChocoButler will now exit.`n`n`n$res" "Chocolately Error"
}
check_choco



$gui_obj = Get-Command chocolateygui  # Returns an object
if ( $gui_obj.Count -gt 0 ) {
    $gui = $gui_obj.Source  # This is the path
} else {
    $gui = "C:\Program Files (x86)\Chocolatey GUI\ChocolateyGui.exe"
    if (-Not (Test-Path $gui)) {
        $gui = "C:\Program Files\Chocolatey GUI\ChocolateyGui.exe"
        if (-Not (Test-Path $gui)) {
            $lnk = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Chocolatey GUI.lnk"
            $sh = New-Object -ComObject WScript.Shell
            $gui = $sh.CreateShortcut($lnk).TargetPath
            if (-Not (Test-Path $gui)) {
                $gui = ""
            }
        }
    }
}

# Create the menu entry for opening Chocolatey GUI
$mnuOpen = New-Object System.Windows.Forms.MenuItem 
if ( Test-Path $gui ) {
    $mnuOpen.Text = "Open Chocolately GUI"
    $mnuOpen.add_Click({
        Start-Process -FilePath $gui
    })
} Else {
    $mnuOpen.Text = "(Chocolately GUI not installed)"
    $mnuOpen.Enabled = $false
}


$mnuCheck = New-Object System.Windows.Forms.MenuItem
$mnuCheck.Text = "Check for outdated packages now"
$mnuCheck.add_Click({
    check_for_outdated
    $next_check_time = (Get-Date) + (New-TimeSpan -Hours $settings.check_delay_hours)
    Write-Host "[$((Get-Date).toString())] Next outdated-check will be in $($settings.check_delay_hours) hours at approx: $($next_check_time.toString())"
    Set-Variable -Name "next_check_time" -Value $next_check_time -Scope Script  # Set the next time in the outer scope
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
    if ($settings.test_mode) { Exit 1 } else { Stop-Process $pid }
})

$mnuInstall = New-Object System.Windows.Forms.MenuItem
$mnuInstall.Text = "Install upgrades..."
$mnuInstall.Enabled = $false
$mnuInstall.add_Click({
   do_upgrade_dialog   
})

$context_menu = New-Object System.Windows.Forms.ContextMenu
$objNotifyIcon.ContextMenu = $context_menu
$objNotifyIcon.contextMenu.MenuItems.AddRange($mnuInstall)
$objNotifyIcon.contextMenu.MenuItems.AddRange($mnuMsg)
$objNotifyIcon.contextMenu.MenuItems.AddRange($mnuDate)
$objNotifyIcon.contextMenu.MenuItems.AddRange($mnuCheck)
$objNotifyIcon.contextMenu.MenuItems.AddRange($mnuOpen)
$objNotifyIcon.contextMenu.MenuItems.AddRange($mnuExit)



function do_upgrade {
    $timer.Stop()
    $old_mnuInstall_Enabled = $mnuInstall.Enabled
    $mnuInstall.Enabled = $false
    $mnuCheck.Enabled = $false
    $objNotifyIcon.Text = "ChocoButler`nUpgrading Packages..."
    $mnuMsg.Text = "Upgrading all packages..."
    #$objNotifyIcon.BalloonTipIcon = "Info" # Should be one of: None, Info, Warning, Error  
    #$objNotifyIcon.BalloonTipText = "Chocolately UPGRADE of all packages has STARTED"
    #$objNotifyIcon.BalloonTipTitle = "ChocoButler" 
    #$objNotifyIcon.ShowBalloonTip(3000)
    $upgradeStart = Get-Date
    $mnuDate.Text = "Upgrading began: $($upgradeStart.toString())"
    Write-Host "[$($upgradeStart.toString())] Upgrading began"
    # Run the choco command as admin. The following is the same as "choco upgrade all --yes"
    If ($settings.test_mode) {
        Write-Host "[$($upgradeStart.toString())] TEST MODE! Nothing will be updated. Running with --noop."
        $arg_list = "upgrade all --yes --noop"
    } Else {
        $arg_list = "upgrade all --yes"
    }
    try {
        Start-Process -FilePath "choco" -Verb RunAs -ArgumentList $arg_list -Wait          
        $exitCode = $LastExitCode # Exit codes: https://docs.chocolatey.org/en-us/choco/commands/upgrade#exit-codes
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
    $upgradeEnd = Get-Date
    Write-Host "[$($upgradeEnd.toString())] Upgrade ended with Exit Code: $exitCode"
    $mnuDate.Text = "Upgrade ended: $($upgradeEnd.toString())"
    $objNotifyIcon.Text = "ChocoButler"
    if ($exitCode -eq 0) {  
        $mnuMsg.Text = "Upgrade successful!"
        $objNotifyIcon.BalloonTipIcon = "Info" # Should be one of: None, Info, Warning, Error  
        $objNotifyIcon.BalloonTipText = "Chocolately UPGRADE SUCCESS!"
        $objNotifyIcon.BalloonTipTitle = "ChocoButler"
        $objNotifyIcon.ShowBalloonTip(4000)
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
            $msg = "Unknown error occurred. Exit code: $exitCode`n$($_.Exception)"
            $type = "Error"
        }
        $mnuMsg.Text = $msg
        $objNotifyIcon.BalloonTipIcon = $type # Should be one of: None, Info, Warning, Error  
        $objNotifyIcon.BalloonTipText = $msg
        $objNotifyIcon.BalloonTipTitle = "Chocolately Upgrade (ChocoButler)" 
        $objNotifyIcon.ShowBalloonTip(30000)
        $mnuInstall.Enabled = $old_mnuInstall_Enabled # Restore the previous state if it didn't work
    }
    check_choco
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
    $checkDate = Get-Date
    $objNotifyIcon.Text = "ChocoButler`nChecking for outdated packages..."
    $mnuMsg.Text = "Checking for outdated packages..."
    $mnuDate.Text = "Checking started: $($checkDate.toString())"
    Write-Host "[$($checkDate.toString())] Outdated-check started"
    check_choco
    $outdated_raw = choco outdated -r    
    $exitCode = $LastExitCode # Exit codes: https://docs.chocolatey.org/en-us/choco/commands/outdated#exit-codes
    # Check for error
    [array]$outdated = ConvertFrom-Csv -InputObject $outdated_raw -Delimiter '|' -Header 'name','current','available','pinned'
    if ($settings.test_mode) {
        if (-Not ($outdated.Count -gt 0)) {
            Write-Host "[$((Get-Date).toString())] TEST MODE! Adding dummy outdated package: 'DummyTest'"
            # We're in TEST MODE so, and there are no updates, so add a fake dummy package (an @array containing one object)
            $outdated = @([PSCustomObject]@{
                name     = 'DummyTest'
                current  = '1.0'
                avaiable = '1.1'
                pinned = $false
            })
        }
    }
    $outdated_csv = $outdated.name -join ', '  # For display in bubble    
    $mnuMsg.Text = "$($outdated.Count) outdated packages"
    $mnuDate.Text = "Last outdated check: $($checkDate.toString())"
    Set-Variable -Name "outdated" -Value $outdated -Scope Script  # Store the $outdated in the outer scope so it can be used by do_upgrade_dialog

    if ($outdated.Count -gt 0) {
        $objNotifyIcon.Icon = $icon_red
        $mnuInstall.Enabled = $true
        $objNotifyIcon.BalloonTipIcon = "Info" # Should be one of: None, Info, Warning, Error  
        $objNotifyIcon.BalloonTipText = "$($outdated.Count) outdated pacakages`nOutdated: $outdated_csv"
        $objNotifyIcon.BalloonTipTitle = "Chocolately Outdated Packages"
        # register-objectevent $objNotifyIcon BalloonTipClicked BalloonClicked_event -Action { do_upgrade_dialog }        
        $objNotifyIcon.ShowBalloonTip(10000)
        Write-Host "[$((Get-Date).toString())] Outdated-check complete; 'choco outdated' exit code: $($LastExitCode)"
        Write-Host "[$((Get-Date).toString())] $($outdated.Count) outdated pacakages: $outdated_csv"
        $objNotifyIcon.Text = "ChocoButler`n$($outdated.Count) outdated packages"    
        if ($settings.auto_install) { do_upgrade }

    } else {
        $objNotifyIcon.Text = "ChocoButler`nNo outdated packages"
        Write-Host "[$((Get-Date).toString())] No outdated packages found"
        $mnuMsg.Text = "No outdated packages"
        $objNotifyIcon.Icon = $icon
        $mnuInstall.Enabled = $false
    }
    
    $timer.Start()
    $mnuCheck.Enabled = $true

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
$timer.Interval = 60000  
$timer.Add_Tick({
    $now = Get-Date
    if ($now -gt $next_check_time) {
        Write-Host "[$($now.toString())] Time for new outdated-check (as of $($next_check_time.toString()))."        
        check_for_outdated
        $end_time = Get-Date
        $next_check_time = $end_time + (New-TimeSpan -Hours $settings.check_delay_hours)       
        Write-Host "[$($end_time.toString())] Next outdated-check will be in $($settings.check_delay_hours) hours at approx: $($next_check_time.toString())"
        Set-Variable -Name "next_check_time" -Value $next_check_time -Scope Script  # Store the new next_time in the outer scope
    }
})
if ($settings.test_mode) {
    # Check immediately in test mode
    Write-Host "[$((Get-Date).toString())] TEST MODE! Starting outdated-check immediately."
    check_for_outdated
} else {
    Write-Host "[$((Get-Date).toString())] First outdated-check will start in 1 minute..."
}
$timer.Start()  # First check will occur in 1 minute when the timer triggers. Don't do it right away to prevent hammering on start-up.

# [System.GC]::Collect() # Help reduce memory
$appContext = New-Object System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)
