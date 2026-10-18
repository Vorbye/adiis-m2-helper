Adiis m2 helper – Version 1.4.0

Enthalten: bisheriger AHK Manager mit AutoHotkey v2 und Rückgängig-Funktion
sowie die neue Seite Fenstererkennung im gleichen Dark-Design.

START / EXE ERSTELLEN
1. ZIP vollständig entpacken.
2. EXE-erstellen.bat unter Windows ausführen (.NET 8 SDK erforderlich).
3. Fertige-App\Adiis-m2-helper.exe starten.
App- und Scripts-Ordner gehören weiterhin zur EXE und müssen dabei bleiben.
Es öffnet sich ein App-Fenster, kein zusätzliches PowerShell-Fenster.

BESTEHENDE SKRIPTE
Der Helper verwendet weiterhin die Einstellungen unter %APPDATA%\AHKManager.
Gruppen, Anzeigenamen, Favoriten und Skriptliste bleiben dadurch erhalten.
Bestehende AHK-Dateien an ihrem bisherigen Speicherort lassen.
Nach einem Umzug: 'Pfad reparieren' zum neuen Speicherort verwenden.
Die bisherige App während der Benutzung des Helpers schließen.

FENSTERERKENNUNG
- Oben 'Fenstererkennung' anklicken.
- Fenster von metin2client.exe werden alle 2 Sekunden automatisch erkannt.
- Titel, Prozess-ID, Fenster-ID und minimierter Zustand werden angezeigt.
- Fenster anklicken oder 'Markieren' drücken: Fenster wird nach vorne geholt,
  bei Bedarf wiederhergestellt und etwa 1,6 Sekunden violett umrahmt.
  Windows kann die Aktivierung im Vordergrund in einzelnen Fällen beschränken.
- 'Schließen' zeigt eine Rückfrage mit Titel und IDs. Nach Bestätigung wird
  eine normale Windows-Schließanfrage genau an dieses Fenster gesendet.
  Spielinterne Rückfragen müssen gegebenenfalls im Client bestätigt werden.
  Ein hängender Client wird damit nicht zwangsweise beendet.
- Clients mit einem anderen EXE-Namen werden in dieser Version nicht erfasst.
- Läuft Metin2 als Administrator, auch den Helper als Administrator starten.
  Prozesse ohne lesbare Prozessdaten können sonst in der Liste fehlen.

BUILD-HINWEIS
Dieses Paket enthält den vollständigen Windows-Quellcode und die Build-Datei,
keine vorkompilierte EXE. Der Windows-Build und die Steuerung echter Metin2-
Fenster konnten in der Linux-Arbeitsumgebung nicht ausgeführt werden.
Wie bisher: AutoHotkey v2 für Skripte, WebView2 für die Oberfläche.
Fenstererkennung und Markierung benötigen kein AHK-Skript.

NEU IN VERSION 1.1
- Abschaltbarer, sanfter Hinweiston (ca. 0,22 Sekunden), wenn ein erkanntes
  Fenster zweimal hintereinander fehlt. Bei mehreren gleichzeitig fehlenden
  Fenstern wird nur ein Ton pro Prüfzyklus abgespielt.
- Vom Helper angeforderte Schließvorgänge bleiben für 30 Sekunden stumm.
  Wenn ein Spiel-Dialog das Schließen verhindert, wird das Fenster danach
  wieder normal überwacht. Manuelles Schließen außerhalb des Helpers zählt
  ebenfalls als Verschwinden; ein Absturz lässt sich nicht sicher unterscheiden.
- Ton testen und gespeicherter Ein/Aus-Schalter auf der Fensterseite.
- Bis zu 30 benannte Timer mit Stunden/Minuten/Sekunden, Pause, Fortsetzen,
  Neustart und Entfernen. Separater gespeicherter Tonschalter für Timer.
