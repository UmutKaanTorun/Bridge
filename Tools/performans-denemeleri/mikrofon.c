/* Mikrofon arabelleği taşınca IAudioCaptureClient::GetBuffer'ın arabelleğin dışını gösterip göstermediğini denetler
 * (motor yaması winecoreaudio-yakalama-tasmasi.patch). Wine'ın Mac ses sürücüsü taşmada okuma konumunu başa
 * sarmıyordu; sonraki GetBuffer arabelleğin sonunu geçen bir adres veriyor, PEAK'in mikrofon iş parçacığı oradan
 * kopyalarken çöküyordu.
 *
 * Kullanım: mikrofon.exe [saniye]. Unity'nin yaptığı gibi 48 kHz, tek kanal, 16 bit ister. Mikrofon izni yoksa
 * macOS sessizlik verir; arabellek hesabı yine aynı işler.
 * İki okuma biçimi denenir: hepsini boşaltan (arada takılmalarla) ve her yoklamada tek parça alan yavaş okuyucu.
 * Çıkış kodu: 0 bütün adresler arabellekte, 1 arabellek dışı adres görüldü, 2 ses açılamadı. */
#define COBJMACROS
#include <windows.h>
#include <initguid.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <stdio.h>
#include <stdlib.h>

static BYTE *base;          /* ilk GetBuffer'ın adresi: okuma konumu 0, yani arabelleğin başı */
static UINT32 buffer_bytes; /* GetBufferSize × blok boyu */
static UINT32 block_align;
static int packets, outside, unreadable;

static void check(BYTE *data, UINT32 frames)
{
    UINT32 bytes = frames * block_align;
    SIZE_T reserved = (buffer_bytes + 0xffff) & ~0xffff;  /* Wine arabelleği 64 KB sınırında ayırır */
    MEMORY_BASIC_INFORMATION info;

    packets++;
    if (!base) { base = data; return; }
    /* Arabelleğin içindeyse ya da ayrı bir geçici arabellekse (sona sarılan parça için) sorun yok. */
    if (data < base || data >= base + reserved || data + bytes <= base + buffer_bytes) return;

    outside++;
    if (VirtualQuery(data + bytes - 1, &info, sizeof(info)) && info.State != MEM_COMMIT) unreadable++;
    if (outside <= 5)
        printf("  arabellek dışı: sondan %ld bayt ileride, %u bayt (%s)\n",
               (long)(data - (base + buffer_bytes)), bytes,
               info.State != MEM_COMMIT ? "kopyalasa çökerdi" : "okunabilir ama başka veri");
}

/* Her yoklamada `drain` doğruysa bütün parçaları, değilse yalnız birini alır; `stall_every` yoklamada bir
 * `stall_ms` bekler (oyundaki takılma). */
static HRESULT run(IAudioCaptureClient *capture, const char *name, DWORD seconds, BOOL drain,
                   DWORD poll_ms, int stall_every, DWORD stall_ms)
{
    DWORD end = GetTickCount() + seconds * 1000;
    int polls = 0, before_outside = outside, before_packets = packets;
    HRESULT hr;

    printf("%s:\n", name);
    while (GetTickCount() < end) {
        UINT32 next = 0;
        if (FAILED(hr = IAudioCaptureClient_GetNextPacketSize(capture, &next))) return hr;
        while (next) {
            BYTE *data; UINT32 frames; DWORD flags;
            if (FAILED(hr = IAudioCaptureClient_GetBuffer(capture, &data, &frames, &flags, NULL, NULL))) return hr;
            if (hr == AUDCLNT_S_BUFFER_EMPTY) break;
            check(data, frames);
            if (FAILED(hr = IAudioCaptureClient_ReleaseBuffer(capture, frames))) return hr;
            if (!drain) break;
            if (FAILED(hr = IAudioCaptureClient_GetNextPacketSize(capture, &next))) return hr;
        }
        Sleep(++polls % stall_every ? poll_ms : stall_ms);
    }
    printf("  %d parça, %d arabellek dışı\n", packets - before_packets, outside - before_outside);
    return S_OK;
}

int main(int argc, char **argv)
{
    DWORD seconds = argc > 1 ? (DWORD)atoi(argv[1]) : 10;
    WAVEFORMATEX fmt = { WAVE_FORMAT_PCM, 1, 48000, 48000 * 2, 2, 16, 0 };
    IMMDeviceEnumerator *enumerator = NULL;
    IMMDevice *device = NULL;
    IAudioClient *client = NULL;
    IAudioCaptureClient *capture = NULL;
    REFERENCE_TIME period, minimum;
    UINT32 frames;
    HRESULT hr;

    CoInitializeEx(NULL, COINIT_MULTITHREADED);
    if (FAILED(hr = CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator,
                                     (void **)&enumerator))
        || FAILED(hr = IMMDeviceEnumerator_GetDefaultAudioEndpoint(enumerator, eCapture, eConsole, &device))
        || FAILED(hr = IMMDevice_Activate(device, &IID_IAudioClient, CLSCTX_ALL, NULL, (void **)&client))
        || FAILED(hr = IAudioClient_Initialize(client, AUDCLNT_SHAREMODE_SHARED, 0, 1000000 /* 100 ms */, 0,
                                               &fmt, NULL))
        || FAILED(hr = IAudioClient_GetBufferSize(client, &frames))
        || FAILED(hr = IAudioClient_GetDevicePeriod(client, &period, &minimum))
        || FAILED(hr = IAudioClient_GetService(client, &IID_IAudioCaptureClient, (void **)&capture))
        || FAILED(hr = IAudioClient_Start(client))) {
        printf("Mikrofon açılamadı: 0x%08lx\n", (unsigned long)hr);
        return 2;
    }
    block_align = fmt.nBlockAlign;
    buffer_bytes = frames * block_align;
    printf("Arabellek %u kare (%u bayt), parça %ld kare\n", frames, buffer_bytes,
           (long)(period * fmt.nSamplesPerSec / 10000000));

    if (FAILED(hr = run(capture, "Hepsini boşaltan okuyucu, 2 sn'de bir 300 ms takılma", seconds, TRUE, 10, 200, 300))
        || FAILED(hr = run(capture, "Yavaş okuyucu (her 15 ms'de tek parça)", seconds, FALSE, 15, 1 << 30, 0))) {
        printf("Okuma hatası: 0x%08lx\n", (unsigned long)hr);
        return 2;
    }

    IAudioClient_Stop(client);
    printf("Toplam %d parça, %d arabellek dışı adres (%d tanesi kopyalanınca çökerdi)\n", packets, outside, unreadable);
    return outside ? 1 : 0;
}
