namespace GitHubProjectBackupApp;

public partial class Form1 : Form
{
    private readonly TextBox _rootsBox = new();
    private readonly TextBox _ownerBox = new();
    private readonly TextBox _stagingBox = new();
    private readonly TextBox _reportBox = new();
    private readonly CheckBox _uploadBox = new();
    private readonly CheckBox _thirdPartyBox = new();
    private readonly CheckBox _allowSuspiciousBox = new();
    private readonly Button _runButton = new();
    private readonly Button _openReportButton = new();
    private readonly RichTextBox _logBox = new();

    public Form1()
    {
        InitializeComponent();
        BuildUi();
    }

    private void BuildUi()
    {
        Font = new Font("Segoe UI", 9F);
        BackColor = Color.FromArgb(246, 248, 250);

        var iconPath = Path.Combine(AppContext.BaseDirectory, "github-project-backup-icon.ico");
        if (File.Exists(iconPath))
        {
            Icon = new Icon(iconPath);
        }

        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(16),
            ColumnCount = 1,
            RowCount = 4
        };
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        Controls.Add(root);

        var title = new Label
        {
            Text = "GitHub Project Backup",
            Font = new Font("Segoe UI Semibold", 18F, FontStyle.Bold),
            AutoSize = true,
            ForeColor = Color.FromArgb(18, 32, 48),
            Margin = new Padding(0, 0, 0, 2)
        };
        root.Controls.Add(title);

        var subtitle = new Label
        {
            Text = "Scan external drives, stage clean project copies, and upload private GitHub repositories.",
            AutoSize = true,
            ForeColor = Color.FromArgb(80, 91, 105),
            Margin = new Padding(0, 0, 0, 14)
        };
        root.Controls.Add(subtitle);

