# Tests

## Automatisch in der VM (`test/vm-test.sh`)

| Prüfung | Wie |
|---|---|
| ISO installiert sich | unbeaufsichtigte Installation in QEMU/KVM |
| Secure Boot an | `mokutil --sb-state` in der VM (UEFI mit Microsoft-Schlüsseln) |
| Desktop startet | `plasmashell` läuft, Sitzung ist Wayland, Screenshot `out/test/vm/desktop.png` |
| Windows-Programm per Wine | selbst kompiliertes `winhello.exe`, Konsole und Fenster (`wine-gui.png`) |
| Keine kaputten Dienste | `systemctl --failed` ist leer |

## Auf echter Hardware (nur du kannst das prüfen)

Testgerät: Acer Aspire Lite 15 (AL15-45P): Ryzen 7 5825U, Radeon-Grafik, Realtek RTL8852BE WLAN.
Bitte jeden Punkt abhaken und Probleme mit kurzer Beschreibung notieren.

### Installation
- [ ] Vom USB-Stick booten **mit eingeschaltetem Secure Boot**
- [ ] Installation durchlaufen, Benutzer anlegen, Neustart startet in den Desktop

### Alltag
- [ ] WLAN verbinden. Danach 30 Minuten surfen ohne Abbrüche (Realtek-Chip: bitte besonders darauf achten)
- [ ] Bluetooth: Kopfhörer oder Maus koppeln
- [ ] Firefox: Seiten laden, YouTube-Video in 1080p läuft flüssig und mit Ton
- [ ] Lokales Video (z. B. MP4) in VLC abspielen
- [ ] LibreOffice: Dokument öffnen, speichern
- [ ] Drucker (falls vorhanden) wird gefunden und druckt
- [ ] **Standby:** Deckel zu, 5 Min warten, Deckel auf. Bild, WLAN, Ton und Touchpad gehen wieder
- [ ] Standby 3× hintereinander
- [ ] Akku: Laufzeit beim Surfen notieren (Einstellungen → Energieverwaltung)
- [ ] Helligkeit- und Lautstärketasten funktionieren
- [ ] Touchpad: Tippen = Klick, Zwei-Finger-Scrollen, 4-Finger-Wischen (Übersicht / Arbeitsfläche)
- [ ] Meta+Leertaste öffnet die Suche (Spotlight)

### Gaming
- [ ] Steam startet, Anmeldung klappt
- [ ] Heroic: Epic-Konto anmelden, Rocket League installieren
- [ ] Rocket League startet mit Proton (in Heroic: Proton-GE über ProtonUp-Qt installieren und auswählen)
- [ ] **Rocket League verbindet sich online** (Easy Anti-Cheat) und ein Online-Match funktioniert
- [ ] FPS mit MangoHud anzeigen (in Heroic: „MangoHud aktivieren“). FPS über 10 Minuten notieren, Ruckler?
- [ ] GameMode aktiv (in Heroic aktivieren; Prüfen: `gamemoded -s` im Terminal während das Spiel läuft)

### Updates und Rollback
- [ ] Später, sobald Updates veröffentlicht werden: Update installieren, neu starten, im Startmenü
      die vorherige Version wählen. Das alte System startet wieder.
