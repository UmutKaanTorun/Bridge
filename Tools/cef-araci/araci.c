/*
 * CEF yardımcı aracı programı
 *
 * Bir programın kendi sabit argümanlarıyla açtığı Chromium/CEF tarayıcı sürecini
 * (<ad>_gercek.exe) ek bayraklarla başlatır. Köprü'nün `helperProxy` tarif eylemi
 * gerçek dosyayı <ad>_gercek.exe yapıp yerine bu aracıyı koyar (KopruCore/HelperProxy.swift).
 *
 * Örnek: Rockstar Games Launcher, Social Club'ın SocialClubHelper.exe'sini bayrak
 * geçirmeden açıyor. Wine'ın Mac sürücüsünde ve DXMT'de Chromium'un ayrı GPU süreci
 * tarayıcı sürecinin penceresine çizemediği için ("cross-process swapchain not
 * supported") giriş penceresi boş kalıyor; --in-process-gpu GPU'yu tarayıcı sürecine alır.
 *
 * GERCEK_DOSYA ve EK_BAYRAKLAR derlemede verilir (derle.sh). Gerçek dosyanın adı aracının
 * içinde UTF-16 olarak geçer; Köprü aracıyı bu işaretle tanır.
 * Steam'in aynı işi yapan aracısı: Tools/steamwebhelper-araci.
 */
#include <windows.h>
#include <stdlib.h>
#include <wchar.h>

#if !defined(GERCEK_DOSYA) || !defined(EK_BAYRAKLAR)
#error "GERCEK_DOSYA ve EK_BAYRAKLAR derlemede verilmeli (derle.sh)"
#endif

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
    /* Bayraklar programınkilerden sonra gelir, böylece onları geçersiz kılar. */
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