- Notizen mit automatischem Speichern nach Schreibpause und Speichern-Button.
- Daten unter %APPDATA%\AHKManager\helper-tools.json, unabhängig vom App-Ordner.
- Überwachung und Timer-Töne funktionieren auch bei minimierter App. Die App
  muss geöffnet bleiben. Beim Neustart werden abgelaufene Timer ohne Ton gezeigt.
- Fenster, die zwischen zwei Prüfungen geöffnet und geschlossen werden, können
  nicht erkannt werden. Ohne lesbare Prozessdaten können Fenster fehlen.

PRÜFUNG
JavaScript-Syntax und Bedienlogik für Navigation, Fensterliste, Schließen,
Timer, Toneinstellungen und Notizenspeicherung wurden geprüft. Der native
Windows-Build, Audioausgabe und echte Metin2-Fenster sind hier nicht testbar.

FIX 1.1.1
Ungültiger Sicherungspfad beim wiederholten Speichern behoben.
Bestehende Einstellungen und Notizen werden beibehalten; die vorige Version
wird beim Speichern als helper-tools.json.bak gesichert.

NEU IN VERSION 1.2
TIMER-VORLAGEN
Name und Dauer eingeben, dann 'Als Vorlage speichern'. Über 'Starten' kann
jede Vorlage beliebig oft gestartet werden und bleibt nach Ablauf erhalten.
'Bearbeiten' lädt Name und Dauer ins Formular; Speichern unter gleichem Namen
aktualisiert die Dauer. Das X entfernt nur die Vorlage, keine laufenden Timer.

SCHWEBENDE TIMER
'Schwebende Timer-Anzeige' auf der Timer-Seite aktivieren/deaktivieren.
Die Anzeige zeigt alle laufenden/pausierten und abgelaufenen Timer zusammen.
Zum Verschieben die Anzeige mit linker Maustaste anfassen und ziehen.
Die Position wird gespeichert. Abgelaufene Timer bleiben mit 'Fertig' sichtbar,
bis sie im Helper entfernt oder neugestartet werden. Eine gemeinsame Anzeige
für alle Timer; einzelne Timer lassen sich darin nicht getrennt verschieben.
Auch bei minimiertem Helper sichtbar. Exklusiver Vollbildmodus eines Spiels
kann die Anzeige verdecken; gegebenenfalls Fenster-/randlosen Modus verwenden.

NOTIZEN
Links eine durchsuchbare Liste benannter Notizen, rechts der Inhaltseditor.
Neue Notiz, Umbenennen und Entfernen sind vorhanden. Inhalte werden automatisch
nach Schreibpause gespeichert. Beim Wechseln wird zuerst gespeichert.
Bisherige Inhalte werden einmalig als 'Bisherige Notizen' übernommen.
Vorlagen, Notizen und der Overlay-Schalter bleiben in helper-tools.json;
die Overlay-Position liegt daneben in timer-overlay-position.txt.

Version 1.2: JavaScript-Syntax und Bedienlogik geprüft. Windows-Kompilierung,
Overlay-Darstellung und echtes Spielverhalten konnten hier nicht geprüft werden.

FIX 1.2.1
Doppelt verwendeten Variablennamen im Overlay-Code behoben.
Startfehler zeigen jetzt die eigentliche Ausgabe des Hintergrunddienstes.

LOGO-UPDATE 1.2.2
Neues AM2-Logo in Oberfläche, Titelleiste und eingebettetem EXE-Symbol.
Windows-ICO mit Größen von 16 bis 256 Pixeln. Falls die Taskleiste noch das
alte Logo zeigt: alte Anheftung lösen und die neue EXE erneut anheften.

NOTIZLISTE 1.2.3
- Links nur Notiztitel, ohne Inhaltsvorschau.
- Notiz am Titel mit gedrückter Maustaste auf eine andere Zeile ziehen.
  Die Reihenfolge wird gespeichert und beim nächsten Start wiederhergestellt.
- Rechtsklick auf eine Notiz: Umbenennen oder Löschen.
  Das Menü bezieht sich auf genau die angeklickte Notiz. Vor einem Wechsel
  werden offene Änderungen gespeichert. Löschen verlangt eine Bestätigung.
