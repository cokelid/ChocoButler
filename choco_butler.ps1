﻿# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted
# Code taken from: https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-powershell-1.0/ff730952(v=technet.10)

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

Get-Variable

if ((Get-Host).Version -lt '5.1') {
    # Do we need this? Not tested on any other PS version, and not clear if the dialog box would work in older PS?
    [System.Windows.Forms.MessageBox]::Show("Choco Butler requires Powershell 5.1 or above.`nChoco Butler will now exit.", "Powershell Version Error", 'OK', 'Error')
    Stop-Process $pid
}


function load_settings {
    $settingsPath = $PSScriptRoot+"\settings.json"
    $settings = Get-Content -Raw -Path $settingsPath | ConvertFrom-Json  # Will not fail if file missing
    $ok = ($settings -is [System.Object]) -AND (Get-Member -inputobject $settings -name "check_delay_hours")
    if (-Not $ok) {
        [System.Windows.Forms.MessageBox]::Show("Cannot load settings.json file:`n$($settingsPath)`nChoco Butler will now exit.", "Choco Butler Settings Error", 'OK', 'Error')
        $objNotifyIcon.Dispose()
        Stop-Process $pid    
    }
    Write-Host "[$((Get-Date).toString())] SETTINGS: $settings"
    return $settings
}

# INIT outer vars (Script scope) used in functions.
$settings = load_settings
$next_check_time = Get-Date
$objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$timer = New-Object System.Windows.Forms.Timer
$outdated = @()


# Check that choco is installed
$choco = Get-Command choco
if ($choco.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("Cannot find a choco installation.`nEnsure 'choco.exe' is on your path.`nChoco Bultler will now exit.", "Chocolately Not Installed", 'OK', 'Error')
    $objNotifyIcon.Dispose()
    Stop-Process $pid
}


# Create the menus for systray icon
$mnuOpen = New-Object System.Windows.Forms.MenuItem
if ( (Get-Command chocolateygui).Count -eq 0 ) {
    $mnuOpen.Text = "Chocolately GUI not installed"
    $mnuOpen.Enabled = $false
} Else {
    $mnuOpen.Text = "Open Chocolately GUI"
    $mnuOpen.add_Click({
        chocolateygui
    })
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
$mnuMsg.Text = "Updates available: ???"
$mnuMsg.Enabled = $false

$mnuDate = New-Object System.Windows.Forms.MenuItem
$mnuDate.Text = "Last checked: ???"
$mnuDate.Enabled = $false

$mnuExit = New-Object System.Windows.Forms.MenuItem
$mnuExit.Text = "Exit"
$mnuExit.add_Click({
    $objNotifyIcon.Dispose()
    Stop-Process $pid
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


function check_choco {
    # If chocolately updates itself it can get confused. Check for this by running trivial 'choco help' command.
    # If it's goes wrong you'll see something like:
    #         "Access to the path 'C:\ProgramData\chocolatey\choco.exe.old' is denied."
    $res = (choco help | Select-String 'choco.exe.old'' is denied')
    if ($res.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show("Chocolately is no longer working properly (it probably updated itself).`nReboot is likely required :-(`nOr delete 'choco.exe.old' file.`nChoco Bultler will now exit.", "Chocolately Error", 'OK', 'Error')
        $objNotifyIcon.Dispose()
        Stop-Process $pid    
    }
}

function do_upgrade {
    $timer.Stop()
    $old_mnuInstall_Enabled = $mnuInstall.Enabled
    $mnuInstall.Enabled = $false
    $mnuCheck.Enabled = $false
    $objNotifyIcon.Text = "Choco Butler`nUpgrading Packages..."
    $mnuMsg.Text = "Upgrading all packages..."
    #$objNotifyIcon.BalloonTipIcon = "Info" # Should be one of: None, Info, Warning, Error  
    #$objNotifyIcon.BalloonTipText = "Chocolately UPGRADE of all packages has STARTED"
    #$objNotifyIcon.BalloonTipTitle = "Choco Butler" 
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
    $objNotifyIcon.Text = "Choco Butler"
    if ($exitCode -eq 0) {  
        $mnuMsg.Text = "Upgrade successful!"
        $objNotifyIcon.BalloonTipIcon = "Info" # Should be one of: None, Info, Warning, Error  
        $objNotifyIcon.BalloonTipText = "Chocolately UPGRADE SUCCESS!"
        $objNotifyIcon.BalloonTipTitle = "Choco Butler"
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
        $objNotifyIcon.BalloonTipTitle = "Chocolately Upgrade (Choco Butler)" 
        $objNotifyIcon.ShowBalloonTip(30000)
        $mnuInstall.Enabled = $old_mnuInstall_Enabled # Restore the previous state if it didn't work
    }
    check_choco
    $mnuCheck.Enabled = $true
    $timer.Start()
}

function do_upgrade_dialog {
    # Present a dialog asking if upgrade should proceed
    # This is called if the Balloon Tip is called

    if ($outdated.Count -gt 0) {
        $timer.Stop()
        $msg = "Proceed with package upgrades?`n$($outdated.Count) packages are available to upgrade:`n$($outdated.name -join ', ')"
        $res = [System.Windows.MessageBox]::Show($msg,'Choco Butler','YesNo','Question')
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
    $objNotifyIcon.Text = "Choco Butler`nChecking for Outdated Packages..."
    $mnuMsg.Text = "Checking for outdated packages..."
    $mnuDate.Text = "Checking started: $($checkDate.toString())"
    Write-Host "[$($checkDate.toString())] Outdated-check started"
    check_choco
    $outdated = choco outdated -r | ConvertFrom-Csv -Delimiter '|' -Header 'name','current','available','pinned'
    if ($settings.test_mode) {
        if (-Not ($outdated.Count -gt 0)) {
            Write-Host "[$((Get-Date).toString())] TEST MODE! Adding dummy outdated package: 'DummyTestPackageChocoButler'"
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
        $objNotifyIcon.Text = "Choco Butler`n$($outdated.Count) outdated packages"    
        if ($settings.auto_install) { do_upgrade }

    } else {
        $objNotifyIcon.Text = "Choco Butler`nNo outdated packages"
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
$objNotifyIcon.Text = "Choco Butler"
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