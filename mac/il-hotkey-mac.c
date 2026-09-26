// ALT+C on a Mac without AeroSpace: registers the key system-wide through the
// Carbon hotkey API, which needs no Accessibility permission, and runs
// il-jump-mac on every press. Run by the ilhop.hotkey launchd agent.
//
//   cc -O2 -o il-hotkey-mac il-hotkey-mac.c -framework Carbon
#include <Carbon/Carbon.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>

extern char **environ;
static char jump[1024];

static OSStatus on_hotkey(EventHandlerCallRef next, EventRef event, void *data)
{
    pid_t pid;
    char *argv[] = { jump, NULL };
    if (posix_spawn(&pid, jump, NULL, NULL, argv, environ) != 0)
        perror(jump);
    return noErr;
}

int main(void)
{
    const char *home = getenv("HOME");
    snprintf(jump, sizeof jump, "%s/.local/bin/il-jump-mac", home ? home : "");
    signal(SIGCHLD, SIG_IGN); // never wait for il-jump-mac; let the kernel reap it

    EventTypeSpec pressed = { kEventClassKeyboard, kEventHotKeyPressed };
    InstallApplicationEventHandler(&on_hotkey, 1, &pressed, NULL, NULL);

    EventHotKeyID id = { 'ilhp', 1 };
    EventHotKeyRef ref;
    if (RegisterEventHotKey(kVK_ANSI_C, optionKey, id, GetApplicationEventTarget(), 0, &ref) != noErr) {
        fprintf(stderr, "il-hotkey-mac: ALT+C is taken by another app\n");
        return 1;
    }
    RunCurrentEventLoop(kEventDurationForever);
    return 0;
}
