# ChocoButler Changelog


## Unreleased

### Added
*
### Changes
* Settings file no longer included in package/repo. If it doesn't exist then use defaults. This helps with upgrading.
* Settings file only created when "Edit Settings File" is first used. Otherwise use defaults. This ensures that code leaves no footprints by default.
* Settings file now found in `%APPDATA%`.
* PID file now created in `%LOCALAPPDATA%`.
## [[v0.1.8](https://github.com/cokelid/ChocoButler/releases/tag/v0.1.8)] 2021-10-05
Improvements for chocolatey packaging and more stable with Windows Server 2012
### Added
* Added packageSourceUrl to nuspec
* Added releaseNotes to nuspec
### Changes
* More consistent temp-dir identification (for PID file) in Windows Server 2012 R2 (and elsewhere)
* Create startup-shortcut with chocolatey's own Install-ChocolateyShortcut command, complete with nice icon

## [[v0.1.7](https://github.com/cokelid/ChocoButler/releases/tag/v0.1.7)] 2021-10-05
Allow ChocoButler to update itself via package. Repair choco.exe.old problem.
### Added
* Creates a PID file containing the Process ID, to be used for package updating.
* Added an option to "repair" when the `choco.exe.old` problem is encountered.
* Missing settings are now automatically added to the `settings.json` file with the default value.
### Changes
* Minor changes to Advanced menu text and ordering
* When updating ChocoButler itself do so tidily: ensure we remove the system tray icon and update ChocoButler last


## [[v0.1.6](https://github.com/cokelid/ChocoButler/releases/tag/v0.1.6)] 2021-09-24
No changes beyond ensuring the version in the code matches the release (which I screwed up)


## [[v0.1.5](https://github.com/cokelid/ChocoButler/releases/tag/v0.1.5)] 2021-09-24
Files renamed, improved error reporting, version displayed

### Added
* New startup message that includes script path, so it's clear where it's running from.
* New section in the README about the dreaded `choco.exe.old` problem.
* ChocoButler Version is now shown under Advanced Menu
### Changes
* Files and names renamed for consistency prior to packaging. Previously had `choco-butler` and `choco_butler`, now changed to `chocobutler` to match the expected package name.
* Improved error message when the dreaded `choco.exe.old` problem is encountered.



## [[v0.1.4](https://github.com/cokelid/ChocoButler/releases/tag/v0.1.4)] 2021-09-22
Two new settings, two new Advanced menu items, new icons
### Added
* New `exit_if_no_outdated` setting, to exit immediately if no outdated packages are found
* New `immediate_first_check` setting, to perform first outdated-check as soon as ChocoButler starts
* New menu entries under 'Advanced' to edit settings file, and show the README file on the web
### Changes
* Improved checking for a _Chocolatey GUI_ installation
* New icons with alpha channel
* Extra filtering on outdated checks for manually installed packages


## [[v0.1.3](https://github.com/cokelid/ChocoButler/releases/tag/v0.1.3)] 2021-09-19
New silent option added to settings.
### Added
* New `silent` option in settings file to allow suppression of pop-ups. Pop-ups will still be shown for errors and warnings, even if this setting is turned on.

## [[v0.1.2](https://github.com/cokelid/ChocoButler/releases/tag/v0.1.1)] 2021-09-16
Only changes to test_mode.
### Changes
* In test_mode, when no outdated packages are available, fake outdated with a real package (GoogleChrome) rather than a dummy package. In test_mode updates are performed with `--noop` so it won't affect anything.
* In test_mode, show [TEST MODE] on the install menu to be clear it won't make changes. 

## [[v0.1.1](https://github.com/cokelid/ChocoButler/releases/tag/v0.1.1)] 2021-09-15
### Added
* Shows pop-up even for no outdated packages when check is manually instigated. This way you know it's done something, and not ignoring your click.
* Only update specific packages previously found to be outdated (before we just did `choco update all`). This keeps the log clean and prevents packages being updated that have become outdated since the last check.
* Added screenshots to README
 ### Changes
 * Better reporting/display of outdated packages, including correct pluralisation!
 * Renamed function to `check_choco_old` for clarity
 * Mention log file (and Advanced menu entry) when an error occurs, to help users debug

## [[v0.1.0](https://github.com/cokelid/ChocoButler/releases/tag/v0.1.0)] 2021-09-13
First Release!










