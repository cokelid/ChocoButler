using System;
using System.Windows.Forms;

namespace ChocoButler
{
    public partial class SettingsForm : Form
    {
        private Settings settings;
        private NumericUpDown checkIntervalNumeric = null!;
        private CheckBox showNotificationsCheckBox = null!;
        private CheckBox startWithWindowsCheckBox = null!;
        private Button saveButton = null!;
        private Button cancelButton = null!;
        private CheckBox periodicChecksCheckBox = null!;

        public SettingsForm(Settings currentSettings)
        {
            settings = currentSettings;
            InitializeComponents();
            LoadSettings();
        }

        private void InitializeComponents()
        {
            this.Text = "ChocoButler Settings";
            this.Size = new System.Drawing.Size(400, 300);
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = false;
            this.StartPosition = FormStartPosition.CenterParent;

            int y = 20;
            int spacing = 32;

            // Periodic checks checkbox (now at the top)
            periodicChecksCheckBox = new CheckBox
            {
                Text = "Periodically check for updates",
                Location = new System.Drawing.Point(20, y),
                Size = new System.Drawing.Size(300, 20),
                Checked = true
            };
            periodicChecksCheckBox.CheckedChanged += PeriodicChecksCheckBox_CheckedChanged;
            y += spacing;

            // Check interval label and numeric
            var checkIntervalLabel = new Label
            {
                Text = "Check for updates every:",
                Location = new System.Drawing.Point(20, y),
                Size = new System.Drawing.Size(200, 20)
            };

            checkIntervalNumeric = new NumericUpDown
            {
                Location = new System.Drawing.Point(220, y - 2),
                Size = new System.Drawing.Size(60, 20),
                Minimum = 1,
                Maximum = 999,
                Value = 1
            };

            var hoursLabel = new Label
            {
                Text = "hours",
                Location = new System.Drawing.Point(290, y),
                Size = new System.Drawing.Size(50, 20)
            };
            y += spacing;

            // Show notifications checkbox
            showNotificationsCheckBox = new CheckBox
            {
                Text = "Show notifications when updates are available",
                Location = new System.Drawing.Point(20, y),
                Size = new System.Drawing.Size(300, 20),
                Checked = true
            };
            y += spacing;

            // Start with Windows checkbox
            startWithWindowsCheckBox = new CheckBox
            {
                Text = "Start with Windows",
                Location = new System.Drawing.Point(20, y),
                Size = new System.Drawing.Size(300, 20),
                // This setting is not stored in the settings file, but reflects the state of the Windows Startup folder.
                Checked = SettingsManager.IsStartupShortcutPresent()
            };
            y += spacing;

            // Buttons
            saveButton = new Button
            {
                Text = "Save",
                Location = new System.Drawing.Point(200, 220),
                Size = new System.Drawing.Size(75, 25),
                DialogResult = DialogResult.OK
            };
            saveButton.Click += SaveButton_Click;

            cancelButton = new Button
            {
                Text = "Cancel",
                Location = new System.Drawing.Point(285, 220),
                Size = new System.Drawing.Size(75, 25),
                DialogResult = DialogResult.Cancel
            };

            // Add controls to form
            this.Controls.AddRange(new Control[]
            {
                periodicChecksCheckBox,
                checkIntervalLabel,
                checkIntervalNumeric,
                hoursLabel,
                showNotificationsCheckBox,
                startWithWindowsCheckBox,
                saveButton,
                cancelButton
            });

            this.AcceptButton = saveButton;
            this.CancelButton = cancelButton;

            // Helper to enable/disable interval controls
            void SetIntervalControlsEnabled(bool enabled)
            {
                checkIntervalLabel.Enabled = enabled;
                checkIntervalNumeric.Enabled = enabled;
                hoursLabel.Enabled = enabled;
            }
            SetIntervalControlsEnabled(periodicChecksCheckBox.Checked);
        }

        private void LoadSettings()
        {
            checkIntervalNumeric.Value = settings.CheckIntervalHours;
            showNotificationsCheckBox.Checked = settings.ShowNotifications;
            periodicChecksCheckBox.Checked = settings.PeriodicChecksEnabled;
        }

        private void SaveButton_Click(object? sender, EventArgs e)
        {
            settings.CheckIntervalHours = (int)checkIntervalNumeric.Value;
            settings.ShowNotifications = showNotificationsCheckBox.Checked;
            settings.PeriodicChecksEnabled = periodicChecksCheckBox.Checked;
            // The 'Start with Windows' setting is not stored in the settings file, but reflects the state of the Windows Startup folder.
            SettingsManager.SetStartupShortcut(startWithWindowsCheckBox.Checked);
            
            SettingsManager.Save(settings);
        }

        public Settings GetUpdatedSettings()
        {
            return settings;
        }

        private void PeriodicChecksCheckBox_CheckedChanged(object? sender, EventArgs e)
        {
            // Enable/disable interval controls based on periodic checks
            var enabled = periodicChecksCheckBox.Checked;
            foreach (Control ctrl in this.Controls)
            {
                if (ctrl is Label lbl && lbl.Text.StartsWith("Check for updates every"))
                    lbl.Enabled = enabled;
                if (ctrl is NumericUpDown num)
                    num.Enabled = enabled;
                if (ctrl is Label lbl2 && lbl2.Text == "hours")
                    lbl2.Enabled = enabled;
            }
        }
    }
} 