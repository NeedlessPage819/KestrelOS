# Entscheidungen

Hier steht jede wichtige Entscheidung: **was**, **warum** und **was wir dafür in Kauf nehmen**.
Neueste Einträge kommen ans Ende.

---

## D1 – Arbeitsname „Kestrel OS“

**Was:** Das System heißt vorerst *Kestrel OS* (Kestrel = Turmfalke: klein, schnell).
**Warum:** Wir brauchen einen Namen für Dateien und Menüs. Er steht nur an einer Stelle
(`config.env`) und lässt sich jederzeit ändern.

---

## D2 – Basis: Fedora Kinoite (Atomic Desktop) über Universal Blue

**Was:** Wir bauen auf **Fedora Kinoite** auf. Das ist das offizielle Fedora mit KDE Plasma,
als „atomares“ System. Als Startpunkt nehmen wir das Image `kinoite-main` von
**Universal Blue**. Das ist dasselbe Fedora, nur schon mit Multimedia-Codecs und
fertig signierten Nvidia-Treibern. Darauf bauen auch Bazzite und Aurora auf.

**Warum, einfach erklärt:**

| Anforderung | Warum Fedora Atomic passt |
|---|---|
| Updates dürfen nichts kaputt machen | Ein Update wird komplett im Hintergrund vorbereitet und erst beim Neustart aktiv. Geht etwas schief, wählst du im Startmenü einfach die vorherige Version (**Rollback eingebaut**, ohne Extra-Werkzeug). |
| Secure Boot / Anti-Cheat | Fedora startet mit einem von Microsoft signierten Bootloader. Secure Boot kann also **an** bleiben. Kernel und Bootvorgang bleiben Standard. |
| Aktuelle Treiber | Fedora liefert neue Kernel und Mesa-Versionen (AMD/Intel-Grafik) innerhalb weniger Wochen. Debian/Ubuntu-LTS sind hier oft ein Jahr hinterher. |
| Reproduzierbarer Build | Das ganze System wird wie ein Container aus einer Datei (`image/Containerfile`) gebaut. Gleiche Eingaben ergeben das gleiche System. |
| Verbreitet und gepflegt | Fedora wird von Red Hat und einer großen Community gepflegt. Gaming-Distros wie Bazzite beweisen, dass genau dieser Stapel für Spiele funktioniert. |

**Verworfene Alternativen:**
- *Arch Linux + archiso:* Neueste Pakete, aber Secure Boot geht nicht direkt, und ein Rollback
  müsste man selbst bauen (Btrfs + Snapper). Bei Rolling Release ist die Gefahr größer,
  dass ein Update den Alltag stört.
- *Ubuntu/Debian + live-build:* Stabil, aber Grafiktreiber und Mesa sind für Gaming oft zu alt.
  Auch hier gibt es kein eingebautes Rollback.
- *openSUSE Tumbleweed:* Hat Snapshots und Secure Boot, ist aber bei Gaming-Software und
  Nvidia-Paketen weniger verbreitet.

**Was wir dafür in Kauf nehmen:** Programme installiert man im Alltag als **Flatpak**
(über „Discover“), nicht mit `dnf`. Für normale Nutzer ist das sogar einfacher.

---

## D3 – Fedora-Version: 44 (nicht das ganz neue 45)

**Was:** Standard ist Fedora 44 (Einstellung `FEDORA_VERSION` in `config.env`).
**Warum:** Fedora 45 ist gerade erst erschienen. Nach unserer Regel „Alltag geht vor“
nehmen wir die seit Monaten bewährte Version. Fedora 44 bekommt noch bis etwa Mitte 2027
Updates. Sobald 45 ein paar Wochen ohne große Fehler läuft, wechseln wir. Dafür ändert
man nur eine Zahl.

---

## D4 – Desktop: KDE Plasma 6 im macOS-Stil

**Was:** KDE Plasma 6 (Wayland) mit eigenem Layout:
- **Top-Bar:** Startmenü-Knopf links, Programm-Menü (globales Menü), rechts Symbole und Uhr.
- **Dock:** schwebend und zentriert unten. Weicht Fenstern aus und enthält Launchpad-Knopf,
  Lieblings-Apps und Papierkorb.
- **Blur** (Milchglas-Effekt) und weiche Animationen. Fenster minimieren sich mit dem
  „Magic Lamp“-Effekt (wie der Genie-Effekt).
- **Fensterknöpfe links** (Schließen, Minimieren, Maximieren), wie am Mac.
- **Schrift:** *Inter* (sehr gut lesbar, ähnlich wie SF Pro) und *JetBrains Mono* für Code.
- **Spotlight:** KRunner öffnet sich mit **Meta+Leertaste** (Meta = Windows-Taste, entspricht
  Cmd am Mac). KRunner findet Apps, Dateien, rechnet und rechnet Einheiten um.
