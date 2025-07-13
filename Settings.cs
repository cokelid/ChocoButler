using System.Text.Json;
using System.IO;
using System;

namespace ChocoButler
{
    public class Settings
    {
        public int CheckIntervalHours { get; set; } = 1; // Default to 1 hour
        public bool ShowNotifications { get; set; } = true;
        // The 'Start with Windows' setting is not stored here. It reflects the state of the Windows Startup folder.
        public bool PeriodicChecksEnabled { get; set; } = true;
    }

    public static class SettingsManager
    {
        private static string GetSettingsPath()
        {
            string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string settingsDir = Path.Combine(appData, "ChocoButler");
            Directory.CreateDirectory(settingsDir);
            return Path.Combine(settingsDir, "settings-v2.json");
        }

        public static Settings Load()
        {
            string path = GetSettingsPath();
            if (File.Exists(path))
            {
                try
                {
                    string json = File.ReadAllText(path);
                    return JsonSerializer.Deserialize<Settings>(json) ?? new Settings();
                }
                catch
                {
                    // If there's an error reading the file, return defaults
                    return new Settings();
                }
            }
            return new Settings();
        }

        public static void Save(Settings settings)
        {
            string path = GetSettingsPath();
            string json = JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(path, json);
        }

        // The 'Start with Windows' setting is not stored in the settings file. It reflects the state of the Windows Startup folder.
        public static bool IsStartupShortcutPresent()
        {
            string? startupFolder = Environment.GetFolderPath(Environment.SpecialFolder.Startup);
            if (string.IsNullOrEmpty(startupFolder))
            {
                System.Windows.Forms.MessageBox.Show("Could not determine the Windows Startup folder.", "ChocoButler", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
                return false;
            }
            string shortcutPath = Path.Combine(startupFolder, "ChocoButler.lnk");
            return File.Exists(shortcutPath);
        }

        public static void SetStartupShortcut(bool enable)
        {
            try
            {
                string? startupFolder = Environment.GetFolderPath(Environment.SpecialFolder.Startup);
                if (string.IsNullOrEmpty(startupFolder))
                {
                    System.Windows.Forms.MessageBox.Show("Could not determine the Windows Startup folder. Cannot create startup shortcut.", "ChocoButler", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
                    return;
                }
                string shortcutPath = Path.Combine(startupFolder, "ChocoButler.lnk");
                string? exePath = System.Windows.Forms.Application.ExecutablePath;
                if (string.IsNullOrEmpty(exePath))
                {
                    System.Windows.Forms.MessageBox.Show("Could not determine the application executable path. Cannot create startup shortcut.", "ChocoButler", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
                    return;
                }
                if (enable)
                {
                    Type? shellType = Type.GetTypeFromProgID("WScript.Shell");
                    if (shellType == null)
                    {
                        System.Windows.Forms.MessageBox.Show("Could not access WScript.Shell COM object. Cannot create startup shortcut.", "ChocoButler", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
                        return;
                    }
                    try
                    {
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
                    catch (Exception ex)
                    {
                        System.Windows.Forms.MessageBox.Show($"Failed to create startup shortcut: {ex.Message}", "ChocoButler", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
                        Console.WriteLine($"[{DateTime.Now:G}] Failed to create startup shortcut: {ex.Message}");
                    }
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
    }
} 