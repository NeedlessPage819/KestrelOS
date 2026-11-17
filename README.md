# Kestrel OS

Linux für Gaming und Alltag: Fedora Kinoite (KDE Plasma) mit macOS-artigem Desktop,
vorinstalliertem Steam, Wine, Proton, Heroic, Lutris und Bottles, automatischen
Grafiktreibern und Rollback bei Updates. Begründungen stehen in [DECISIONS.md](DECISIONS.md),
Tests in [TESTING.md](TESTING.md).

## Aufbau

```
config.env            alle Versionen und Namen an einem Ort
build.sh              baut Image und ISO
image/Containerfile   das System als Container-Image
image/build/steps/    Bauschritte, der Reihe nach
image/packages/       Paketlisten (eine Zeile = ein Paket)
image/system_files/   Dateien, die 1:1 ins System kopiert werden
iso/release.toml      Einstellungen für das Installations-ISO
test/                 automatischer VM-Test
sandbox/setup.sh      richtet die Build-Umgebung ein
```

## Bauen

Gebaut wird nur in der Sandbox: Fedora in WSL2 auf Windows (oder einer Linux-VM).

Einmalig in Windows: unter „Windows-Features aktivieren oder deaktivieren“ die
**Windows-Hypervisor-Plattform** einschalten (für die Test-VM), dann in PowerShell als
Administrator (danach neu starten):

```powershell
wsl --install --no-distribution
wsl --install FedoraLinux-44
```

Dann in Fedora (WSL):

```bash
git clone /mnt/c/Users/<du>/Documents/OS ~/kestrel && cd ~/kestrel
sudo sandbox/setup.sh
sudo ./build.sh iso          # ISO landet in out/
sudo ./build.sh test-iso     # nur für den VM-Test
test/vm-test.sh
```