- Menü schließen: außerhalb klicken oder Escape.
Bedien- und Speicherlogik geprüft, Windows-Build hier nicht ausführbar.

LOGO-FIX 1.2.4
AM2-Logo und Browser-Icon sind direkt in index.html eingebettet.
Keine separate Logo-Anfrage mehr nötig. Das eingebettete Windows-ICO bleibt
weiterhin im Projekt. Logo-Daten dekodiert und gegen die PNG-Datei geprüft.
Windows-Build hier weiterhin nicht ausführbar.

BUILD-FIX 1.2.5
Alle App-Dateien bleiben explizit ausserhalb des Einzel-EXE-Bundles.
Die Build-Datei kopiert und prüft server.ps1, index.html, MetinWindows.cs
und icon.png vor dem Austausch des bisherigen Fertige-App-Ordners.
Die App prüft die Dateien vor dem Start. Nur Program.cs wird im Host kompiliert,
damit vorhandene Fertige-App- und Backup-Ordner den Neubau nicht stören.

TASK BEENDEN 1.2.6
Auf der Fensterseite beendet 'Task beenden' nach Bestätigung den zugehörigen
Metin2-Prozess vollständig. Keine normale WM_CLOSE-Schließanfrage mehr.
Prozessname, Prozessstart und Fenster-ID werden vor dem Zugriff geprüft.
Der Prozesshandle wird vor der abschließenden Identitätsprüfung festgehalten.
Bei fehlenden Rechten: Helper ebenfalls als Administrator starten.
Alle Fenster desselben Prozesses schließen sich. Andere Prozesse bleiben offen.
Der bewusst beendete Prozess löst keinen Fenster-Hinweiston aus.
Die früheren Hinweise zu normalen Schließanfragen sind damit überholt.
Windows-Prozessbeendigung hier nicht ausführbar; Bedienlogik geprüft.

ANZEIGE 1.2.7
Standard-Skriptnamen erscheinen ohne Dateiendung in der Oberfläche.
Eigene Anzeigenamen, Dateinamen und Dateipfade werden nicht verändert.

OBERFLÄCHE 1.3
Die schwebende Timer-Anzeige wurde als kompakte, abgerundete dunkle Karte mit
violetten Akzenten gestaltet. Titel einzeilig mit Kürzung, darunter Restzeit.
Breite 236 Pixel; Höhe richtet sich nach der Anzahl der Timer.
Mit linker Maustaste an beliebiger Stelle ziehen; Position bleibt gespeichert.
Bis zu 6 Timer gleichzeitig sichtbar, weitere über das Mausrad erreichbar.
Hilfe und AHK-Einstellungen stehen nur noch innerhalb der AHK-Manager-Seite,
rechts neben der Code-Editor-Überschrift. Die Einstellungen erklären, wie der
AutoHotkey-v2-Interpreter automatisch erkannt oder manuell ausgewählt wird.
JavaScript-Syntax und bestehende Bedienlogik geprüft. Windows-Darstellung und
Windows-Build konnten hier nicht ausgeführt werden.

GITHUB-UPDATES 1.4.0
Neuer Updates-Button für Vorbye/adiis-m2-helper.
Einrichtung siehe GITHUB-START.md im selben Ordner.
Enthalten: automatischer Windows-Build als GitHub-Actions-Workflow,
SHA-256-Prüfung, Prüfung der erwarteten Paketdateien, Backup und Installer.
Der Workflow prüft die PowerShell-Syntax, kompiliert den nativen Code und
führt Tests für gültige Pakete, Pfadmanipulationen, doppelte Dateien,
fehlende Dateien und unerlaubte Skript-/Interpreter-Dateien aus.
Es wurde noch nichts durch ChatGPT auf GitHub veröffentlicht. Die lokale
Arbeitsumgebung konnte den Windows-Build und ein echtes Update nicht ausführen.
