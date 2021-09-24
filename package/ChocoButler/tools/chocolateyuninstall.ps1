$ErrorActionPreference = 'Stop'; # stop on all errors

# The choco_butler.bat file would have been installed with "shim" by Install-Binfile
Uninstall-BinFile -Name 'chocobutler.bat'