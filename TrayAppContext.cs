using System;
using System.Drawing;
using System.Windows.Forms;
using System.Collections.Generic;
using System.Linq;
using System.IO;
using System.Reflection;

namespace ChocoButler
{
    public class TrayAppContext : ApplicationContext  // Use ApplicationContext to handle the system tray icon
    {
        private NotifyIcon trayIcon;
        private Timer checkTimer;
        private ToolStripMenuItem installUpdatesMenuItem;
        private ToolStripMenuItem checkNowMenuItem;
        private ToolStripMenuItem statusMenuItem;
        private ToolStripMenuItem outdatedPackagesMenuItem;
        private List<(string Name, string FullName, string Current, string Available)> updatablePackages = new List<(string, string, string, string)>();
        private DateTime? lastCheckStarted = null;
        private DateTime? lastCheckCompleted = null;
        private bool isChecking = false;
        private bool isUpdating = false;
        private DateTime? lastUpdateStarted = null;
        private Settings appSettings;
        private readonly Dictionary<(string, string), string> packageFullNameCache = new();
        private Icon? normalIcon = null;
        private Icon? alertIcon = null;

        public TrayAppContext()
        {
            // Load settings
            appSettings = SettingsManager.Load();

            // Create context menu
            var contextMenu = new ContextMenuStrip();
            installUpdatesMenuItem = new ToolStripMenuItem($"Install Updates ({updatablePackages.Count}) ...");
            installUpdatesMenuItem.Enabled = false;
            installUpdatesMenuItem.Click += InstallUpdates_Click;

            statusMenuItem = new ToolStripMenuItem();
            statusMenuItem.Enabled = false;

            outdatedPackagesMenuItem = new ToolStripMenuItem("Outdated Packages");
            outdatedPackagesMenuItem.Enabled = false;

            checkNowMenuItem = new ToolStripMenuItem("Check for outdated packages now", null, CheckNow_Click);
            var settingsMenuItem = new ToolStripMenuItem("Settings...", null, Settings_Click);
            var exitMenuItem = new ToolStripMenuItem("Exit", null, Exit_Click);

            var advancedMenuItem = new ToolStripMenuItem("Advanced");

            // Version label (greyed out)
            var versionObj = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
            var version = versionObj != null
                ? $"{versionObj.Major}.{versionObj.Minor}.{versionObj.Build}"
                : "v?";
            Console.WriteLine($"[{DateTime.Now:G}] ChocoButler version: {version}");
            var versionLabel = new ToolStripMenuItem($"ChocoButler v{version}");
            versionLabel.Enabled = false;

            // Advanced submenu items
            var openReadmeMenuItem = new ToolStripMenuItem("Open ChocoButler README (on web)", null, OpenReadme_Click);
            var logFilePath = System.IO.Path.Combine(Environment.GetEnvironmentVariable("ProgramData") ?? "C:/ProgramData", "chocolatey", "logs", "chocolatey.log");
            var logFileExists = System.IO.File.Exists(logFilePath);
            var openLogMenuItem = new ToolStripMenuItem(logFileExists ? "Open Chocolatey log file" : "(Chocolatey Log file not found?)", null, OpenLog_Click)
            {
                Enabled = logFileExists
            };

            var chocolateyGuiExe = FindChocolateyGuiExe();
            var openGuiMenuItem = new ToolStripMenuItem(chocolateyGuiExe != null ? "Open Chocolatey GUI" : "(Chocolatey GUI not found)", null, OpenGui_Click)
            {
                Enabled = chocolateyGuiExe != null
            };

            var aboutMenuItem = new ToolStripMenuItem("About", null, About_Click);

            advancedMenuItem.DropDownItems.Add(versionLabel);
            advancedMenuItem.DropDownItems.Add(new ToolStripSeparator());
            advancedMenuItem.DropDownItems.Add(openReadmeMenuItem);
            advancedMenuItem.DropDownItems.Add(openLogMenuItem);

            contextMenu.Items.Add(statusMenuItem);
            contextMenu.Items.Add(new ToolStripSeparator());
            contextMenu.Items.Add(installUpdatesMenuItem);
            contextMenu.Items.Add(outdatedPackagesMenuItem);
            contextMenu.Items.Add(checkNowMenuItem);
            contextMenu.Items.Add(new ToolStripSeparator());
            contextMenu.Items.Add(settingsMenuItem);
            contextMenu.Items.Add(openGuiMenuItem);
            contextMenu.Items.Add(advancedMenuItem);
            contextMenu.Items.Add(aboutMenuItem);
            contextMenu.Items.Add(new ToolStripSeparator());
            contextMenu.Items.Add(exitMenuItem);

            // Now create tray icon
            trayIcon = new NotifyIcon();
            trayIcon.ContextMenuStrip = contextMenu;
            trayIcon.Text = "ChocoButler";
            trayIcon.Visible = true;

            // Load both embedded icon resources with error handling
            var assembly = System.Reflection.Assembly.GetExecutingAssembly();
            var normalResourceName = "ChocoButler.icons.chocobutler.ico";
            var alertResourceName = "ChocoButler.icons.chocobutler_red.ico";
            using (Stream? stream = assembly.GetManifestResourceStream(normalResourceName))
            {
                if (stream != null)
                {
                    normalIcon = new Icon(stream);
                }
                else
                {
                    Console.WriteLine($"[{DateTime.Now:G}] Failed to load normal icon.");
                }
            }
            using (Stream? stream = assembly.GetManifestResourceStream(alertResourceName))
            {
                if (stream != null)
                {
                    alertIcon = new Icon(stream);                    
                }
                else
                {
                    Console.WriteLine($"[{DateTime.Now:G}] Failed to load alert icon.");
                }
            }
            trayIcon.Icon = normalIcon ?? SystemIcons.Application;

            trayIcon.DoubleClick += TrayIcon_DoubleClick;
            trayIcon.BalloonTipClicked += TrayIcon_BalloonTipClicked;

            // Now it's safe to call this:
            UpdateStatusMenuItem();

            // Set up timer with settings
            checkTimer = new Timer();
            checkTimer.Interval = appSettings.CheckIntervalHours * 60 * 60 * 1000; // Convert hours to milliseconds
            checkTimer.Tick += (s, e) => CheckForUpdates();
            if (appSettings.PeriodicChecksEnabled)
                checkTimer.Start();

            // Initial check
            CheckForUpdates();
            
            // Set initial tray icon tooltip
            UpdateTrayIconTooltip();
        }

