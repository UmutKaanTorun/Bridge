/* Rosetta'nın AVX bildirimini Wine içinden denetler.
 * Satır 1: işlemcinin CPUID'si (Rosetta ROSETTA_ADVERTISE_AVX=1 ile bildirir).
 * Satır 2: Wine'ın Windows programlarına söylediği (IsProcessorFeaturePresent). */
#include <windows.h>
#include <stdio.h>
#include <cpuid.h>

#ifndef PF_AVX_INSTRUCTIONS_AVAILABLE
#define PF_AVX_INSTRUCTIONS_AVAILABLE 39
#endif
#ifndef PF_AVX2_INSTRUCTIONS_AVAILABLE
#define PF_AVX2_INSTRUCTIONS_AVAILABLE 40
#endif

int main(void)
{
    unsigned a, b, c, d;
    int avx = 0, avx2 = 0;

    if (__get_cpuid(1, &a, &b, &c, &d)) avx = (c >> 28) & 1;
    if (__get_cpuid_count(7, 0, &a, &b, &c, &d)) avx2 = (b >> 5) & 1;
    printf("CPUID AVX=%d AVX2=%d\n", avx, avx2);
    printf("IsProcessorFeaturePresent AVX=%d AVX2=%d\n",
           IsProcessorFeaturePresent(PF_AVX_INSTRUCTIONS_AVAILABLE) ? 1 : 0,
           IsProcessorFeaturePresent(PF_AVX2_INSTRUCTIONS_AVAILABLE) ? 1 : 0);
    return 0;
}