- **Gesten:** Plasma hat Touchpad-Gesten eingebaut (Wischen mit 4 Fingern: Übersicht und
  Arbeitsflächen wechseln). Tippen zum Klicken ist an.

**Warum KDE und nicht GNOME:** GNOME braucht für Dock und Blur *Erweiterungen*. Die gehen bei
GNOME-Updates oft kaputt, und das widerspricht „Updates dürfen nichts kaputt machen“.
In Plasma sind Dock, Blur, globales Menü und Spotlight **fest eingebaut**.

**Bewusst nicht gemacht:** Wir kopieren keine Apple-Grafiken, Logos oder Icons.
Wir übernehmen das *Gefühl*, nicht das Markenzeichen.

---

## D5 – Grafiktreiber: automatisch nach Hardware

**Was:**
- **AMD und Intel:** Treiber stecken im Kernel und in Mesa und laufen sofort. Es gibt nichts
  einzurichten. Das gilt auch für deinen Acer (AMD Radeon).
- **Nvidia (GTX 16xx / RTX 20xx und neuer):** Der offizielle Nvidia-Treiber („nvidia-open“) ist
  im System enthalten, aber zunächst *ausgeschaltet*. Beim ersten Start prüft der Dienst
  `kestrel-gpu-setup`, ob eine passende Nvidia-Karte da ist. Nur dann schaltet er den Treiber ein
  und startet einmal neu.
- **Ältere Nvidia-Karten (GTX 10xx und älter):** Sie behalten den freien Treiber „nouveau“.
  Der neue Nvidia-Treiber unterstützt sie nicht mehr.

**Warum:** Ein einziges ISO für alle Rechner, ohne dass jemand etwas auswählen muss. Auf Rechnern
ohne Nvidia bleibt der Nvidia-Treiber komplett aus und kann nichts stören.

**Secure Boot mit Nvidia:** Der Nvidia-Treiber ist mit dem Schlüssel von Universal Blue signiert.
Ist Secure Boot an, muss man diesen Schlüssel einmalig bestätigen. Nach dem Neustart erscheint ein
blauer Bildschirm („MOK“), Passwort: `universalblue`. Das betrifft nur Nvidia-Rechner.

---

## D6 – Gaming-Software

**Fest im System (RPM):** Steam, Wine, Winetricks, Lutris, GameMode, MangoHud, Gamescope.
**Beim ersten Start mit Internet (Flatpak):** Heroic (Epic/GOG, z. B. für Rocket League),
Bottles, ProtonUp-Qt.

**Warum diese Aufteilung:** Steam und Wine gehören ins System, weil sie tief mit Treibern und
32-Bit-Bibliotheken verzahnt sind. Wine funktioniert damit auch ohne Internet (das brauchen wir
für den Test). Heroic, Bottles und ProtonUp-Qt veröffentlicht der Hersteller selbst als Flatpak.
Dort sind sie am aktuellsten.

**Leistungs-Einstellungen, die den Alltag nicht stören:**
- `ntsync`: Ein Kernel-Modul, mit dem Wine und Proton Windows-Programme schneller synchronisieren.
  Es wird nur benutzt, wenn ein Spiel läuft.
- `split_lock_mitigate = 0`: Verhindert, dass manche Spiele künstlich ausgebremst werden.
- **GameMode** schaltet die CPU nur *während eines Spiels* auf volle Leistung. Danach läuft sie
  wieder im Stromsparmodus, gut für den Akku.

**Bewusst NICHT gemacht:** Kein eigener Gaming-Kernel, keine geänderten Boot-Parameter, keine
abgeschalteten Sicherheitsfunktionen. Das kostet höchstens ein paar Prozent FPS. Dafür bleiben
Secure Boot, Anti-Cheat-Kompatibilität und Akku-Laufzeit unangetastet (siehe D7).

---

## D7 – Anti-Cheat und Secure Boot

**Was:** Standard-Fedora-Kernel (signiert), Standard-Bootloader (shim + GRUB), keine
Kernel-Patches, keine Sonder-Boot-Parameter für Gaming.
**Warum:** Rocket League (Easy Anti-Cheat) läuft unter Proton bereits. Sollte Epic eines Tages
Fortnite für Linux freigeben, wird es sehr wahrscheinlich ein unverändertes, Secure-Boot-fähiges
System verlangen. Das haben wir dann schon.

---

## D8 – Alltags-Programme als Flatpak

