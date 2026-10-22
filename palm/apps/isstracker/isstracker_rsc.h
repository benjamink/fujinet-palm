/* palm/apps/isstracker/isstracker_rsc.h -- resource IDs, shared by
 * isstracker.c and isstracker.rcp. */

#define MapBitmap            1020  /* top-level BITMAP resource (map.bmp), NOT inside any FORM -- draw it manually with DmGetResource(bitmapRsc, MapBitmap) + WinDrawBitmap */
#define MapColorBitmap       1021  /* 8-bit color map (map8.bmp, from bluemarble.png by mkmaps.py), same layout; only loaded on OS 3.5+ color screens */
#define MapGrayBitmap        1022  /* 2-bit 4-gray map (map2.bmp, from bluemarble.png by mkmaps.py), same layout; loaded on grayscale screens */

#define MainForm             1000
#define RefreshButton        1010
#define CrewButton           1011

#define CrewForm             2000
#define CrewField            2010
#define CrewScrollBar        2011
#define CrewDoneButton       2012

#define GeneralAlert         9000
#define InfoAlert            9001
