#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

extern long tokenize_entry(char *buffer);

uint64_t token_ptrs[512];

static void trim_newlines(char *buf, size_t len) {
    for (size_t i = 0; i < len; ++i) {
        if (buf[i] == '\0') {
            return;
        }
        if (buf[i] == '\r') {
            buf[i] = '\n';
        }
    }
}

int main(void) {
    char buffer[1024];
    size_t bytes = fread(buffer, 1, sizeof(buffer) - 1, stdin);
    buffer[bytes] = '\0';
    trim_newlines(buffer, bytes);
    long count = tokenize_entry(buffer);
    for (long i = 0; i < count; ++i) {
        const char *tok = (const char *)(uintptr_t)token_ptrs[i];
        if (i != 0) {
            fputc('|', stdout);
        }
        fputs(tok, stdout);
    }
    fputc('\n', stdout);
    return 0;
}