        private void TrayIcon_DoubleClick(object? sender, EventArgs e)
        {
            ShowInstallUpdatesWindow();
        }

        private void TrayIcon_BalloonTipClicked(object? sender, EventArgs e)
        {
            ShowInstallUpdatesWindow();
        }

        private void InstallUpdates_Click(object? sender, EventArgs e)
        {
            ShowInstallUpdatesWindow();
        }

        private void CheckNow_Click(object? sender, EventArgs e)
        {
            CheckForUpdates();
        }

        private void Settings_Click(object? sender, EventArgs e)
        {
            var oldInterval = appSettings.CheckIntervalHours;
            var oldPeriodic = appSettings.PeriodicChecksEnabled;
            var settingsForm = new SettingsForm(appSettings);
            if (settingsForm.ShowDialog() == DialogResult.OK)
            {
                // Update settings
                appSettings = settingsForm.GetUpdatedSettings();
                // Only update timer if interval or periodic setting changed
                if (appSettings.CheckIntervalHours != oldInterval || appSettings.PeriodicChecksEnabled != oldPeriodic)
                {
                    checkTimer.Interval = appSettings.CheckIntervalHours * 60 * 60 * 1000;
                    checkTimer.Stop();
                    if (appSettings.PeriodicChecksEnabled)
                    {
                        checkTimer.Start();
                        Console.WriteLine($"[{DateTime.Now:G}] Periodic checks enabled. Timer restarted with interval: {appSettings.CheckIntervalHours} hour(s).");
                        Console.WriteLine($"[{DateTime.Now:G}] Next check at: {DateTime.Now.AddHours(appSettings.CheckIntervalHours):G}");
                    }
                    else
                    {
                        Console.WriteLine($"[{DateTime.Now:G}] Periodic checks disabled. Timer stopped.");
                    }
                }
                // Save settings
                SettingsManager.Save(appSettings);
            }
        }

        private void Exit_Click(object? sender, EventArgs e)
        {
            trayIcon.Visible = false;
            Application.Exit();
        }

