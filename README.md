# ChocoButler - An automatic package upgrader for Chocolatey

ChocoButler is a small app that works with [Chocolatey](https://chocolatey.org/), periodically checking for outdated packages, and allowing them to be upgraded.

ChocoButler sits in the system tray (i.e. notification area) of Windows. Its icon changes colour and an alert pops-up when upgrades are available. See [screenshots](#screenshots) for examples.

Rather than running upgrades on a fixed schedule, ChocoButler alerts you when updates are available and allows you to start the upgrades at a time convenient for you. (If you just want regular, scheduled updates without user interaction there are better ways to achieve this, though you can do that too with ChocoButler if you really want to).

![ChocoButler Brown Icon](./img/chocobutler_48x48.png?raw=true) ![ChocoButler Red Icon](./img/chocobutler_red_48x48.png?raw=true)

## Installation & Running
The easiest way to install ChocoButler is via Chocolately. The [package](https://community.chocolatey.org/packages/chocobutler) in Chocolatey is named `chocobutler`. Use the Chocolatey GUI and search for "chocobutler" or install via the command line with `choco install chocobutler`. The Chocolatey package adds a shortcut to the startup folder so ChocoButler starts automatically with Windows, but it will not install any start menu icons.

For manual installation, [download](https://github.com/cokelid/ChocoButler/archive/refs/tags/v0.1.8.zip) the files, unzip to a folder, double-click the `chocobutler.bat` file.

Alternatively clone the [github repo](https://github.com/cokelid/ChocoButler.git) and run the `chocobutler.bat` file.

Note that ChocoButler is "portable" and does not require any installation. Just place the files in a folder, and double-click the `chocobutler.bat` file. If you don't like the software, exit ChocoButler from the menu, and then delete the folder. ChocoButler makes no changes to your system (unless you use it to install updates of course). If you edit your settings via the "Advanced" menu in ChocoButler then a settings file will be created.

If you want to see ChocoButler's logging messages, either run within Powershell (by running `chocobutler.ps1`), or run the `chocobutler_visible.bat` file instead. This .bat file runs ChocoButler with a visible console window, rather than hiding the window.

### Start with Windows
When installed via Chocolatey, a shortcut is added to your startup folder automatically, so that ChocoButler runs when Windows starts. To do this manually, copy a shortcut of the `chocobutler.bat` file to your startup folder as follows:

1) Open start-up folder: Press `Win+R` (to open run dialog), and type `shell:startup`
2) Right-click on the `chocobutler.bat` file and copy, then "Paste shortcut" in the startup folder


## Usage
ChocoButler will first check for outdated packages 1 minute after you start ChocoButler (and every N hours thereafter). This delay prevents your PC getting hammered at startup. If you're keen to check sooner, right-click on the brown ChocoButler icon in the system tray and click "Check for outdated packages now" (or change the `immediate_first_check` [setting](#immediate_first_check)).

Normally the brown ChocoButler icon is shown in the system tray. If packages are available for upgrade, the icon will turn red. When outdated packages are found, a popup will display also.

To install available upgrades, right-click on the system tray icon and select "Install upgrades...". This will install outdated package updates without prompting for confirmations. This effectively runs `choco upgrade <packages> --yes` under the covers.

By right-clicking the ChocoButler icon you can see when the last update or check occurred. You can also start the Chocolatey GUI (if installed) via the icon, and exit ChocoButler too.

See [screenshots](#screenshots) for examples.



## Screenshots

On detecting outdated packages, an alert pop-up is shown, and the ChocoButler icon in the system tray (notification area) turns red:

![Outdated package pop-up](./img/screenshot-01-alert.png?raw=true)

You may need to expand the system tray (notification area) with the up-arrow to see the icon. Hovering the mouse over the (red) icon displays the number (and names) of outdated packages:

![Tooltip showing number outdated packages](./img/screenshot-02-tooltip.png?raw=true)

Right-clicking the icon shows a menu, including the option to "Install upgrades...":

![Context menu from right-clicking icon](./img/screenshot-03-menu.png?raw=true)

A confirmation box, showing packages to be upgraded, is shown before installation:

![Upgrade confirmation dialog](./img/screenshot-04-confirm.png?raw=true)

A pop-up displays when upgrades are complete:

![Upgrade success pop-up](./img/screenshot-05-success.png?raw=true)

When no outdated packages are available for upgrade (e.g. post-install) the icon returns to the regular icon. Hovering over the icon displays "No outdated packages":

![Normal icon for no outdated packages](./img/screenshot-06-post-install.png?raw=true)



## Configuration & Settings
Default settings (as detailed below) will be in place unless/until the user selects `Edit ChocoButler Settings file` via the `Advanced`. At that point a `settings.json` file will be created (in `%APPDATA%`).

Edit this file to configure ChocoButler. The following settings are available:

### `check_delay_hours`
By default ChocoButler checks for outdated packages every 12 hours. To change this, edit the `settings.json` file and change the `check_delay_hours` value.

### `silent`
Suppress alert pop-ups by setting `silent` to `true`. Alerts will still be shown for warnings and errors, even with this setting turned on.

### `exit_if_no_outdated`
Normally ChocoButler will check in the background for outdated packages every few hours. However if `exit_if_no_outdated` is set to `true`, ChocoButler will exit after an outdated-check find no packages are available for upgrade.

You may want to pair this with the `immediate_first_check` setting.

### `immediate_first_check`
By default, ChocoButler waits 1 minute before doing its first outdated-check; this helps prevent hammering the PC on startup. Set `immediate_first_check` to `true` to have the first check start immediately.

### `auto_install`
By default, ChocoButler will alert you to available updates, and you then start the installation process (from the system tray icon) at a convenient time. This way you don't upgrade Zoom in the middle of a video meeting, say. However if you want the upgrade installation to occur automatically, and as soon as outdated packages are available, you can change the `auto_install` setting to `true`.

Even with `auto_install` turned on, you'll probably still need to click OK in a dialog to allow choco to make changes, and these requests could pop up at any time (and so could be annoying).
To avoid this, you could run the whole Powershell script as Admin, then you won't get prompted, but this is probably not a great idea from a security point of view. Overall ChocoButler was not built for fully automated updates, so this will likely be clunky.

### `test_mode`
Generally the `test_mode` setting should be left as `false`. See [Testing & Development](#testing--development) below for more details.

### Apply Changes
You must restart ChocoButler for settings changes to take effect.



## The Dreaded `choco.exe.old` Problem
Often, when Chocolatey updates itself, the `choco` command will start issuing errors/warnings like this:

 `Access to the path 'C:\ProgramData\chocolatey\choco.exe.old' is denied.`

These warning messages prevent the output of `choco` from being parsed correctly.

The problem occurs when Chocolatey is trying to delete an old .exe file from a previous version, but is unable to do so. This can generally be fixed by running `choco` as admin.

ChocoButler will check for this problem periodically, and if encountered gives the option to "repair". The repair option simply runs `choco` as admin to allow it to fix itself.



## Testing & Development

There is a built in _test mode_ to help when testing and developing the app. You can enable the _test mode_ by setting `"test_mode": true` in the `settings.json` file.

The test_mode leads to four changes in behaviour:

1) The first check for outdated-packages occurs as soon as the script starts (not one minute after as is the normal behaviour)
2) If no outdated packages are found, the GoogleChrome package is added to the outdated list for testing
3) No changes are made during the installation of upgrades, it just does a dry-run (i.e. the `--noop` switch is passed to `choco upgrade`)
4) On exit, `Exit` is called rather than `Stop-Process`. This is less likely to kill your IDE. YMMV.

The above changes allow you to quickly test the main check->upgrade workflow, without having to wait for an actual outdated package to appear.











