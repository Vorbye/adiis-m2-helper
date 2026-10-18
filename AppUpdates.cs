using System.Diagnostics;
using System.IO.Compression;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text.Json;
using System.Windows.Forms;

internal static class AppUpdates
{
    internal const string Repository = "Vorbye/adiis-m2-helper";
    internal const string AssetName = "Adiis-m2-helper-win-x64.zip";
    internal static Version Current => new(typeof(AppUpdates).Assembly.GetName().Version!.ToString(3));
    internal static readonly string[] ManagedFiles = { "Adiis-m2-helper.exe", "App/server.ps1", "App/index.html", "App/MetinWindows.cs", "App/icon.png" };

    internal static async Task<string?> DownloadAsync(IWin32Window owner)
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromMinutes(8) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("Adiis-m2-helper/" + Current);
        client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        using var response = await client.GetAsync("https://api.github.com/repos/" + Repository + "/releases/latest");
        if (response.StatusCode == HttpStatusCode.NotFound)
        {
            MessageBox.Show(owner, "Noch keine öffentliche Update-Version gefunden. Auf GitHub muss zuerst ein fertiges Release veröffentlicht werden.", "Updates");
            return null;
        }
        response.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var release = json.RootElement;
        string tag = release.GetProperty("tag_name").GetString() ?? "";
        if (!Version.TryParse(tag.TrimStart('v', 'V'), out var version)) throw new Exception("Ungültige Release-Version: " + tag);
        if (version <= Current)
        {
            MessageBox.Show(owner, "Du verwendest die aktuelle Version " + Current + ".", "Updates");
            return null;
        }
        JsonElement archive = default, checksum = default;
        foreach (var asset in release.GetProperty("assets").EnumerateArray())
        {
            string? name = asset.GetProperty("name").GetString();
            if (name == AssetName) archive = asset;
            if (name == AssetName + ".sha256") checksum = asset;
        }
        if (archive.ValueKind == JsonValueKind.Undefined || checksum.ValueKind == JsonValueKind.Undefined)
            throw new Exception("Das Release enthält noch kein vollständiges Windows-Update-Paket mit Prüfsumme.");
        if (MessageBox.Show(owner, "Version " + version + " ist verfügbar (installiert: " + Current + ").\n\nJetzt herunterladen und installieren? Der Helper startet danach neu. Laufende AHK-Skripte und persönliche Daten bleiben erhalten.", "Update verfügbar", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return null;
        var zipUrl = AssetUrl(archive);
        var hashUrl = AssetUrl(checksum);
        string folder = Path.Combine(Path.GetTempPath(), "Adiis-m2-update-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(folder);
        try
        {
            string zip = Path.Combine(folder, AssetName);
            await DownloadLimited(client, zipUrl, zip, 200L * 1024 * 1024);
            string hashPath = Path.Combine(folder, "checksum.txt");
            await DownloadLimited(client, hashUrl, hashPath, 1024);
            string expected = (await File.ReadAllTextAsync(hashPath)).Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries)[0];
            if (expected.Length != 64 || !expected.All(Uri.IsHexDigit)) throw new Exception("Ungültige Update-Prüfsumme.");
            await using (var input = File.OpenRead(zip))
            {
                string actual = Convert.ToHexString(await SHA256.HashDataAsync(input));
                if (!actual.Equals(expected, StringComparison.OrdinalIgnoreCase)) throw new Exception("Die Update-Prüfsumme stimmt nicht. Das Update wird nicht installiert.");
            }
            string stage = Path.Combine(folder, "stage");
            ValidateAndExtract(zip, stage);
            var fileVersion = FileVersionInfo.GetVersionInfo(Path.Combine(stage, ManagedFiles[0])).FileVersion;
            if (!Version.TryParse(fileVersion, out var packaged) || packaged.Major != version.Major || packaged.Minor != version.Minor || packaged.Build != Math.Max(0, version.Build))
                throw new Exception("Die Programmversion passt nicht zum Release.");
            return stage;
        }
        catch { Directory.Delete(folder, true); throw; }
    }

    private static Uri AssetUrl(JsonElement asset)
    {
        var uri = new Uri(asset.GetProperty("browser_download_url").GetString()!);
        if (uri.Scheme != "https" || uri.Host != "github.com" || !uri.AbsolutePath.StartsWith("/" + Repository + "/releases/download/", StringComparison.OrdinalIgnoreCase))
            throw new Exception("Das Update stammt nicht aus dem vorgesehenen GitHub-Repository.");
        return uri;
    }
    private static async Task DownloadLimited(HttpClient client, Uri url, string file, long limit)
    {
        using var response = await client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
        response.EnsureSuccessStatusCode();
        if (response.Content.Headers.ContentLength > limit) throw new Exception("Update-Datei zu groß.");
        await using var source = await response.Content.ReadAsStreamAsync();
        await using var output = File.Create(file);
        byte[] buffer = new byte[65536]; long size = 0; int read;
        using var timeout = new CancellationTokenSource(TimeSpan.FromMinutes(8));
        while ((read = await source.ReadAsync(buffer, timeout.Token)) > 0)
        {
            size += read; if (size > limit) throw new Exception("Update-Datei zu groß.");
            await output.WriteAsync(buffer.AsMemory(0, read), timeout.Token);
        }
    }
    internal static void ValidateAndExtract(string zip, string destination)
    {
        using var archive = ZipFile.OpenRead(zip);
        if (archive.Entries.Count > 1000) throw new Exception("Zu viele Dateien im Update.");
        var allowed = new HashSet<string>(ManagedFiles, StringComparer.OrdinalIgnoreCase);
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase); long total = 0;
        Directory.CreateDirectory(destination);
        foreach (var entry in archive.Entries)
        {
            string name = entry.FullName.Replace('\\', '/');
            if (name == "App/" || name == "Scripts/") continue;
            if (!allowed.Contains(name) || !seen.Add(name) || ((entry.ExternalAttributes >> 16) & 0xF000) == 0xA000)
                throw new Exception("Unerwartete Datei im Update: " + name);
            total += entry.Length; if (total > 500L * 1024 * 1024) throw new Exception("Entpacktes Update zu groß.");
            string target = Path.Combine(destination, name.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(Path.GetDirectoryName(target)!);
            entry.ExtractToFile(target);
        }
        if (!allowed.SetEquals(seen)) throw new Exception("Benötigte Programmdateien fehlen im Update.");
    }
    internal static void LaunchInstaller(string stage, string target)
    {
        string executable = Path.Combine(Path.GetDirectoryName(stage)!, "Installer.exe");
        File.Copy(Application.ExecutablePath, executable);
        var start = new ProcessStartInfo(executable) { UseShellExecute = true, WorkingDirectory = Path.GetDirectoryName(executable)! };
        start.ArgumentList.Add("--apply-update"); start.ArgumentList.Add(stage); start.ArgumentList.Add(target);
        start.ArgumentList.Add(Environment.ProcessId.ToString());
        start.ArgumentList.Add(Process.GetCurrentProcess().StartTime.ToUniversalTime().Ticks.ToString());
        _ = Process.Start(start) ?? throw new Exception("Update-Helfer konnte nicht gestartet werden.");
    }
    internal static void Install(string[] args)
    {
        string stage = Path.GetFullPath(args[1]), target = Path.GetFullPath(args[2]);
        string backup = Path.Combine(target, "Update-Backup-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N").Substring(0, 6));
        var changed = new List<string>();
        try
        {
            try
            {
                using var old = Process.GetProcessById(int.Parse(args[3]));
                if (old.StartTime.ToUniversalTime().Ticks.ToString() == args[4] && !old.WaitForExit(30000))
                    throw new Exception("Der Helper ist noch geöffnet. Update abgebrochen.");
            }
            catch (ArgumentException) { }
            foreach (string file in ManagedFiles)
            {
                string source = Path.Combine(stage, file);
                if (!File.Exists(source)) throw new Exception("Update-Datei fehlt: " + file);
                string dest = Path.Combine(target, file);
                if (File.Exists(dest))
                {
                    string safe = Path.Combine(backup, file); Directory.CreateDirectory(Path.GetDirectoryName(safe)!); File.Copy(dest, safe);
                }
            }
            foreach (string file in ManagedFiles)
            {
                string dest = Path.Combine(target, file); Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
                changed.Add(file); File.Copy(Path.Combine(stage, file), dest, true);
            }
            Process.Start(new ProcessStartInfo(Path.Combine(target, ManagedFiles[0])) { UseShellExecute = true, WorkingDirectory = target });
        }
        catch (Exception error)
        {
            var restoreErrors = new List<string>();
            foreach (string file in changed.AsEnumerable().Reverse())
            {
                try { string safe = Path.Combine(backup, file), dest = Path.Combine(target, file); if (File.Exists(safe)) File.Copy(safe, dest, true); else File.Delete(dest); }
                catch (Exception ex) { restoreErrors.Add(file + ": " + ex.Message); }
            }
            MessageBox.Show("Update fehlgeschlagen: " + error.Message + "\n\nSicherung: " + backup + (restoreErrors.Count == 0 ? "\nBereits ersetzte Dateien wurden zurückgesetzt. Du kannst den Helper erneut starten." : "\nWiederherstellung unvollständig:\n" + string.Join("\n", restoreErrors)), "Update", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
    internal static int TestPackageValidation()
    {
        string folder = Path.Combine(Path.GetTempPath(), "Adiis-update-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(folder);
        try
        {
            void Make(string name, IEnumerable<string> files)
            {
                using var zip = ZipFile.Open(Path.Combine(folder, name), ZipArchiveMode.Create);
                foreach (string file in files)
                {
                    using var writer = new StreamWriter(zip.CreateEntry(file).Open());
                    writer.Write("test");
                }
            }
            Make("valid.zip", ManagedFiles);
            ValidateAndExtract(Path.Combine(folder, "valid.zip"), Path.Combine(folder, "valid"));
            foreach (string file in ManagedFiles) if (!File.Exists(Path.Combine(folder, "valid", file))) return 1;
            string[][] invalid = {
                ManagedFiles.Append("../outside.txt").ToArray(),
                ManagedFiles.Append(ManagedFiles[0]).ToArray(),
                ManagedFiles.Skip(1).ToArray(),
                ManagedFiles.Append("Scripts/private.ahk").ToArray(),
                ManagedFiles.Append("App/AutoHotkey/AutoHotkey64.exe").ToArray()
            };
            for (int i = 0; i < invalid.Length; i++)
            {
                Make("bad" + i + ".zip", invalid[i]);
                bool rejected = false;
                try { ValidateAndExtract(Path.Combine(folder, "bad" + i + ".zip"), Path.Combine(folder, "bad" + i)); }
                catch { rejected = true; }
                if (!rejected) return 1;
            }
            return File.Exists(Path.Combine(folder, "outside.txt")) ? 1 : 0;
        }
        catch { return 1; }
        finally { try { Directory.Delete(folder, true); } catch { } }
    }
}