        private void UpdateStatusMenuItem()
        {
            string statusLine;
            string timeLine;
            if (isUpdating)
            {
                statusLine = $"Updating {updatablePackages.Count} package{(updatablePackages.Count == 1 ? "" : "s")}";
                timeLine = lastUpdateStarted.HasValue ? $"Started at: {lastUpdateStarted.Value:G}" : "Starting update...";
            }
            else if (isChecking)
            {
                statusLine = "Checking for outdated packages...";
                timeLine = lastCheckStarted.HasValue ? $"Check started: {lastCheckStarted.Value:G}" : "Check started...";
            }
            else if (lastCheckCompleted.HasValue)
            {
                statusLine = updatablePackages.Count == 0 ? "No outdated packages" : $"{updatablePackages.Count} outdated package{(updatablePackages.Count == 1 ? "" : "s")}";
                timeLine = $"Last checked: {lastCheckCompleted.Value:G}";
            }
            else
            {
                statusLine = "No check performed yet";
                timeLine = "";
            }
            statusMenuItem.Text = statusLine + "\n" + timeLine;
            
            // Update tray icon tooltip
            UpdateTrayIconTooltip();
        }

        private void UpdateTrayIconTooltip()
        {
            if (isUpdating)
            {
                trayIcon.Text = $"ChocoButler - Updating {updatablePackages.Count} package{(updatablePackages.Count == 1 ? "" : "s")}";
            }
            else if (isChecking)
            {
                trayIcon.Text = "ChocoButler - Checking for outdated packages...";
            }
            else if (updatablePackages.Count > 0)
            {
                trayIcon.Text = $"ChocoButler - {updatablePackages.Count} update{(updatablePackages.Count == 1 ? "" : "s")} available";
            }
            else
            {
                trayIcon.Text = "ChocoButler - No updates available";
            }
        }