LibreOffice und VLC kommen beim ersten Start mit Internet von Flathub.
Firefox, Dateimanager (Dolphin), Drucken (CUPS), WLAN, Bluetooth und Energieverwaltung sind fest
im System. Flathub ist die einzige App-Quelle, damit Discover keine Apps doppelt anzeigt.
**Warum:** Flatpaks bekommen Updates direkt vom Hersteller. Sie laufen getrennt vom System, damit
können sie das Grundsystem nicht beschädigen.

---

## D9 – Installations-ISO statt Live-System (vorerst)

**Was:** Das ISO ist ein **Installer** (Anaconda, das Programm, das auch Fedora benutzt).
Ein „Ausprobieren ohne Installation“ gibt es vorerst nicht.
**Warum:** Für atomare Systeme ist das der offizielle, stabile Weg (Werkzeug
`bootc-image-builder` von Fedora/Red Hat). Ein Live-ISO prüfen wir später als Verbesserung.

---

## D10 – Bauen und Testen nur in der Sandbox

**Was:** Gebaut und getestet wird ausschließlich in einer **WSL2-Fedora-Umgebung** auf deinem
Windows-PC. Darin läuft eine **QEMU/KVM-VM** mit Secure Boot. Dein Windows bleibt unberührt.
**Warum:** WSL2 ist von Microsoft, sauber getrennt und mit einem Befehl wieder entfernbar.
Fedora in WSL hat genau die Werkzeuge, die auch das Zielsystem nutzt (podman, bootc).

---

## D11 – Ein einfacher Befehl für Updates: `kestrel`

**Was:** Im Terminal gibt es den Befehl `kestrel`:
- `kestrel update`: lädt das neue System und aktualisiert alle Apps. Das neue System gilt ab dem
  nächsten Neustart. Das alte bleibt als Notfall-Version erhalten.
- `kestrel rollback`: beim nächsten Start wieder die vorherige Version nehmen.
- `kestrel status`: zeigt, welche Versionen installiert sind.

Updates gehen auch per Mausklick in **Discover** (dem App-Store von KDE).

**Warum:** Die eigentlichen Werkzeuge (`bootc`, `flatpak`) sind für Anfänger unübersichtlich.
Ein Befehl mit deutschen Meldungen ist einfacher.

**Offen:** Damit installierte Rechner Updates *finden*, muss das fertige System-Image im Internet
liegen (z. B. kostenlos auf GitHub). Das ist eine Veröffentlichung nach außen, deshalb frage ich
vorher nach. Bis dahin aktualisiert man durch Neuinstallation mit einem neuen ISO.

---

## D12 – Eigenes Design statt fremder Themes

**Was:**
- **Hintergrundbild:** eigene Vektorgrafik (Farbverlauf mit weichen Wellen), hell und dunkel.
  Plasma wählt automatisch die passende Variante zum hellen oder dunklen Farbschema. Dasselbe Bild
  erscheint auf dem Sperrbildschirm.
- **Akzentfarbe:** ein ruhiges Blau-Violett (`#5B6CF0`), passend zum Hintergrund.
- **Grundlage:** das Standard-Design „Breeze“ von KDE, nur angepasst.

**Warum:** Fertige „macOS-Themes“ aus dem Internet kopieren oft Apple-Grafiken (rechtlich heikel)
und gehen bei Plasma-Updates gerne kaputt. Breeze wird von KDE selbst gepflegt und bleibt bei
Updates stabil. Wir passen nur Farben, Schrift und Anordnung an.

---

## D13 – Einrichtung beim ersten Start mit dem „Plasma Setup“-Assistenten

**Was:** Das Installationsprogramm fragt nur noch, auf welche Festplatte installiert wird.
Beim ersten Start begrüßt dich dann ein Assistent von KDE. Dort wählst du Sprache, Tastatur
und WLAN und legst dein Benutzerkonto an.
**Warum:** Das fühlt sich an wie der Einrichtungsassistent am Mac: erst installieren, dann
in Ruhe einrichten. Fedora KDE 44 macht es genauso. Wir nutzen also den offiziellen,
gepflegten Weg.

---

## D14 – Kleine Korrekturen für fehlerfreie Systemdienste

- `systemd-remount-fs` startet nicht mehr auf atomaren Systemen. Er versucht dort, den
  schreibgeschützten Systembereich neu einzuhängen, und das schlägt immer fehl. Dieser Fehler
  betrifft nur eine Meldung, keine Funktion.
- `mcelog` (meldet Hardwarefehler der CPU) läuft nur noch auf echter Hardware. In VMs gibt es
  nichts zu melden, dort bricht der Dienst nur mit einem Fehler ab.
