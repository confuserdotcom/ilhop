// Print the Linux keycodes of every modifier key physically held right now.
// Reads the kernel's key state directly (EVIOCGKEY) across all keyboards, so it
// reflects the real hardware rather than any compositor's idea of it.
#include <fcntl.h>
#include <linux/input.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <stdlib.h>
#include <sys/ioctl.h>

static const int MODS[] = {29, 42, 54, 56, 97, 100, 125, 126};
#define NMODS (int)(sizeof(MODS)/sizeof(MODS[0]))
#define BITS_PER_LONG (8 * (int)sizeof(long))
#define TEST_BIT(nr, addr) (((addr)[(nr)/BITS_PER_LONG] >> ((nr)%BITS_PER_LONG)) & 1)

int main(void) {
    DIR *d = opendir("/dev/input");
    if (!d) return 1;
    int seen[NMODS];
    memset(seen, 0, sizeof(seen));
    struct dirent *e;
    while ((e = readdir(d))) {
        if (strncmp(e->d_name, "event", 5) != 0) continue;
        char path[512];
        snprintf(path, sizeof(path), "/dev/input/%s", e->d_name);
        int fd = open(path, O_RDONLY | O_NONBLOCK);
        if (fd < 0) continue;
        // Skip ydotool's own virtual keyboard: this tool is used to decide what
        // to re-press through ydotool, so counting ydotool's state would make it
        // latch its own synthetic holds forever.
        char nm[256] = {0};
        if (ioctl(fd, EVIOCGNAME(sizeof(nm)), nm) >= 0 && strstr(nm, "ydotool")) {
            close(fd);
            continue;
        }
        unsigned long keys[(KEY_MAX + BITS_PER_LONG) / BITS_PER_LONG];
        memset(keys, 0, sizeof(keys));
        if (ioctl(fd, EVIOCGKEY(sizeof(keys)), keys) >= 0)
            for (int i = 0; i < NMODS; i++)
                if (TEST_BIT(MODS[i], keys)) seen[i] = 1;
        close(fd);
    }
    closedir(d);
    for (int i = 0; i < NMODS; i++) if (seen[i]) printf("%d\n", MODS[i]);
    return 0;
}
