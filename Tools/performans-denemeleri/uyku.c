/* SetThreadExecutionState'in macOS güç kilidine dönüşmesini denetler.
 * Kullanım: uyku.exe <saniye>. Her adımda `pmset -g assertions` ile bakılır. */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
    DWORD seconds = argc > 1 ? (DWORD)atoi(argv[1]) : 15;

    printf("1: ES_CONTINUOUS | ES_DISPLAY_REQUIRED\n");
    fflush(stdout);
    SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED);
    Sleep(seconds * 1000);

    printf("2: ES_CONTINUOUS (temizlendi)\n");
    fflush(stdout);
    SetThreadExecutionState(ES_CONTINUOUS);
    Sleep(seconds * 1000);

    printf("3: çıkış\n");
    return 0;
}
