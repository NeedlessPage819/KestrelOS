# Kestrel OS

Linux für Gaming und Alltag. Kestrel OS sieht aus und fühlt sich an wie macOS, startet
Windows-Spiele über Steam, Proton und Wine und kann jedes Update mit einem Befehl rückgängig
machen. Die Grundlage ist Fedora Kinoite (KDE Plasma), ein weit verbreitetes, stabiles System.

Warum etwas so gelöst ist, steht in [DECISIONS.md](DECISIONS.md). Was noch auf echter Hardware
geprüft werden muss, steht in [TESTING.md](TESTING.md).

## Stand

| Bereich | Stand |
|---|---|
| ISO bauen, in einer VM installieren, Desktop startet | läuft, wird bei jedem Build automatisch getestet |
| Live-USB-Stick: ausprobieren, dann installieren | läuft in der VM, auch mit Secure Boot |
| Windows-Programm über Wine | läuft, automatisch getestet |
| Secure Boot | läuft, automatisch getestet (vollständiger Test) |
| Design (Dock, Top-Bar, Fenster, Symbole) | Runde 3, wird weiter verfeinert |
| Echte Hardware (Laptop, Rocket League online) | noch offen, siehe [TESTING.md](TESTING.md) |
| Updates über das Internet verteilen | noch offen, braucht deine Zustimmung (D11) |

## Was drin ist

**Desktop wie auf dem Mac**
- Dock unten (Milchglas, kleiner Strich unter laufenden Apps), schlanke durchscheinende Top-Bar
- Fensterknöpfe als Ampel links oben, weiche Schatten, abgerundete Ecken
- Symbole im macOS-Stil (WhiteSur), Schrift Inter
- Suche wie Spotlight mit **Meta+Leertaste**, Launchpad-Knopf im Dock
- Wischgesten auf dem Touchpad, Hell- und Dunkelmodus („Kestrel“ und „Kestrel Dunkel“, auch automatisch)

**Gaming**
- Steam, Wine, Proton, Heroic, Lutris, Bottles, ProtonUp-Qt
- GameMode, MangoHud (FPS-Anzeige), Gamescope
- Regeln für Controller (Xbox, PlayStation, Switch) sind vorinstalliert
- Easy Anti-Cheat (z. B. Rocket League) soll über Proton laufen. Das wird auf echter Hardware
  geprüft. Secure Boot bleibt an, nichts greift in Anti-Cheat-Prüfungen ein.

**Hardware**
- Intel- und AMD-Grafik laufen sofort. Nvidia-Treiber sind dabei und schalten sich nur ein,
  wenn eine Nvidia-Karte gefunden wird.
- Läuft auch in VMs (QEMU/KVM, VirtualBox, VMware).

**Updates, die nichts kaputt machen**
- Updates werden im Hintergrund vorbereitet und erst beim nächsten Neustart aktiv.
- Das vorherige System bleibt erhalten. Geht etwas schief, ist es mit einem Befehl zurück.

## Bedienung im Terminal

```bash
kestrel update     # System und Apps aktualisieren (wirkt nach Neustart)
kestrel rollback   # zurück zum vorherigen System (wirkt nach Neustart)
kestrel status     # welche Version läuft, welche ist vorbereitet
```

## Aufbau des Projekts

```
config.env              alle Versionen, Namen und Quellen an einem Ort
build.sh                baut Image und ISO
image/Containerfile     das System als Container-Image
image/build/            Bauschritte: install/ (Pakete, langsam, wird zwischengespeichert),
                        configure/ (Einstellungen, schnell)
image/packages/         Paketlisten (eine Zeile = ein Paket)
image/artwork/          Hintergrundbild, Fensterrahmen und Dock-Design als Quellcode
image/system_files/     Dateien, die 1:1 ins System kopiert werden
image/live/             Live-Schicht für den USB-Stick (Live-Start, Installer, Kestrel-Branding)
iso/live/               baut das Live-ISO und das Kestrel-Startmenü
iso/release.toml        Einstellungen für das reine Installations-ISO
test/vm-test.sh         automatischer Test: installiert das ISO in einer VM und prüft alles
test/live-test.sh       startet das Live-ISO in einer VM und macht Bilder
test/vm-live.sh         Design schnell ausprobieren, ohne neu zu bauen
sandbox/setup.sh        richtet die Build-Umgebung ein
sandbox/watchdog.sh     Wächter für lange Builds (meldet Hänger)
```

