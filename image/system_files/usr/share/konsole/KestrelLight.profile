# Kestrel OS terminal profile for light mode (DECISIONS.md D27). Same as KestrelDark.profile
# except for the colours; Konsole picks the one that fits the mode (konsolerc).
[General]
Name=Kestrel Light
Parent=FALLBACK/
# Generous room around the text, like a page with margins (DECISIONS.md D27).
TerminalMargin=20
TerminalCenter=false
LocalTabTitleFormat=%d
RemoteTabTitleFormat=%h

[Appearance]
ColorScheme=KestrelLight
Font=JetBrains Mono,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
LineSpacing=3
UseFontLineChararacters=true
# Bold text is drawn bold (the prompt shows the folder name in bold).
BoldIntense=true

[Cursor Options]
# A thin bar in the Kestrel accent colour (#5b6cf0).
CursorShape=1
CustomCursorColor=91,108,240
UseCustomCursorColor=true

[Scrolling]
# No scroll bar; the mouse wheel and Shift+PgUp still scroll.
ScrollBarPosition=2
HistorySize=10000

[Terminal Features]
BellMode=3
UrlHintsModifiers=67108864
