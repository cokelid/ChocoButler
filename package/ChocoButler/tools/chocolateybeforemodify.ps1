# This runs in 0.9.10+ before upgrade and uninstall.
# Note: We don't need the .exe extension here, despite the output of tasklist
Stop-Process -Name 'chocobutler.bat'

