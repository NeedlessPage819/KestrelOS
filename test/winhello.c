/* Minimal Windows test program for the Wine check in vm-test.sh.
 * Built with mingw-w64 so the test needs no binaries from the internet. */
#include <stdio.h>
#include <string.h>
#include <windows.h>

int main(int argc, char **argv)
{
    char dir[MAX_PATH];

    GetWindowsDirectoryA(dir, sizeof dir);
    printf("KESTREL-WINE-OK windows-dir=%s\n", dir);

    if (argc > 1 && strcmp(argv[1], "--gui") == 0)
        MessageBoxA(NULL, "Hallo von Windows (via Wine)!", "Kestrel Wine-Test", MB_OK);

    return 0;
}
