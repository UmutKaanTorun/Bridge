/*
 * steamwebhelper aracı programı
 *
 * Steam'in tarayıcı sürecini (steamwebhelper_gercek.exe) Chromium'u tek süreçte
 * çalıştıracak bayraklarla başlatır. Wine'ın macOS sürücüsü, Chromium'un ayrı
 * GPU sürecinden başka bir sürecin penceresine çizmesini desteklemediği için
 * Steam penceresi aksi halde siyah kalır.
 *
 * Fikir: github.com/ramiabih/play-windows-steam-on-mac (MIT). Bu dosya ayrı yazıldı.
 * Derleme: x86_64-w64-mingw32-gcc -municode -O2 -s -o steamwebhelper.exe araci.c
 */
#include <windows.h>
#include <stdlib.h>
#include <wchar.h>

#define GERCEK_DOSYA L"steamwebhelper_gercek.exe"
#define EK_BAYRAKLAR L"--disable-gpu --single-process"

/* Komut satırının ilk öğesini (program adını) atlayıp geri kalanını döndürür. */
static const wchar_t *argumanlar(void)
{
    const wchar_t *p = GetCommandLineW();
    int tirnak = 0;
    for (; *p; p++) {
        if (*p == L'"') tirnak = !tirnak;
        else if (*p == L' ' && !tirnak) break;
    }
    while (*p == L' ') p++;
    return p;
}

int wmain(void)
{
    wchar_t gercek[MAX_PATH];
    DWORD n = GetModuleFileNameW(NULL, gercek, MAX_PATH);
    if (!n || n >= MAX_PATH) return 1;
    wchar_t *bolu = wcsrchr(gercek, L'\\');
    if (!bolu || (size_t)(bolu + 1 - gercek) + wcslen(GERCEK_DOSYA) >= MAX_PATH) return 1;
    wcscpy(bolu + 1, GERCEK_DOSYA);

    const wchar_t *arg = argumanlar();
    size_t boy = wcslen(gercek) + wcslen(arg) + wcslen(EK_BAYRAKLAR) + 8;
    wchar_t *satir = calloc(boy, sizeof(wchar_t));
    if (!satir) return 1;
    /* Bayraklar Steam'inkilerden sonra gelir, böylece onları geçersiz kılar. */
    _snwprintf(satir, boy, L"\"%ls\" %ls %ls", gercek, arg, EK_BAYRAKLAR);

    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi;
    if (!CreateProcessW(gercek, satir, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
        free(satir);
        return 1;
    }
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD kod = 1;
    GetExitCodeProcess(pi.hProcess, &kod);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    free(satir);
    return (int)kod;
}