        var formGrid = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            ColumnCount = 3,
            RowCount = 6,
            AutoSize = true,
            Margin = new Padding(0, 0, 0, 12)
        };
        formGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 110));
        formGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        formGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 112));
        root.Controls.Add(formGrid);

        ConfigureTextBox(_rootsBox, @"I:\,J:\");
        ConfigureTextBox(_ownerBox, "elliot7williams");
        ConfigureTextBox(_stagingBox, @"H:\CodexUploadStaging\auto-project-backups");
        ConfigureTextBox(_reportBox, Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
            "GitHubProjectBackup-report.csv"));

        AddRow(formGrid, 0, "Roots", _rootsBox, MakeFolderButton(_rootsBox, true));
        AddRow(formGrid, 1, "Owner", _ownerBox, null);
        AddRow(formGrid, 2, "Staging", _stagingBox, MakeFolderButton(_stagingBox, false));
        AddRow(formGrid, 3, "Report", _reportBox, MakeReportButton());

        var options = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            AutoSize = true,
            FlowDirection = FlowDirection.LeftToRight,
            Margin = new Padding(0, 4, 0, 4)
        };
        _uploadBox.Text = "Upload private repos";
        _thirdPartyBox.Text = "Include third-party/download folders";
        _allowSuspiciousBox.Text = "Allow suspicious files";
        foreach (var box in new[] { _uploadBox, _thirdPartyBox, _allowSuspiciousBox })
        {
            box.AutoSize = true;
            box.Margin = new Padding(0, 0, 18, 0);
            options.Controls.Add(box);
        }
        formGrid.Controls.Add(new Label { Text = "Options", TextAlign = ContentAlignment.MiddleLeft, Dock = DockStyle.Fill }, 0, 4);
        formGrid.Controls.Add(options, 1, 4);
        formGrid.SetColumnSpan(options, 2);

        var buttons = new FlowLayoutPanel
        {
            AutoSize = true,
            FlowDirection = FlowDirection.LeftToRight,
            Margin = new Padding(0, 8, 0, 0)
        };
        _runButton.Text = "Run";
        _runButton.Width = 120;
        _runButton.Height = 34;
        _runButton.Click += async (_, _) => await RunBackupAsync();
        buttons.Controls.Add(_runButton);

        _openReportButton.Text = "Open Report";
        _openReportButton.Width = 120;
        _openReportButton.Height = 34;
        _openReportButton.Click += (_, _) => OpenReport();
        buttons.Controls.Add(_openReportButton);

        formGrid.Controls.Add(new Label(), 0, 5);
        formGrid.Controls.Add(buttons, 1, 5);
        formGrid.SetColumnSpan(buttons, 2);

        _logBox.Dock = DockStyle.Fill;
        _logBox.BackColor = Color.FromArgb(10, 14, 20);
        _logBox.ForeColor = Color.FromArgb(216, 229, 239);
        _logBox.Font = new Font("Consolas", 9F);
        _logBox.BorderStyle = BorderStyle.FixedSingle;
        _logBox.ReadOnly = true;
        root.Controls.Add(_logBox);
    }

    private static void ConfigureTextBox(TextBox box, string text)
    {
        box.Text = text;
        box.Dock = DockStyle.Fill;
        box.Margin = new Padding(0, 3, 8, 3);
    }

    private static void AddRow(TableLayoutPanel grid, int row, string label, Control input, Control? button)
    {
        grid.Controls.Add(new Label
        {
            Text = label,
            TextAlign = ContentAlignment.MiddleLeft,
            Dock = DockStyle.Fill,
            Margin = new Padding(0, 3, 8, 3)
        }, 0, row);
        grid.Controls.Add(input, 1, row);
        if (button != null)
        {
            grid.Controls.Add(button, 2, row);
        }
    }

    private Button MakeFolderButton(TextBox target, bool append)
    {
        var button = new Button { Text = "Browse", Dock = DockStyle.Fill, Margin = new Padding(0, 3, 0, 3) };
        button.Click += (_, _) =>
        {
            using var dialog = new FolderBrowserDialog { ShowNewFolderButton = true };
            if (dialog.ShowDialog(this) == DialogResult.OK)
            {
                target.Text = append && !string.IsNullOrWhiteSpace(target.Text)
                    ? target.Text.TrimEnd() + "," + dialog.SelectedPath
                    : dialog.SelectedPath;
            }
        };
        return button;
    }

    private Button MakeReportButton()
    {
        var button = new Button { Text = "Save As", Dock = DockStyle.Fill, Margin = new Padding(0, 3, 0, 3) };
        button.Click += (_, _) =>
        {
            using var dialog = new SaveFileDialog
            {
                Filter = "CSV report (*.csv)|*.csv|All files (*.*)|*.*",
                FileName = Path.GetFileName(_reportBox.Text)
            };
            if (dialog.ShowDialog(this) == DialogResult.OK)
            {
                _reportBox.Text = dialog.FileName;
            }
        };
        return button;
    }

    private async Task RunBackupAsync()
    {
        var scriptPath = Path.Combine(AppContext.BaseDirectory, "Backup-GitHubProjects.ps1");
        if (!File.Exists(scriptPath))
        {
            AppendLog("Backup-GitHubProjects.ps1 was not found next to the app.");
            return;
        }

        _runButton.Enabled = false;
        _logBox.Clear();
        AppendLog("Starting...");

        var roots = _rootsBox.Text
            .Split(new[] { ",", ";", Environment.NewLine }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .ToArray();

        var psi = new System.Diagnostics.ProcessStartInfo
        {
            FileName = "pwsh.exe",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        psi.ArgumentList.Add("-NoLogo");
        psi.ArgumentList.Add("-NoProfile");
        psi.ArgumentList.Add("-ExecutionPolicy");
        psi.ArgumentList.Add("Bypass");
        psi.ArgumentList.Add("-File");
        psi.ArgumentList.Add(scriptPath);

        if (roots.Length > 0)
        {
            psi.ArgumentList.Add("-Roots");
            foreach (var root in roots)
            {
                psi.ArgumentList.Add(root);
            }
        }
        AddArgument(psi, "-Owner", _ownerBox.Text);
        AddArgument(psi, "-StagingRoot", _stagingBox.Text);
        AddArgument(psi, "-ReportPath", _reportBox.Text);
        if (_uploadBox.Checked) psi.ArgumentList.Add("-Upload");
        if (_thirdPartyBox.Checked) psi.ArgumentList.Add("-IncludeThirdParty");
        if (_allowSuspiciousBox.Checked) psi.ArgumentList.Add("-AllowSuspiciousFiles");

        try
        {
            using var process = new System.Diagnostics.Process { StartInfo = psi, EnableRaisingEvents = true };
            process.OutputDataReceived += (_, e) => { if (e.Data != null) AppendLog(e.Data); };
            process.ErrorDataReceived += (_, e) => { if (e.Data != null) AppendLog(e.Data); };
            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
            await process.WaitForExitAsync();
            AppendLog(process.ExitCode == 0 ? "Done." : $"Finished with exit code {process.ExitCode}.");
        }
        catch (Exception ex)
        {
            AppendLog(ex.Message);
        }
        finally
        {
            _runButton.Enabled = true;
        }
    }

    private static void AddArgument(System.Diagnostics.ProcessStartInfo psi, string name, string value)
    {
        if (string.IsNullOrWhiteSpace(value)) return;
        psi.ArgumentList.Add(name);
        psi.ArgumentList.Add(value);
    }

    private void AppendLog(string text)
    {
        if (InvokeRequired)
        {
            BeginInvoke(() => AppendLog(text));
            return;
        }

        _logBox.AppendText(text + Environment.NewLine);
        _logBox.SelectionStart = _logBox.TextLength;
        _logBox.ScrollToCaret();
    }

    private void OpenReport()
    {
        if (!File.Exists(_reportBox.Text))
        {
            AppendLog("Report file does not exist yet.");
            return;
        }

        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
        {
            FileName = _reportBox.Text,
            UseShellExecute = true
        });
    }
}
