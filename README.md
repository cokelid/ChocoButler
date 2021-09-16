# ChocoButler - An automatic updater for Chocolatey
ChocoButler is a small app that works with [Chocolatey](https://chocolatey.org/), periodically checking for outdated packages, and allowing them to be upgraded.

ChocoButler sits in the system tray (i.e. notification area) of Windows. Its icon changes colour and an alert pops-up when upgrades are available. See [screenshots](#screenshots) for examples.

Rather than running upgrades on a fixed schedule, ChocoButler alerts you when updates are available and allows you to start the upgrades at a time convenient for you. (If you just want regular, scheduled updates without user interaction there are better ways to achieve this, though you can do that too with ChocoButler if you really want to).


## Installation & Running
In short: [download](https://github.com/cokelid/ChocoButler/archive/refs/tags/v0.1.2.zip) the files, unzip to a folder, double-click the `choco_butler.bat` file.

Alternatively clone the [github repo](https://github.com/cokelid/ChocoButler.git) and run the `choco_butler.bat` file.

To be clear, you don't need to install ChocoButler as such, just place the files in a folder, and double-click the `choco_butler.bat` file. If you don't like it, exit ChocoButler from the menu, and then delete the folder. ChocoButler makes no changes to your system (unless you use it to install updates of course).

You will need a recent version of Chocolatey.

If you want to see ChocoButler's logging messages, either run within Powershell (by running `choco_butler.ps1`), or run the `choco_butler_visible.bat` file instead. This .bat file runs ChocoButler with a visible console window, rather than hiding the window.
### Start with Windows
To set up ChocoButler to run every time you start Windows, copy a shortcut of the `choco_butler.bat` file to your startup folder as follows:

1) Open start-up folder: Press `Win+R` (to open run dialog), and type `shell:startup`
2) Right-click on the `choco_butler.bat` file and copy, then "Paste shortcut" in the startup folder


## Usage
ChocoButler will first check for outdated packages 1 minute after you start ChocoButler (and every N hours thereafter). This delay prevents your PC getting hammered at startup. If you're keen to check sooner, right-click on the Chocolatey icon in the system tray and click "Check for outdated packages now".

Normally the regular blue/brown Chocolatey icon is shown in the system tray. If packages are available for upgrade, the icon will turn red. When updated packages are found, a popup will display also.

To install available updates, right-click on the system tray icon and select "Install upgrades...". This will install outdated package updates without prompting for confirmations. This effectively runs `choco upgrade <packages> --yes` under the covers.

By right-clicking the ChocoButler icon you can see when the last update or check occurred. You can also start the Chocolatey GUI (if installed) via the icon, and exit ChocoButler too.

See [screenshots](#screenshots) for examples.



## Screenshots

On detecting outdated packages, an alert pop-up is shown, and the Chocolatey icon in the system tray (notification area) turns red:

![Outdated package pop-up](./img/screenshot-01-alert.png?raw=true)

You may need to expand the system tray (notification area) with the up-arrow to see the icon. Hovering the mouse over the (red) icon displays the number (and names) of outdated packages:

![Tooltip showing number outdated packages](./img/screenshot-02-tooltip.png?raw=true)

Right-clicking the icon shows a menu, including the option to "Install upgrades...":

![Context menu from right-clicking icon](./img/screenshot-03-menu.png?raw=true)

A confirmation box, showing packages to be upgraded, is shown before installation:

![Upgrade confirmation dialog](./img/screenshot-04-confirm.png?raw=true)

A pop-up displays when upgrades are complete:

![Upgrade success pop-up](./img/screenshot-05-success.png?raw=true)

When no outdated packages are available for upgrade (e.g. post-install) the icon returns to the regular blue and brown Chocolatey icon. Hovering over the icon displays "No outdated packages":

![Normal icon for no outdated packages](./img/screenshot-06-post-install.png?raw=true)



## Configuration & Settings
Settings exist in the `settings.json` text file. Edit this file to configure ChocoButler. The following settings are available:

### `check_delay_hours`
By default ChocoButler checks for outdated packages every 12 hours. To change this, edit the `settings.json` file and change the `check_delay_hours` value.

### `auto_install`
By default, ChocoButler will alert you to available updates, and you then start the installation process (from the system tray icon) at a convenient time. This way you don't upgrade Zoom in the middle of a video meeting, say. However if you want the upgrade installation to occur automatically, and as soon as outdated packages are available, you can change the `auto_install` setting to `true`.

Even with auto_install turned on, you'll probably still need to click a box to allow choco to make changes, and these requests could pop up at any time (and so could be annoying).
To avoid this, you could run the whole Powershell script as Admin, then you won't get prompted (but this is probably not a great idea from a security point of view). Overall ChocoButler was not built for fully automated updates, so this will seem a bit clunky.

### `test_mode`
Generally the `test_mode` setting should be left as `false`. See [Testing & Development](#testing--development) below for more details.

### Apply Changes
You must restart ChocoButler for settings changes to take affect.

## Testing & Development

There is a built in _test mode_ to help when testing and developing the app. You can enable the _test mode_ by setting `"test_mode": true` in the `settings.json` file.

The test_mode leads to four changes in behaviour:

1) The first check for outdated-packages occurs as soon as the script starts (not one minute after as is the normal behaviour)
2) If no outdated packages are found, the GoogleChrome package is added to the outdated list for testing
3) No changes are made during the installation of upgrades, it just does a dry-run (i.e. the `--noop` switch is passed to `choco upgrade`)
4) On exit, `Exit` is called rather than `Stop-Process`. This is less likely to kill your IDE. YMMV.

The above changes allow you to quickly test the main check->upgrade workflow, without having to wait for an actual outdated packages to appear.

## TODO
1) Ideally if you click on the "Updates Available" pop-up message you'd be able to start the install, but I can't get the `BalloonTipClicked` object event to work reliably. See comments in code.
1) Make some better icons
1) Read settings changes on the fly
1) Edit settings from the app 
1) Add option/setting to prevent the update-window from closing when complete
1) Create a chocolatey install package for ChocoButler, so it can be installed via chocolatey