        private void CheckForUpdates()
        {
            if (isUpdating) return; // Don't allow check during update
            // Stop timer so it restarts after check completes (if enabled)
            checkTimer.Stop();
            Console.WriteLine($"[{DateTime.Now:G}] Starting check for outdated packages...");
            isChecking = true;
            lastCheckStarted = DateTime.Now;
            UpdateStatusMenuItem();
            // Grey-out the check-now menu item while running
            if (checkNowMenuItem != null) checkNowMenuItem.Enabled = false;
            if (installUpdatesMenuItem != null) installUpdatesMenuItem.Enabled = false;
            try
            {
                var process = new System.Diagnostics.Process();
                process.StartInfo.FileName = "choco";
                process.StartInfo.Arguments = "outdated --no-color -r --ignore-pinned";
                process.StartInfo.RedirectStandardOutput = true;
                process.StartInfo.UseShellExecute = false;
                process.StartInfo.CreateNoWindow = true;
                process.Start();
                string output = process.StandardOutput.ReadToEnd();
                process.WaitForExit();
  
                if (output.Contains("Unable to load service index") || output.Contains("The remote name could not be resolved") || output.Contains("Unable to connect to source"))
                {
                    MessageBox.Show("Unable to check for updates. Please check your internet connection and try again.", "ChocoButler", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                // Parse output: each line is 'name|current|available|pinned'
                updatablePackages.Clear();
                var lines = output.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
                foreach (var line in lines)
                {
                    var parts = line.Split('|');
                    if (parts.Length == 4)
                    {
                        string name = parts[0].Trim();
                        string current = parts[1].Trim();
                        string available = parts[2].Trim();
                        string pinned = parts[3].Trim().ToLowerInvariant();
                        if (pinned != "true" && available != current)
                        {
                            // Get the full package name using choco info
                            string fullName = GetPackageFullName(name, available);
                            updatablePackages.Add((name, fullName, current, available));
                        }
                    }
                }
                Console.WriteLine($"[{DateTime.Now:G}] Found {updatablePackages.Count} outdated package(s).");
                // Change tray icon based on updates available
                if (updatablePackages.Count > 0 && alertIcon != null)
                {
                    trayIcon.Icon = alertIcon;
                    Console.WriteLine($"[{DateTime.Now:G}] Set tray icon to alert (red).");
                }
                else if (normalIcon != null)
                {
                    trayIcon.Icon = normalIcon;
                    Console.WriteLine($"[{DateTime.Now:G}] Set tray icon to normal.");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[{DateTime.Now:G}] Error during check: {ex.Message}");
                trayIcon.ShowBalloonTip(5000, "ChocoButler", $"Error checking for updates: {ex.Message}", ToolTipIcon.Error);
            }
            finally
            {
                // Re-enable the check-now menu item
                if (checkNowMenuItem != null) checkNowMenuItem.Enabled = true;
                if (installUpdatesMenuItem != null) installUpdatesMenuItem.Enabled = updatablePackages.Count > 0 && !isUpdating;
                isChecking = false;
                lastCheckCompleted = DateTime.Now;
                UpdateStatusMenuItem();
                UpdateOutdatedPackagesMenu();
                // Restart timer countdown after check completes, only if enabled
                checkTimer.Interval = appSettings.CheckIntervalHours * 60 * 60 * 1000;
                if (appSettings.PeriodicChecksEnabled)
                    checkTimer.Start();
                Console.WriteLine($"[{DateTime.Now:G}] Next check at: {(appSettings.PeriodicChecksEnabled ? DateTime.Now.AddHours(appSettings.CheckIntervalHours).ToString("G") : "(disabled)")}");
            }

            installUpdatesMenuItem!.Text = $"Install updates ({updatablePackages.Count})...";
            installUpdatesMenuItem.Enabled = updatablePackages.Count > 0;

            if (updatablePackages.Count > 0)
            {
                var packageList = string.Join(", ", updatablePackages.Select(pkg => pkg.FullName));
                if (appSettings.ShowNotifications)
                {
                    trayIcon.ShowBalloonTip(5000, "Chocolately Outdated Packages", $"{updatablePackages.Count} outdated package{(updatablePackages.Count == 1 ? "" : "s")}:\n{packageList}", ToolTipIcon.Info);
                }
            }
        }

        private string GetPackageFullName(string packageName, string version)
        {
            var key = (packageName, version);
            if (packageFullNameCache.TryGetValue(key, out var cachedFullName))
            {
                return cachedFullName;
            }

            try
            {
                var process = new System.Diagnostics.Process();
                process.StartInfo.FileName = "choco";
                process.StartInfo.Arguments = $"info {packageName} --version={version}";
                process.StartInfo.RedirectStandardOutput = true;
                process.StartInfo.UseShellExecute = false;
                process.StartInfo.CreateNoWindow = true;
                process.Start();
                string output = process.StandardOutput.ReadToEnd();
                process.WaitForExit();

                // Parse the output to find the Title
                var lines = output.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
                foreach (var line in lines)
                {
                    if (line.TrimStart().StartsWith("Title: "))
                    {
                        var match = System.Text.RegularExpressions.Regex.Match(line, @"\s*Title: (.+) \|");
                        if (match.Success)
                        {
                            packageFullNameCache[key] = match.Groups[1].Value.Trim();
                            return match.Groups[1].Value.Trim();
                        }
                    }
                }
            }
            catch (Exception)
            {
                // If we can't get the full name, fall back to the package name
            }
            packageFullNameCache[key] = packageName;
            return packageName;
        }

        private void ShowInstallUpdatesWindow(List<(string Name, string FullName, string Current, string Available)>? packagesToUpdate = null)
        {
            var packages = packagesToUpdate ?? updatablePackages;
            int packageCount = packages.Count;
            if (packageCount > 0)
            {
                Console.WriteLine($"[{DateTime.Now:G}] User initiated update for {packageCount} package(s).");
                var msg = $"Proceed with {packageCount} package upgrade{(packageCount == 1 ? "" : "s")}?\n\n" +
                    string.Join("\n", packages.Select(pkg => $"• {pkg.FullName}  [{pkg.Name} → {pkg.Available}]"));
                var result = MessageBox.Show(msg, "ChocoButler", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
                if (result == DialogResult.Yes)
                {
                    isUpdating = true;
                    lastUpdateStarted = DateTime.Now;
                    UpdateStatusMenuItem();
                    if (checkNowMenuItem != null) checkNowMenuItem.Enabled = false;
                    if (installUpdatesMenuItem != null) installUpdatesMenuItem.Enabled = false;
                    try
                    {
                        // Only upgrade the packages shown in the popup
                        var packageList = string.Join(" ", packages.Select(pkg => pkg.Name));
                        if (string.IsNullOrWhiteSpace(packageList))
                        {
                            MessageBox.Show("No packages to upgrade.", "ChocoButler");
                            isUpdating = false;
                            UpdateStatusMenuItem();
                            if (checkNowMenuItem != null) checkNowMenuItem.Enabled = true;
                            if (installUpdatesMenuItem != null) installUpdatesMenuItem.Enabled = updatablePackages.Count > 0;
                            return;
                        }
                        // Here we run the upgrade process as administrator
                        var process = new System.Diagnostics.Process();
                        process.StartInfo.FileName = "choco";
                        process.StartInfo.Arguments = $"upgrade {packageList} --yes"; // --noop"; // Set to --noop for debugging perhaps
                        process.StartInfo.UseShellExecute = true;
                        process.StartInfo.Verb = "runas"; // Prompt for elevation
                        process.StartInfo.CreateNoWindow = false;
                        try
                        {
                            Console.WriteLine($"[{DateTime.Now:G}] Starting upgrade for {packageCount} package(s): {packageList}");
                            process.Start();
                            process.WaitForExit();
                            int exitCode = process.ExitCode;
                            string exitMsg;
                            string type;
                            bool disableInstall = false;
                            switch (exitCode)
                            {
                                case 0:
                                    exitMsg = "Upgrade completed successfully.";
                                    type = "Info";
                                    Console.WriteLine($"[{DateTime.Now:G}] Upgrade completed successfully.");
                                    break;
                                case 1641:
                                    exitMsg = "Upgrade successful. Reboot Initiated...";
                                    type = "Warning";
                                    disableInstall = true;
                                    Console.WriteLine($"[{DateTime.Now:G}] Upgrade successful. Reboot Initiated...");
                                    break;
                                case 3010:
                                    exitMsg = "Upgrade successful. Reboot Required...";
                                    type = "Warning";
                                    disableInstall = true;
                                    Console.WriteLine($"[{DateTime.Now:G}] Upgrade successful. Reboot Required...");
                                    break;
                                case 350:
                                    exitMsg = "Upgrade successful. Pending reboot detected, no action has occurred. (Exit code 350)";
                                    type = "Warning";
                                    disableInstall = true;
                                    Console.WriteLine($"[{DateTime.Now:G}] Upgrade successful. Pending reboot detected, no action has occurred. (Exit code 350)");
                                    break;
                                case 1604:
                                    exitMsg = "Upgrade error. Install suspended, incomplete. (Exit code 1604)";
                                    type = "Error";
                                    disableInstall = true;
                                    Console.WriteLine($"[{DateTime.Now:G}] Upgrade error. Install suspended, incomplete. (Exit code 1604)");
                                    break;
                                case -999:
                                    exitMsg = "User cancelled upgrade. Admin rights required! (Exit code -999)";
                                    type = "Error";
                                    Console.WriteLine($"[{DateTime.Now:G}] User cancelled upgrade. Admin rights required! (Exit code -999)");
                                    break;
                                case -1:
                                    exitMsg = "Error occurred during upgrade. Update manually. (Exit code -1)";
                                    type = "Error";
                                    disableInstall = true;
                                    Console.WriteLine($"[{DateTime.Now:G}] Error occurred during upgrade. Update manually. (Exit code -1)");
                                    break;
                                default:
                                    exitMsg = $"Unknown error occurred. Exit code: {exitCode}. Open Log File for details (under Advanced menu)";
                                    type = "Error";
                                    disableInstall = true;
                                    Console.WriteLine($"[{DateTime.Now:G}] Unknown error occurred. Exit code: {exitCode}.");
                                    break;
                            }
                            if (disableInstall && installUpdatesMenuItem != null)
                                installUpdatesMenuItem.Enabled = false;
                            if (type == "Info")
                                MessageBox.Show(exitMsg, "ChocoButler", MessageBoxButtons.OK, MessageBoxIcon.Information);
                            else if (type == "Warning")
                                MessageBox.Show(exitMsg, "ChocoButler", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                            else
                                MessageBox.Show(exitMsg, "ChocoButler", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        }
                        catch (System.ComponentModel.Win32Exception ex) when (ex.NativeErrorCode == 1223)
                        {
                            // The operation was canceled by the user (UAC prompt declined)
                            MessageBox.Show("Upgrade cancelled (administrator permission was not granted).", "ChocoButler");
                        }
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Error running upgrade: {ex.Message}", "ChocoButler", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    }
                    finally
                    {
                        isUpdating = false;
                        UpdateStatusMenuItem();
                        CheckForUpdates();  // This will enable checkNowMenuItem etc.
                        //if (checkNowMenuItem != null) checkNowMenuItem.Enabled = true;
                        //if (installUpdatesMenuItem != null) installUpdatesMenuItem.Enabled = updatablePackages.Count > 0;
                    }
                }
                // If No is clicked, do nothing
            }
            else
            {
                MessageBox.Show("No updates available.", "ChocoButler");
            }
        }

        private void IndividualPackage_Click(object? sender, EventArgs e)
        {
            if (sender is ToolStripMenuItem menuItem)
            {
                if (menuItem.Tag is not null)
                {
                    var package = ((string Name, string FullName, string Current, string Available))menuItem.Tag;
                    var singlePackage = new List<(string Name, string FullName, string Current, string Available)> { package };
                    ShowInstallUpdatesWindow(singlePackage);
                }
            }
        }

        private void UpdateOutdatedPackagesMenu()
        {
            outdatedPackagesMenuItem.DropDownItems.Clear();
            if (updatablePackages.Count > 0)
            {
                outdatedPackagesMenuItem.Enabled = true;
                foreach (var package in updatablePackages)
                {
                    var packageItem = new ToolStripMenuItem($"{package.FullName} [{package.Name} → {package.Available}]");
                    packageItem.Tag = package;
                    packageItem.Click += IndividualPackage_Click;
                    outdatedPackagesMenuItem.DropDownItems.Add(packageItem);
                }
            }
            else
            {
                outdatedPackagesMenuItem.Enabled = false;
            }
        }

        // Add stub event handlers for advanced menu
        private void EditSettings_Click(object? sender, EventArgs e)
        {
            // TODO: Open settings file in default editor
            MessageBox.Show("Open settings file (not yet implemented)", "ChocoButler");
        }
        private void OpenReadme_Click(object? sender, EventArgs e)
        {
            try
            {
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                {
                    FileName = "https://github.com/cokelid/ChocoButler#readme",
                    UseShellExecute = true
                });
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Failed to open README: {ex.Message}", "ChocoButler", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
        private void OpenLog_Click(object? sender, EventArgs e)
        {
            var logFilePath = System.IO.Path.Combine(Environment.GetEnvironmentVariable("ProgramData") ?? "C:/ProgramData", "chocolatey", "logs", "chocolatey.log");
            if (System.IO.File.Exists(logFilePath))
            {
                try
                {
                    System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = logFilePath,
                        UseShellExecute = true
                    });
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Failed to open log file: {ex.Message}", "ChocoButler", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
            else
            {
                MessageBox.Show("Chocolatey log file not found.", "ChocoButler", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
        private void OpenGui_Click(object? sender, EventArgs e)
        {
            var chocolateyGuiExe = FindChocolateyGuiExe();
            if (chocolateyGuiExe != null)
            {
                try
                {
                    System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = chocolateyGuiExe,
                        UseShellExecute = true
                    });
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Failed to open Chocolatey GUI: {ex.Message}", "ChocoButler", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
            else
            {
                MessageBox.Show("Chocolatey GUI executable not found.", "ChocoButler", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
        
        // Helper to find Chocolatey GUI executable
        private static string? FindChocolateyGuiExe()
        {
            // Common install locations
            var programFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            var programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            var programData = Environment.GetEnvironmentVariable("ProgramData") ?? "C:/ProgramData";
            if (string.IsNullOrEmpty(programFilesX86) || string.IsNullOrEmpty(programFiles) || string.IsNullOrEmpty(localAppData) || string.IsNullOrEmpty(programData))
            {
                System.Windows.Forms.MessageBox.Show("Could not determine one or more required system folders.", "ChocoButler", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
                return null;
            }
            var possiblePaths = new[]
            {
                System.IO.Path.Combine(programFilesX86, "Chocolatey GUI", "ChocolateyGui.exe"),
                System.IO.Path.Combine(programFiles, "Chocolatey GUI", "ChocolateyGui.exe"),
                System.IO.Path.Combine(localAppData, "Programs", "Chocolatey GUI", "ChocolateyGui.exe"),
                System.IO.Path.Combine(programData, "chocolatey", "lib", "chocolateygui", "tools", "ChocolateyGui.exe")
            };
            foreach (var path in possiblePaths)
            {
                if (System.IO.File.Exists(path))
                {
                    Console.WriteLine($"[{DateTime.Now:G}] Found Chocolatey GUI executable at: {path}");
                    return path;
                }
            }
            return null;
        }

        // Add method to create/remove shortcut in Startup folder using dynamic COM interop
        private void SetStartup(bool enable)
        {
            try
            {
                string? startupFolder = Environment.GetFolderPath(Environment.SpecialFolder.Startup);
                if (string.IsNullOrEmpty(startupFolder))
                {
                    System.Windows.Forms.MessageBox.Show("Could not determine the Windows Startup folder.", "ChocoButler", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
                    return;
                }
                string shortcutPath = Path.Combine(startupFolder, "ChocoButler.lnk");
                string? exePath = System.Windows.Forms.Application.ExecutablePath;
                if (string.IsNullOrEmpty(exePath))
                {
                    System.Windows.Forms.MessageBox.Show("Could not determine the application executable path.", "ChocoButler", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
                    return;
                }
                if (enable)
                {
                    Type? shellType = Type.GetTypeFromProgID("WScript.Shell");
                    if (shellType == null)
                    {
                        System.Windows.Forms.MessageBox.Show("Could not access WScript.Shell COM object.", "ChocoButler", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
                        return;
                    }
                    dynamic? shell = Activator.CreateInstance(shellType);
                    if (shell == null)
                    {
                        System.Windows.Forms.MessageBox.Show("Failed to create WScript.Shell COM object. Cannot create startup shortcut.", "ChocoButler", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
                        return;
                    }
                    dynamic? shortcut = shell.CreateShortcut(shortcutPath);
                    if (shortcut == null)
                    {
                        System.Windows.Forms.MessageBox.Show("Failed to create shortcut object. Cannot create startup shortcut.", "ChocoButler", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
                        return;
                    }
                    shortcut.TargetPath = exePath;
                    shortcut.WorkingDirectory = Path.GetDirectoryName(exePath);
                    shortcut.Save();
                    Console.WriteLine($"[{DateTime.Now:G}] Created startup shortcut: {shortcutPath}");
                }
                else
                {
                    if (File.Exists(shortcutPath))
                    {
                        File.Delete(shortcutPath);
                        Console.WriteLine($"[{DateTime.Now:G}] Removed startup shortcut: {shortcutPath}");
                    }
                }
            }
            catch (Exception ex)
            {
                System.Windows.Forms.MessageBox.Show($"Error updating startup shortcut: {ex.Message}", "ChocoButler", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
                Console.WriteLine($"[{DateTime.Now:G}] Error updating startup shortcut: {ex.Message}");
            }
        }

        private void About_Click(object? sender, EventArgs e)
        {
            var versionObj = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version;
            var version = versionObj != null
                ? $"{versionObj.Major}.{versionObj.Minor}.{versionObj.Build}"
                : "v?";            
            string githubUrl = "https://github.com/cokelid/ChocoButler";
            string msg = $"ChocoButler\nVersion: {version}\n\nA Windows system tray app for monitoring and updating Chocolatey packages.\n\nGitHub: {githubUrl}\n\n© 2025 Cokelid (https://github.com/cokelid)\n\nThis program comes with ABSOLUTELY NO WARRANTY.\nIt is released under the GPL-3.0 licence.";
            var result = MessageBox.Show(msg + "\n\nOpen GitHub page?", "About ChocoButler", MessageBoxButtons.YesNo, MessageBoxIcon.Information);
            if (result == DialogResult.Yes)
            {
                try
                {
                    System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = githubUrl,
                        UseShellExecute = true
                    });
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Failed to open GitHub page: {ex.Message}", "ChocoButler", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }

        // Helper method to check if Chocolatey is available
        private bool IsChocolateyAvailable()
        {
            try
            {
                var process = new System.Diagnostics.Process();
                process.StartInfo.FileName = "choco";
                process.StartInfo.Arguments = "--version";
                process.StartInfo.RedirectStandardOutput = true;
                process.StartInfo.UseShellExecute = false;
                process.StartInfo.CreateNoWindow = true;
                process.Start();
                string output = process.StandardOutput.ReadToEnd();
                process.WaitForExit();
                
                // If we get here, choco command exists and ran successfully
                Console.WriteLine($"[{DateTime.Now:G}] Chocolatey version: {output.Trim()}");
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[{DateTime.Now:G}] Chocolatey not available: {ex.Message}");
                return false;
            }
        }
    }
} 