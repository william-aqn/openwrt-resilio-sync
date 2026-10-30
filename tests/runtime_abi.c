/* SPDX-License-Identifier: MIT */
#define _GNU_SOURCE
#include <gnu/libc-version.h>
#include <locale.h>
#include <wchar.h>
#include <netdb.h>
#include <pthread.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void *worker(void *unused)
{
    (void)unused;
    for (;;) pause();
    return NULL;
}

int main(void)
{
    printf("glibc: %s\n", gnu_get_libc_version());
    if (!setlocale(LC_ALL, "C.UTF-8")) return 1;
    wchar_t wc;
    if (mbtowc(&wc, "\xd0\x9f", 2) != 2 || wc != 0x41f) return 2;
    puts("UTF-8: PASS");

    struct addrinfo *addresses;
    int error = getaddrinfo("download-cdn.resilio.com", "443", NULL, &addresses);
    if (error) {
        fprintf(stderr, "DNS: %s\n", gai_strerror(error));
        return 3;
    }
    freeaddrinfo(addresses);
    puts("DNS: PASS");

    pthread_t thread;
    void *result;
    if (pthread_create(&thread, NULL, worker, NULL) ||
        pthread_cancel(thread) || pthread_join(thread, &result)) return 4;
    if (result != PTHREAD_CANCELED) return 5;
    puts("pthread cancellation: PASS");

    FILE *maps = fopen("/proc/self/maps", "r");
    char line[1024];
    int found_libgcc = 0;
    if (!maps) return 6;
    while (fgets(line, sizeof(line), maps)) {
        if (strstr(line, "ld-musl") || strstr(line, "/lib/libc.so\n")) {
            fclose(maps);
            fputs("Unexpected musl mapping in glibc process\n", stderr);
            return 7;
        }
        if (strstr(line, "/lib/libgcc_s.so.1")) found_libgcc = 1;
    }
    fclose(maps);
    if (!found_libgcc) return 8;
    puts("OpenWrt libgcc loaded without musl: PASS");
    return 0;
}
