# ChocoButler Changelog


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