- Rechnername ist standardmäßig `kestrel` statt `fedora`.

**Warum:** Ein sauberes System zeigt keine roten Fehlermeldungen. Der automatische Test prüft,
dass kein Systemdienst fehlschlägt.

---

## D15 – Aufgeräumteres macOS-Gefühl (Design-Runde 2)

Nach dem ersten Blick auf den Desktop wirkte er noch nach „KDE mit Dock“. Geändert:

- **Fensterknöpfe als farbige „Ampel“** (rot, gelb, grün; Symbole erscheinen beim Darüberfahren),
  schlanke helle Titelleiste, abgerundete obere Ecken, weicher Schatten. Das ist ein **eigenes
  Fensterdesign** („Aurorae“-Theme, erzeugt von `image/artwork/aurorae.py`).
  *Warum eigenes:* Fertige Lösungen wie „Klassy“ sind kompilierte Programme, die zur genauen
  Plasma-Version passen müssen. Für Fedora 44 gibt es keine Pakete, und ein Plasma-Update könnte
  die Fensterrahmen kaputt machen. Aurorae-Designs sind nur Grafiken, die KWin selbst zeichnet.
  Updates können sie nicht beschädigen.
- **Dock:** größere Symbole und nur Apps, die immer installiert sind (Dateien, Firefox, Steam,
  Discover, Terminal, Einstellungen). Keine leeren Platzhalter mehr. Der Launchpad-Knopf zeigt ein
  App-Raster.
- **Top-Bar:** schlanker, mit eigenem schlichten Logo (Vogel im Gleitflug) und Datum im Stil
  „Di. 17. Nov.“
- **Kein KDE-Begrüßungsfenster** beim ersten Login. Die Einrichtung übernimmt schon der
  Assistent (D13). Abschalten per Einstellung hat im Test nicht gereicht, deshalb wird das Paket
  `plasma-welcome` ganz entfernt. Nichts anderes hängt davon ab.

## D16 – Design-Runde 3: Dock und Top-Bar wie Glas

Neben macOS wirkte das Dock noch unruhig. Geändert:

- **Eigenes Plasma-Design „Kestrel“** (erzeugt von `image/artwork/plasma_theme.py`). Es ersetzt nur
  den Hintergrund von Dock und Top-Bar und die Markierung laufender Apps. Alles andere kommt
  weiter von Breeze, deshalb bleibt es bei Plasma-Updates stabil.
- **Dock:** durchscheinend wie Milchglas, stark abgerundete Ecken, Symbole füllen das Dock.
  Auf echter Hardware verschwimmt der Hintergrund dahinter. In der Test-VM fehlt dafür die
  3D-Beschleunigung, dort ist es nur durchscheinend.
- **Laufende Apps** bekommen einen kleinen Strich unter dem Symbol statt eines blauen Kastens.
- **Top-Bar:** flach und ebenfalls durchscheinend.
- Die Farben kommen aus dem Farbschema, im Dunkelmodus wird alles automatisch dunkel.
- **Fensterschatten repariert:** An den Fensterecken waren helle Lücken im Schatten zu sehen.

## D17 – Symbole im macOS-Stil (WhiteSur)

Die Breeze-Symbole sahen im Dock durcheinander aus: flache Ordner, runde Logos, dunkle Quadrate.
Auf dem Mac haben alle App-Symbole dieselbe abgerundete Quadrat-Form. Deshalb nutzt Kestrel das
freie Symbol-Set **WhiteSur** (Lizenz GPL-3.0). Entschieden mit dir.

- Es ist nicht in Fedora enthalten und wird beim Bauen von GitHub geholt.
- **Sicherheit:** Die Version ist fest auf `2026-09-10` eingestellt, und der Build prüft den
  genauen Stand (Commit `73d8040`). Weicht etwas ab, bricht der Build ab. Das Installations-
  skript läuft nur in einem abgetrennten Bau-Container, nicht im fertigen System.
- **Updates:** Eine neue Version kommt nur, wenn wir sie in `config.env` bewusst eintragen.
- Die Alternative wäre Papirus aus Fedora gewesen: geprüft und einheitlich, aber flach und nicht
  macOS-artig.
- **Papierkorb und Launchpad im Dock:** Plasma zeigt Widgets in Leisten absichtlich als schlichte
  Umriss-Symbole. Im großen Dock passte der Papierkorb so nicht zu den bunten App-Symbolen. Ein
  kleines eigenes Symbol-Set „Kestrel“ übernimmt alles von WhiteSur und tauscht nur den Papierkorb
  gegen die farbige Glas-Version. Der Launchpad-Knopf nutzt das farbige App-Raster.
