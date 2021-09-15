# ChocoButler Changelog

## Unreleased
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
