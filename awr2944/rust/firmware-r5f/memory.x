/* memory.x — AWR2944 R5F MSS memory map (simplified placeholder).
 *
 * The exact memory map is documented in the AWR2944 Technical Reference
 * Manual (SWRU504/SPRUIY8). This placeholder assumes the "single-R5F, split
 * TCM/L2" boot configuration used by the mmW demo. Adjust ORIGIN/LENGTH
 * values if you run dual-core or reserve L3 for the C66x DSS.
 *
 * Sizes below come from the AWR2944 datasheet (SWRS265) "Memory" section.
 * TOTAL MSS TCMA: 32 KB. TOTAL MSS TCMB: 32 KB. MSS L2 RAM: 768 KB.
 * Shared L3 (DSS + MSS + HWA): 1 MB. Flash: 4 MB.
 *
 * DO NOT ship without reconciling these against the TRM you are targeting.
 */

MEMORY
{
    /* Boot ROM / flash (XIP). Start of main firmware image goes here.    */
    FLASH   (rx) : ORIGIN = 0x08000000, LENGTH = 4M

    /* MSS L2 (main RAM for the R5F application).                         */
    L2_RAM  (rwx): ORIGIN = 0x10200000, LENGTH = 768K

    /* Tightly coupled memory for fast paths (ISRs, DSP kernels).         */
    TCMA    (rwx): ORIGIN = 0x00000000, LENGTH = 32K
    TCMB    (rwx): ORIGIN = 0x00080000, LENGTH = 32K
}

REGION_ALIAS("REGION_TEXT",  FLASH);
REGION_ALIAS("REGION_RODATA",FLASH);
REGION_ALIAS("REGION_DATA",  L2_RAM);
REGION_ALIAS("REGION_BSS",   L2_RAM);
REGION_ALIAS("REGION_HEAP",  L2_RAM);
REGION_ALIAS("REGION_STACK", L2_RAM);
