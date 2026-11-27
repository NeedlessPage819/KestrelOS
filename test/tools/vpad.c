/* Virtual game controller for the VM tests (DECISIONS.md D35). Creates an Xbox 360-style pad
   through /dev/uinput and plays a list of steps given as arguments:
     w<ms>        wait
     a b x y lb rb start select guide   press and release that button
     up down left right                 press the D-pad (hat) in that direction and let go
     rs<x>,<y>    hold the right stick at x,y (-32767..32767) for 600 ms
     ls<x>,<y>    the same with the left stick
   Build: gcc -O2 -o vpad vpad.c */
#include <fcntl.h>
#include <linux/uinput.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int fd;
static void emit(int type, int code, int value) {
    struct input_event ev = {0};
    ev.type = type; ev.code = code; ev.value = value;
    if (write(fd, &ev, sizeof ev) != sizeof ev) { perror("write"); exit(1); }
}
static void syn(void) { emit(EV_SYN, SYN_REPORT, 0); }
static void absinfo(int code, int min, int max) {
    struct uinput_abs_setup a = {0};
    a.code = code; a.absinfo.minimum = min; a.absinfo.maximum = max;
    if (code != ABS_HAT0X && code != ABS_HAT0Y && code != ABS_Z && code != ABS_RZ) { a.absinfo.flat = 128; a.absinfo.fuzz = 16; }
    ioctl(fd, UI_SET_ABSBIT, code);
    if (ioctl(fd, UI_ABS_SETUP, &a) < 0) { perror("UI_ABS_SETUP"); exit(1); }
}
static void press(int code) { emit(EV_KEY, code, 1); syn(); usleep(120000); emit(EV_KEY, code, 0); syn(); }
static void hat(int code, int v) { emit(EV_ABS, code, v); syn(); usleep(120000); emit(EV_ABS, code, 0); syn(); }

int main(int argc, char **argv) {
    fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) { perror("/dev/uinput"); return 1; }
    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_EVBIT, EV_ABS);
    const int keys[] = {BTN_SOUTH, BTN_EAST, BTN_NORTH, BTN_WEST, BTN_TL, BTN_TR, BTN_SELECT,
                        BTN_START, BTN_MODE, BTN_THUMBL, BTN_THUMBR};
    for (unsigned i = 0; i < sizeof keys / sizeof *keys; i++) ioctl(fd, UI_SET_KEYBIT, keys[i]);
    absinfo(ABS_X, -32768, 32767); absinfo(ABS_Y, -32768, 32767);
    absinfo(ABS_RX, -32768, 32767); absinfo(ABS_RY, -32768, 32767);
    absinfo(ABS_Z, 0, 255); absinfo(ABS_RZ, 0, 255);
    absinfo(ABS_HAT0X, -1, 1); absinfo(ABS_HAT0Y, -1, 1);
    struct uinput_setup us = {0};
    us.id.bustype = BUS_USB; us.id.vendor = 0x045e; us.id.product = 0x028e; us.id.version = 0x110;
    strcpy(us.name, "Microsoft X-Box 360 pad");
    if (ioctl(fd, UI_DEV_SETUP, &us) < 0 || ioctl(fd, UI_DEV_CREATE) < 0) { perror("create"); return 1; }
    for (int i = 1; i < argc; i++) {
        const char *s = argv[i];
        if (s[0] == 'w') usleep(atoi(s + 1) * 1000);
        else if (!strcmp(s, "a")) press(BTN_SOUTH);
        else if (!strcmp(s, "b")) press(BTN_EAST);
        else if (!strcmp(s, "x")) press(BTN_WEST);
        else if (!strcmp(s, "y")) press(BTN_NORTH);
        else if (!strcmp(s, "lb")) press(BTN_TL);
        else if (!strcmp(s, "rb")) press(BTN_TR);
        else if (!strcmp(s, "start")) press(BTN_START);
        else if (!strcmp(s, "select")) press(BTN_SELECT);
        else if (!strcmp(s, "guide")) press(BTN_MODE);
        else if (!strcmp(s, "up")) hat(ABS_HAT0Y, -1);
        else if (!strcmp(s, "down")) hat(ABS_HAT0Y, 1);
        else if (!strcmp(s, "left")) hat(ABS_HAT0X, -1);
        else if (!strcmp(s, "right")) hat(ABS_HAT0X, 1);
        else if (!strncmp(s, "rs", 2) || !strncmp(s, "ls", 2)) {
            const int ax = s[0] == 'r' ? ABS_RX : ABS_X, ay = s[0] == 'r' ? ABS_RY : ABS_Y;
            int x = 0, y = 0; sscanf(s + 2, "%d,%d", &x, &y);
            for (int t = 0; t < 30; t++) { emit(EV_ABS, ax, x); emit(EV_ABS, ay, y); syn(); usleep(20000); }
            emit(EV_ABS, ax, 0); emit(EV_ABS, ay, 0); syn();
        } else { fprintf(stderr, "unknown step %s\n", s); return 2; }
        usleep(150000);
        fprintf(stderr, "step %s\n", s);
    }
    ioctl(fd, UI_DEV_DESTROY);
    return 0;
}
