# GitHub-Updates einrichten

Repository: https://github.com/Vorbye/adiis-m2-helper

Dieses Paket ist vorbereitet, aber noch nicht von ChatGPT auf GitHub hochgeladen.

## Einmalig den Quellcode hochladen

1. ZIP auf deinem PC entpacken, dann den Ordner `Adiis-m2-helper` öffnen.
2. Im GitHub-Repository **Add file → Upload files** öffnen.
3. Die Dateien **aus diesem Ordner** hochladen, nicht den übergeordneten Ordner und nicht die ZIP. `AHKManager.csproj`, `Program.cs` und `AppUpdates.cs` müssen direkt auf der ersten Repository-Ebene liegen. Keine eigenen Skripte oder persönlichen Einstellungsdateien hochladen.
4. Mit **Commit changes** speichern.
5. Falls der Ordner `.github` nicht mit hochgeladen wurde: **Add file → Create new file**. Als Namen `.github/workflows/windows-release.yml` eingeben. Den vollständigen Inhalt der mitgelieferten gleichnamigen Datei hineinkopieren und speichern.

## Ersten fertigen Download bauen

1. Im Repository **Actions → Windows Release bauen** öffnen.
2. **Run workflow** wählen, Version `1.4.0` eintragen und starten.
3. Warten, bis der Lauf erfolgreich ist. Er prüft den PowerShell-Code und kompiliert beide C#-Teile auf Windows.
4. Unter **Releases** den Entwurf `v1.4.0` öffnen.
5. **Adiis-m2-helper-win-x64.zip** herunterladen, vollständig entpacken und auf deinem PC testen. Der komplette App-Ordner gehört zur EXE.
6. Wenn alles funktioniert, den Release-Entwurf mit **Publish release** veröffentlichen. Entwürfe werden vom Update-Button nicht angeboten.
7. Deinen Freunden den Release-Link schicken. Sie laden die Windows-ZIP herunter und starten die EXE, ohne selbst zu bauen. Für AHK-Skripte brauchen sie AutoHotkey v2 oder die vorhandene portable Laufzeit. Der Build verteilt keine zusätzliche AutoHotkey-Laufzeit.

## Weitere Updates

1. Neue Quellcode-Dateien im Repository aktualisieren. `AppUpdates.cs` und der Workflow gehören dazu.
2. Den Workflow erneut starten, mit einer höheren dreiteiligen Versionsnummer, z. B. `1.4.1`. Eine Nummer nur einmal verwenden.
3. Windows-Download aus dem neuen Entwurf testen, dann veröffentlichen.
4. Deine Freunde klicken im Helper auf **Updates**, bestätigen das Angebot und der Helper startet nach der Installation neu.

Die Version wird vom Workflow in EXE und Oberfläche gesetzt. Auf deinem eigenen PC gebaute Versionen verwenden die `<Version>` aus `AHKManager.csproj`.

## Was das Update verändert

Nur fünf Programmdateien: die EXE und `App/server.ps1`, `App/index.html`, `App/MetinWindows.cs`, `App/icon.png`.

Eigene `Scripts`, eine vorhandene portable AutoHotkey-Laufzeit und die Daten unter `%APPDATA%\AHKManager` werden nicht überschrieben. Ab Version 1.4.2 ersetzt der Installer die Programmdateien direkt und erstellt keine Update-Backups. Bei einer fehlgeschlagenen Installation kann das aktuelle Windows-Paket manuell über die vorhandenen Programmdateien entpackt werden.

Der Helper lädt nur das feste Windows-Paket aus diesem Repository über HTTPS, vergleicht dessen SHA-256 mit der Release-Prüfsumme und akzeptiert ausschließlich die erwarteten Programmdateien. Das schützt vor beschädigten Downloads und falschen Paketinhalten; die Freigabe der veröffentlichten Version bleibt bei dir als Repository-Inhaber. Es gibt keinen GitHub-Schlüssel in der App.

Zum Installieren muss der App-Ordner beschreibbar sein. Den Helper z. B. in einem eigenen Ordner unter Dokumente verwenden; bei erhöhten Rechten auch das Update aus derselben Sitzung installieren. Bei Netzproblemen, GitHub-Limits oder fehlenden Assets erscheint eine Meldung statt einer Installation.

Die Windows-Kompilierung und ein echter Update-Durchlauf konnten in dieser Chat-Umgebung nicht ausgeführt werden. Der erste GitHub-Build prüft die Kompilierung; vor Veröffentlichung bitte Installation, Timer und Fensterfunktionen unter Windows testen.

## Wechsel von 1.4.1 auf 1.4.2 ohne weiteres Backup

Version 1.4.1 kopiert noch ihren eigenen alten Installer und erstellt deshalb beim automatischen Update ein letztes Backup. Um das zu vermeiden: Version 1.4.2 bauen, ZIP herunterladen, Helper schließen und den vollständigen Inhalt über den vorhandenen App-Ordner entpacken. Eigene Scripts und eine vorhandene AutoHotkey-Laufzeit dabei behalten. Ab dann sind automatische Updates ohne Update-Backup möglich. Bereits vorhandene Backup-Ordner werden durch diese Änderung nicht automatisch gelöscht.