## Bauen

Gebaut wird nur in einer Sandbox, nie auf dem echten System: Fedora in WSL2 auf Windows
(oder eine Linux-VM).

**Einmalig in Windows:** unter „Windows-Features aktivieren oder deaktivieren“ die
**Windows-Hypervisor-Plattform** einschalten (für die Test-VM). Dann in PowerShell als
Administrator, danach neu starten:

```powershell
wsl --install --no-distribution
wsl --install FedoraLinux-44
```

In `C:\Users\<du>\.wslconfig` (bei 16 GB RAM bewährt; mehr Speicher ohne Swap ließ WSL einfrieren):

```ini
[wsl2]
nestedVirtualization=true
memory=8GB
swap=16GB

[experimental]
autoMemoryReclaim=dropCache
```

**Dann in Fedora (WSL):**

```bash
git clone /mnt/c/Users/<du>/Documents/OS ~/kestrel && cd ~/kestrel
sudo sandbox/setup.sh
sudo ./build.sh iso            # Live-ISO (ausprobieren, dann installieren) in out/, nur UEFI
sudo ./build.sh installer-iso  # reines Installations-ISO, startet auch auf alten BIOS-Rechnern
```

Der erste Build dauert lange (etwa eine Stunde, alle Pakete werden geladen). Danach kommen die
Pakete aus dem Zwischenspeicher, und Design-Änderungen sind in wenigen Minuten im Image.

**Testen:**

```bash
sudo ./build.sh test-iso      # ISO, das sich ohne Fragen selbst installiert
test/vm-test.sh               # vollständiger Test inkl. Secure Boot (über eine Stunde)
QUICK=1 test/vm-test.sh       # schneller Test für Design-Runden, ohne Secure-Boot-Start
test/live-test.sh             # Live-ISO starten: Bilder von Menü, Desktop, Installer, Secure Boot
```

Screenshots landen in `out/test/vm/`.

**Wächter für lange Builds** (auf der Windows-Seite, in Git Bash): meldet, wenn WSL nicht mehr
antwortet, der Build lange keine Ausgabe mehr schreibt oder Windows der Speicher ausgeht.

```bash
sandbox/watchdog.sh <systemd-unit> <build-log> [minuten-ohne-ausgabe]
```

**Design live ausprobieren** (die VM aus dem letzten Test wird weiterverwendet):

```bash
test/vm-live.sh start         # installierte Test-VM starten
test/vm-live.sh theme         # Fensterrahmen aus image/artwork/ übernehmen
test/vm-live.sh plasma        # Dock- und Top-Bar-Design übernehmen
test/vm-live.sh shot name     # Screenshot nach out/test/vm/name.png
test/vm-live.sh stop
```

## Fremde Bausteine

| Baustein | Quelle | Lizenz |
|---|---|---|
| Basis-System | Fedora Kinoite über Universal Blue (`ghcr.io/ublue-os/kinoite-main`) | verschiedene freie Lizenzen |
| Nvidia-Treiber | Universal Blue akmods, von Nvidia | proprietär (frei verteilbar) |
| Steam | RPM Fusion | proprietär (frei verteilbar) |
| Symbole | [WhiteSur](https://github.com/vinceliuice/WhiteSur-icon-theme), fest auf eine Version gepinnt | GPL-3.0 |

Die genauen Versionen jedes Builds stehen in `out/manifest.txt` und `out/packages.txt`.
