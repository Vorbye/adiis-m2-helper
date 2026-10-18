using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Web.WebView2.WinForms;

internal static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        if (args.Length == 1 && args[0] == "--test-updater")
        {
            Environment.Exit(AppUpdates.TestPackageValidation());
            return;
        }
        ApplicationConfiguration.Initialize();
        if (args.Length == 5 && args[0] == "--apply-update")
        {
            AppUpdates.Install(args);
            return;
        }
        Application.Run(new ManagerWindow());
    }
}
public sealed class ManagerWindow : Form
{
    private readonly WebView2 view = new() { Dock = DockStyle.Fill };
    private readonly string readyFile = Path.Combine(Path.GetTempPath(), "ahk-manager-" + Guid.NewGuid().ToString("N") + ".txt");
    private Process? backend;
    private bool shuttingDown;
    private bool updateBusy;
    public ManagerWindow()
    {
        Text = "Adiis m2 helper – made by Adii";
        StartPosition = FormStartPosition.CenterScreen;
        Width = 1220;
        Height = 810;
        MinimumSize = new Size(800, 550);
        BackColor = Color.FromArgb(14, 20, 35);
        // Fenstericon aus der eingebetteten EXE-Ressource laden (Titel + Taskleiste).
        // Damit ist keine separate .ico im Ausgabeordner erforderlich.
        Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath)
            ?? SystemIcons.Application;
        Controls.Add(view);
        Shown += async (_, _) => await StartManagerAsync();
        FormClosing += (_, _) => StopBackend();
    }
    private async Task StartManagerAsync()
    {
        try
        {
            string dir = AppContext.BaseDirectory;
            string script = Path.Combine(dir, "App", "server.ps1");
            if (!File.Exists(script)) throw new FileNotFoundException("server.ps1 fehlt.", script);
            foreach (string name in new[] { "index.html", "MetinWindows.cs", "icon.png" })
            {
                string required = Path.Combine(dir, "App", name);
                if (!File.Exists(required))
                    throw new FileNotFoundException("App-Datei fehlt: " + required + "\nBitte den gesamten Fertige-App-Ordner verwenden oder EXE-erstellen.bat erneut ausfuehren.");
            }
            var psi = new ProcessStartInfo("powershell.exe")
            {
                Arguments = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\"",
                WorkingDirectory = dir,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true,
                RedirectStandardOutput = true
            };
            psi.Environment["AHK_MANAGER_READY_FILE"] = readyFile;
            psi.Environment["AHK_MANAGER_APP_DIR"] = dir;
            backend = Process.Start(psi) ?? throw new Exception("PowerShell-Backend konnte nicht gestartet werden.");
            // Drain both streams immediately so diagnostic output cannot block startup.
            Task<string> errorOutput = backend.StandardError.ReadToEndAsync();
            Task<string> standardOutput = backend.StandardOutput.ReadToEndAsync();
            string? url = null;
            for (int i = 0; i < 120; i++)
            {
                if (File.Exists(readyFile))
                {
                    url = File.ReadAllText(readyFile).Trim();
                    break;
                }
                if (backend.HasExited)
                {
                    string details = (await errorOutput).Trim();
                    if (string.IsNullOrWhiteSpace(details)) details = (await standardOutput).Trim();
                    if (details.Length > 4000) details = details.Substring(0, 4000);
                    throw new Exception("Der Hintergrunddienst wurde beendet (Code " + backend.ExitCode + ").\n\n" + details);
                }
                await Task.Delay(100);
            }
            if (string.IsNullOrWhiteSpace(url)) throw new TimeoutException("AHK-Hintergrunddienst antwortet nicht.");
            try { File.Delete(readyFile); } catch { }
            await view.EnsureCoreWebView2Async();
            view.CoreWebView2.Settings.AreDevToolsEnabled = false;
            view.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
            view.CoreWebView2.NavigationStarting += (_, args) =>
            {
                if (!args.Uri.StartsWith("http://127.0.0.1:", StringComparison.OrdinalIgnoreCase))
                    args.Cancel = true;
            };
            view.CoreWebView2.ProcessFailed += (_, _) => { };
            var appUrl = new Uri(url);
            view.CoreWebView2.WebMessageReceived += async (_, message) =>
            {
                if (!Uri.TryCreate(message.Source, UriKind.Absolute, out var source) ||
                    source.GetLeftPart(UriPartial.Authority) != appUrl.GetLeftPart(UriPartial.Authority) ||
                    source.Query != appUrl.Query) return;
                string command;
                try { command = message.TryGetWebMessageAsString(); } catch { return; }
                if (command != "checkUpdates" || updateBusy) return;
                updateBusy = true; view.Enabled = false; UseWaitCursor = true;
                try
                {
                    string? stage = await AppUpdates.DownloadAsync(this);
                    if (stage != null)
                    {
                        AppUpdates.LaunchInstaller(stage, AppContext.BaseDirectory);
                        Close();
                    }
                }
                catch (Exception ex) { MessageBox.Show(this, ex.Message, "Update nicht möglich", MessageBoxButtons.OK, MessageBoxIcon.Information); }
                finally
                {
                    updateBusy = false;
                    if (!IsDisposed && !Disposing)
                    {
                        view.Enabled = true; UseWaitCursor = false;
                        view.CoreWebView2.PostWebMessageAsString("updateCheckFinished");
                    }
                }
            };
            view.Source = new Uri(url);
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message,
                "Adiis m2 helper – Startfehler", MessageBoxButtons.OK, MessageBoxIcon.Error);
            Close();
        }
    }
    private void StopBackend()
    {
        if (shuttingDown) return;
        shuttingDown = true;
        try { if (backend != null && !backend.HasExited) backend.Kill(); } catch { }
        try { backend?.Dispose(); } catch { }
        try { if (File.Exists(readyFile)) File.Delete(readyFile); } catch { }
    }
}
