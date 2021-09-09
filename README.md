# ChocoButler - An automated updater for Chocolatey

ChocoButler is a small app that works with [Chocolatey](https://chocolatey.org/), periodically checking for outdated packages that can be upgraded.

Rather than running upgrades on a fixed schedule, ChocoButler alerts you when updates are available and allows to start the upgrades at a time convenient for you If you just want regular, scheduled updates without user interaction there are better ways to achieve this (though you can do that too with ChocoButler if you really want to).

ChocoButler sits in the system tray (i.e. notification area) of Windows. Its icon changes colour and an alert will pop-up when upgrades are avaiable.

## Installation
You don't need to install ChocoButler - it's literally five files (a Powershell script, a settings file, two icon files, and a .bat file to start it). Okay, six files including this README.

To test it out, double click the `choco_butler.bat` file (or run the `choco_butler.ps1` file in Powershell, from where you can see logging messages).

To set it up to run everytime you start Windows, copy a shortcut of the .bat file to your startup folder as follow:

1) Open start-up folder: Press `Win+R` (to open run dialog), and type `shell:startup`
2) Right-click on the `choco_butler.bat` file and copy, then "Paste shortcut" in the startup folder



## Usage

The first check for outdated packages will occur 1 minute after you start ChocoButler (and then every N hours thereafter). This dealy prevents your PC getting hammered at startup. If you're keen, right-click on the Chocolatey icon in the system tray and click "Check for outdated packages now".

Normally the regular blue/brown Chocolatey icon is shown in the system tray. If packages are available for upgrade, the icon will turn red. When updated packages are found, a popup will display also.

To install avaialble updates, right-click on the system tray icon and select "Install updates". From the icon you can see when the last update or check occurred. You can also start the Chocolatey GUI (if installed) via the icon, and exit ChocoButler too.

Updates are 

## Configuration & Settings
Settings exist in the `settings.json` text file. Edit this file to configure ChocoButler.

### check_delay_hours
By default ChocoButler checks for outdated packages every 12 hours. To change this, edit the `settings.json` file and change the `check_delay_hours` value.

### auto_install
By default, ChocoButler will alert you to available updates, and you then start the installation process (from the system tray icon) at a convenient time. This way you don't upgrade Zoom in the middle of a video meeting, say. However if you want the upgrade installation to occur automatically, and as soon as outdated packages are available, you can change the `auto_install` setting to `true`.

Even with auto_install turned on, you'll still need to click a box to allow choco to make changes, and these requests could pop up at any time (and so could be annoying).
To avoid this, you could run the whole Powershell script as Admin, then you won't get prompted. This is probably not a great idea from a security point of view, and has not been tested. Overall ChocoButler was not built for automatic updates.

### test_mode
Generally the `test_mode` setting should be left as `false`. See [Testing & Development](#testing-development) below for more details.

### Restart
You must restart ChocoButler for settings changes to take affect.


## TESTING & DEVELOPMENT

There is a built in _test mode_ to help when testing and developing the app. You can enable the _test mode_ by setting `"test_mode": true` in the `settings.json` file.

The test_mode leads to three changes in behaviour:

1) The first check for outdated-packages occurs as soon as the script starts (not one minute after as is the normal beahviour)
2) If no outdated packages are found, a dummy package ("DummyTest") is added to the outdated list
3) No changes are made during update installation, it just does a dry-run (i.e. the `--noop` switch is passed to `choco upgrade`)

This allows you to quickly test the main check->upgrade workflow, without having to wait for actual outdated packages to occur.

## TODO

1) Ideally if you click on the "Updates Available" pop-up message you'd be able to start the install, but I can't get the `BalloonTipClicked` object event to work reliably. See comments in code.
1) Make some better icons
1) Read settings changes on the fly
1) Edit settings from the app (even just open settings.json in notepad)
1) Add a setting to prevent the update-window from closing when complete
1) Create a chocolatey install package for ChocoButler, so it can be installed via chocolatey

