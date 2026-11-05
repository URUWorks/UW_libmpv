// Loads every dylib of the folder, checks that libmpv exports the functions
// that UW_MPVPlayer uses and plays the given files to the end (vo/ao null).
// Usage: dltest <Frameworks folder> <functions.txt> <media>...
#include <dirent.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct { int event_id; int error; uint64_t reply_userdata; void *data; } mpv_event;
typedef struct { int reason; int error; } mpv_event_end_file;
enum { EV_SHUTDOWN = 1, EV_END_FILE = 7, EV_FILE_LOADED = 8 };

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: dltest <dir> <functions.txt> <media>...\n"); return 2; }
    const char *dir = argv[1];
    char path[2048], line[256];
    int fails = 0;

    DIR *d = opendir(dir);
    struct dirent *e;
    while ((e = readdir(d))) {
        if (!strstr(e->d_name, ".dylib")) continue;
        snprintf(path, sizeof path, "%s/%s", dir, e->d_name);
        void *h = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        printf("%-28s %s\n", e->d_name, h ? "OK" : dlerror());
        if (!h) fails++;
    }
    closedir(d);

    snprintf(path, sizeof path, "%s/libmpv.2.dylib", dir);
    void *m = dlopen(path, RTLD_NOW);
    if (!m) { printf("libmpv: %s\n", dlerror()); return 1; }

    FILE *fl = fopen(argv[2], "r");
    int nf = 0;
    while (fl && fgets(line, sizeof line, fl)) {
        line[strcspn(line, "\r\n")] = 0;
        if (!*line) continue;
        nf++;
        if (!dlsym(m, line)) { printf("MISSING %s\n", line); fails++; }
    }
    if (fl) fclose(fl); else { printf("no %s\n", argv[2]); fails++; }
    printf("functions checked: %d\n", nf);

    unsigned long (*api)(void) = dlsym(m, "mpv_client_api_version");
    void *(*create)(void) = dlsym(m, "mpv_create");
    int (*setopt)(void *, const char *, const char *) = dlsym(m, "mpv_set_option_string");
    int (*init)(void *) = dlsym(m, "mpv_initialize");
    int (*command)(void *, const char **) = dlsym(m, "mpv_command");
    mpv_event *(*wait)(void *, double) = dlsym(m, "mpv_wait_event");
    char *(*getstr)(void *, const char *) = dlsym(m, "mpv_get_property_string");
    void (*mfree)(void *) = dlsym(m, "mpv_free");
    void (*destroy)(void *) = dlsym(m, "mpv_terminate_destroy");

    unsigned long v = api();
    printf("mpv client API: %lu.%lu\n", v >> 16, v & 0xffff);
    if ((v >> 16) != 2) { printf("not libmpv 2\n"); fails++; }

    for (int i = 3; i < argc; i++) {
        void *ctx = create();
        setopt(ctx, "vo", "null");
        setopt(ctx, "ao", "null");
        setopt(ctx, "terminal", "no");
        if (init(ctx) < 0) { printf("mpv_initialize failed\n"); fails++; destroy(ctx); continue; }
        if (i == 3) {
            const char *props[] = {"mpv-version", "ffmpeg-version", NULL};
            for (int p = 0; props[p]; p++) {
                char *s = getstr(ctx, props[p]);
                printf("%s: %s\n", props[p], s ? s : "(null)");
                mfree(s);
            }
        }
        const char *cmd[] = {"loadfile", argv[i], NULL};
        command(ctx, cmd);
        int loaded = 0, ok = 0;
        for (;;) {
            mpv_event *ev = wait(ctx, 30.0);
            if (ev->event_id == 0) { printf("%s: timeout\n", argv[i]); break; }
            if (ev->event_id == EV_FILE_LOADED) {
                loaded = 1;
                char *dur = getstr(ctx, "duration");
                printf("%s: loaded, duration %s\n", argv[i], dur ? dur : "?");
                mfree(dur);
            }
            if (ev->event_id == EV_END_FILE) {
                mpv_event_end_file *ef = ev->data;
                ok = loaded && ef->reason == 0; // MPV_END_FILE_REASON_EOF
                printf("%s: end, reason %d error %d\n", argv[i], ef->reason, ef->error);
                break;
            }
            if (ev->event_id == EV_SHUTDOWN) break;
        }
        if (!ok) { printf("%s: PLAYBACK FAILED\n", argv[i]); fails++; }
        destroy(ctx);
    }

    printf(fails ? "FAILURES: %d\n" : "ALL OK\n", fails);
    return fails != 0;
}
