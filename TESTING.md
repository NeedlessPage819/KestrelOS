# Tests

## Automatic in the VM (`test/vm-test.sh`)

| Check | How |
|---|---|
| ISO installs | unattended installation in QEMU/KVM |
| Secure Boot on | `mokutil --sb-state` in the VM (UEFI with Microsoft keys) |
| Desktop starts | `plasmashell` is running, session is Wayland, screenshot `out/test/vm/desktop.png` |
| Windows program via Wine | self-compiled `winhello.exe`, console and window (`wine-gui.png`) |
| No broken services | `systemctl --failed` is empty |
| Kestrel Dock loads | no errors from the dock widget in the system log |
| Boot screen | Kestrel design active, graphical boot (`rhgb`), pictures `boot-1..3.png` |
| Dark mode | „Kestrel Dunkel“ (Kestrel Dark) can be switched on, screenshot `dark.png` |

## Live USB stick in the VM (`test/live-test.sh`)

Pictures in `out/test/live/`: boot menu and boot screen (`boot-NN.png`), live desktop
(`desktop.png`), installer from the dock (`installer.png`), the same start with Secure Boot
enforced (`secure-NN.png`, `secure-boot.png`). The live system has no SSH, so
the test only looks; I judge the pictures.

## On real hardware (only you can check this)

Test device: Acer Aspire Lite 15 (AL15-45P): Ryzen 7 5825U, Radeon graphics, Realtek RTL8852BE Wi-Fi.
Please tick off each item and write down problems with a short description.

### USB stick and installation
- [ ] Write the ISO to a USB stick with at least 16 GB (for example with Fedora Media Writer or Rufus in „DD-Modus“ (DD mode))
- [ ] Boot from the USB stick **with Secure Boot switched on**: the Kestrel boot menu appears
- [ ] „Kestrel OS starten“ (Start Kestrel OS): the live desktop comes up, Wi-Fi, sound and touchpad already work here
- [ ] In the dock, „Kestrel OS installieren“ (Install Kestrel OS): the installation runs through, without internet
- [ ] Restart without the stick: the setup assistant creates the user account, then the desktop appears

### Daily use
- [ ] Connect to Wi-Fi. Then browse for 30 minutes without dropouts (Realtek chip: please watch this closely)
- [ ] Bluetooth: pair headphones or a mouse
- [ ] Firefox: pages load, a YouTube video in 1080p plays smoothly and with sound
- [ ] Play a local video (for example MP4) in VLC
- [ ] LibreOffice: open a document, save it
- [ ] Printer (if you have one) is found and prints
- [ ] **Standby:** close the lid, wait 5 min, open the lid. Screen, Wi-Fi, sound and touchpad work again
- [ ] Standby 3× in a row
- [ ] Battery: write down the runtime while browsing (Einstellungen → Energieverwaltung, Settings → Power Management)
- [ ] Brightness and volume keys work
- [ ] Touchpad: tap = click, two-finger scrolling, 4-finger swipe (overview / workspace)
- [ ] Meta+Space opens the search (Spotlight)
- [ ] Press the Windows key alone: nothing happens (it should not get in the way in games)
- [ ] Animations feel smooth: opening/closing windows (zoom), minimizing into the dock (Magic Lamp), maximizing
- [ ] Touchpad: 4 fingers up = window overview, 4 fingers sideways = switch workspace
- [ ] Dock and top bar show the blurred background (frosted glass)

### Gaming
- [ ] Steam starts, login works
- [ ] Heroic: log in to the Epic account, install Rocket League
- [ ] Rocket League starts with Proton (in Heroic: install Proton-GE with ProtonUp-Qt and select it)
- [ ] **Rocket League connects online** (Easy Anti-Cheat) and an online match works
- [ ] Show FPS with MangoHud (in Heroic: „MangoHud aktivieren“ (Enable MangoHud)). Write down FPS over 10 minutes, any stutters?
- [ ] In the game (full screen or borderless window) the dock and top bar are not visible
- [ ] The game runs at full screen resolution, not blurry and upscaled
- [ ] A controller (Xbox/PlayStation) is detected in Steam and in Heroic
- [ ] GameMode active (turn it on in Heroic; to check: `gamemoded -s` in the terminal while the game is running)

### Updates and rollback
- [ ] Later, once updates are published: install an update, restart, choose the previous version
      in the boot menu. The old system starts again.
