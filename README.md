# ChocoButler - An automatic package upgrader for Chocolatey

ChocoButler is a native Windows application that works with [Chocolatey](https://chocolatey.org/), periodically checking for outdated packages, and allowing them to be upgraded.

ChocoButler sits in the system tray (notification area) of Windows. Its icon changes colour and an alert pops-up when upgrades are available. See [screenshots](#screenshots) for examples.

Rather than running upgrades on a fixed schedule, ChocoButler alerts you when updates are available and allows you to start the upgrades at a time convenient for you. 

![ChocoButler Brown Icon](./img/chocobutler_48x48.png?raw=true) ![ChocoButler Red Icon](./img/chocobutler_red_48x48.png?raw=true)

## What's New in Version 2 (July 2025)

Version 2 is a complete rewrite of ChocoButler as a native Windows application:

- **Native Windows App**: No more PowerShell scripts or console windows
- **Better UI**: Click notifications to install updates, improved menu interactions
- **Enhanced Features**: Better settings management
- **Modern Architecture**: Built with .NET 8.0 for better performance and reliability

## Installation & Running

### Install via Chocolatey
The easiest way to install ChocoButler is via Chocolatey. The [package](https://community.chocolatey.org/packages/chocobutler) in Chocolatey is named `chocobutler`. Use the Chocolatey GUI and search for "chocobutler" or install via the command line with `choco install chocobutler`.

The Chocolatey package adds a shortcut to the startup folder so ChocoButler starts-up automatically with Windows, and also adds an entry to the Start Menu.

To suppress the Start-Up or Start-Menu additions, install via the command line with the following params:
```
choco install chocobutler --params "'/NoStartUp'"
choco install chocobutler --params "'/NoStartMenu'"
choco install chocobutler --params "'/NoStartMenu /NoStartUp'"
```

### Manual Install
For manual installation, [download](https://github.com/cokelid/ChocoButler/releases) the latest release, extract the files to a folder, and run `ChocoButler.exe` in the `package/tools` folder 

Alternatively clone the [github repo](https://github.com/cokelid/ChocoButler.git) and build the project.

### Requirements
- **Windows 10/11**
- **Chocolatey** package manager
- **.NET 8.0 Runtime** (will be installed automatically via Chocolatey)

## Usage

ChocoButler will first check for outdated packages on start-up, and every N hours thereafter. To check on-demand, right-click on the ChocoButler icon in the system tray and click "Check for outdated packages now".

Normally the brown ChocoButler icon is shown in the system tray. If packages are available for upgrade, the icon will turn red. When outdated packages are found, a popup will display also.

### Installing Updates
There are several ways to install available upgrades:

- **Right-click menu**: Right-click on the system tray icon and select "Install updates..."
- **Double-click**: Double-click the system tray icon to install all updates
- **Click notification**: Click on the notification popup to install updates
- **Individual packages**: Right-click → "Outdated Packages" → select specific packages

This will install outdated package updates with administrator privileges. This effectively runs `choco upgrade <packages> --yes` under the covers.

### Menu Options
By right-clicking the ChocoButler icon you can:
- View outdated packages and their details
- Install all updates or individual packages
- Check for updates manually
- Access settings and configuration
- Open Chocolatey GUI (if installed)
- View advanced options and help

See [screenshots](#screenshots) for examples.

## Screenshots

On detecting outdated packages, an alert pop-up is shown:

![Outdated package pop-up](./img/screenshot-01-alert.png?raw=true)

You may need to expand the system tray (notification area) with the up-arrow to see the icon. Hovering the mouse over the (red) icon displays the number of outdated packages:

![Tooltip showing number outdated packages](./img/screenshot-02-tooltip.png?raw=true)

Right-clicking the icon shows a menu, including the option to "Install updates...":

![Context menu from right-clicking icon](./img/screenshot-03-menu.png?raw=true)

A confirmation box, showing packages to be upgraded, is shown before installation:

![Upgrade confirmation dialog](./img/screenshot-04-confirm.png?raw=true)

A pop-up displays when upgrades are complete:

![Upgrade success pop-up](./img/screenshot-05-success.png?raw=true)

When no outdated packages are available for upgrade (e.g. post-install) the icon returns to the regular icon. Hovering over the icon displays "No updates available":

![Normal icon for no updates available](./img/screenshot-06-post-install.png?raw=true)

## Configuration & Settings

Default settings will be in place unless/until the user selects `Settings...` via the system tray menu. At that point a `settings-v2.json` file will be created (in `%APPDATA%\ChocoButler\`).

The following settings are available:

- **Periodically Check for Updates**  Enable or disable automatic periodic checks for outdated packages using the "Enable Periodic Checks" option in the Settings dialog.
    - **Check Interval Hours** By default, ChocoButler checks for outdated packages every 1 hour. You can change how often checks occur by opening the Settings dialog from the system tray menu and adjusting the "Check Interval (hours)" option.
- **Show Notifications** Control whether notification pop-ups appear when outdated packages are found. This can be toggled on or off in the Settings dialog.
- **Start with Windows** This setting controls whether ChocoButler will start with windows.


## Development

### Building from Source
1. Clone the repository: `git clone https://github.com/cokelid/ChocoButler.git`
2. Install the .NET 8 SDK (https://dotnet.microsoft.com/en-us/download/dotnet/8.0)
3. Ensure `dotnet --version` gives version 8
3. Build the project with `dotnet build`
4. Run the application with `dotnet run`


## License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.












