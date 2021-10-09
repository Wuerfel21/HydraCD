
/*
BMP2SPIN.CPP - Converts bitmaps in 8-24 bit color into spin tile code plus palettes

Author: Andre' Lamothe
Last Modified: 7.17.06

Description:  This program us used to convert a set of bitmap tiles that are typically
16x16 into 4 color SPIN code that are compatible with the HEL version 4.0 tile/sprite
engine, the program has to take in the tile bitmaps, convert to 24-bit color first
then extract the bitmap(s), perform a histogram on the colors used, then select
the 4 most predominant colors from each tile, then map the colors to the nearest match
in the hydra color map (based on the hardware's output), then finally output SPIN
statements that define the tiles plus masks (to support sprites), finally the palette
table itself that each tile refers to for its coloring. This is a very nastly program
and not pretty, like all tools its a "work in progress" and coding on the fly with
complete disregard to anything :), the idea is to get it done and make it work. In other
words its a "travesty" of coding which is typical of tools since in most cases they start
out as a few lines of main() console code, then you add functions, then you copy things, etc.
so the point is don't worry about messy tools, no one is going to look at the code, they 
just need to work!

The book gives specific examples of using the tool, here is its formal usage though
much of the funtionality is not supported though for example, currently the tool only 
works for 16x16 pixel bitmaps, but the command line allows you to give it other sizes
this will cause errors etc.

Usage BMP2SPIN.exe inputfile [flags] > outputfile");
flags = -B -TW[1...255] -TH[1..255] -W[1..256] -H[1..256] - C[1..256] -XYx,y -M -FX -FY -V -I -P[0|1] -?");

-B    = Enable 1 pixel border for templated bitmaps, default no border.");
-TWxx = Width of tile set on x-axis, default = 1.");
-THxx = Height of tile set on y-axis, default = 1.");
-Wxx  = Width of tile, default = 16 pixels.");
-Hxx  = Height of tile, default = 16 pixels.");
-Cxx  = Total count of tiles to be converted, if omitted assumed to be tw*th.");
-XYxx,yy = Coordinate of single tile to pull from bitmap, upper left (0,0) overrides -Cxx.");
-M    = Enables mask write as well after each tile.");
-FX   = Flips the output bitmap's on the X axis (needed for hel engine 4.0).");
-FY   = Flips the output bitmap on the Y axis.");
-Px   = Selects the color matching palette 0 or 1, 0 is default, 1 skews color hue 15 degrees approximately.
-I    = Enables interactive mode.");
-V    = Verbose flag.");
-?    = Prints help.");

*/


// INCLUDES /////////////////////////////////////////////////////////////

#define WIN32_LEAN_AND_MEAN
#define INITGUID

#include <windows.h>   // include important windows stuff
#include <windowsx.h>
#include <mmsystem.h>
#include <conio.h>
#include <stdlib.h>
#include <malloc.h>
#include <memory.h>
#include <string.h>
#include <stdarg.h>
#include <stdio.h>
#include <math.h>
#include <io.h>
#include <fcntl.h>
#include <sys/timeb.h>
#include <time.h>

// DEFINE ///////////////////////////////////////////////////////////////

// directdraw pixel format defines, used to help
// bitmap loader put data in proper format
#define DD_PIXEL_FORMAT8        8
#define DD_PIXEL_FORMAT555      15
#define DD_PIXEL_FORMAT565      16
#define DD_PIXEL_FORMAT888      24
#define DD_PIXEL_FORMATALPHA888 32

#define MAX_COLORS_PALETTE  256

// bitmap defines
#define BITMAP_ID            0x4D42 // universal id for a bitmap

// TYPES ////////////////////////////////////////////////////////////////
// basic unsigned types
typedef unsigned short USHORT;
typedef unsigned short WORD;
typedef unsigned char  UCHAR;
typedef unsigned char  BYTE;
typedef unsigned int   QUAD;
typedef unsigned int   UINT;

// container structure for bitmaps .BMP file
typedef struct BITMAP_FILE_TAG
        {
        BITMAPFILEHEADER bitmapfileheader;  // this contains the bitmapfile header
        BITMAPINFOHEADER bitmapinfoheader;  // this is all the info including the palette
        PALETTEENTRY     palette[256];      // we will store the palette here
        UCHAR            *buffer;           // this is a pointer to the data

        } BITMAP_FILE, *BITMAP_FILE_PTR;

// the simple bitmap image
typedef struct BITMAP_IMAGE_TYP
        {
        int state;          // state of bitmap
        int attr;           // attributes of bitmap
        int x,y;            // position of bitmap
        int width, height;  // size of bitmap
        int num_bytes;      // total bytes of bitmap
        int bpp;            // bits per pixel
        UCHAR *buffer;      // pixels of bitmap

        } BITMAP_IMAGE, *BITMAP_IMAGE_PTR;

// structure to hold hydra palette entry in a couple formats to help color analysis algorithm, basically just a 4-tuple named array
typedef struct HYDRA_PALETTE_ENTRY_TYP
    {
    int colors[4];
    } HYDRA_PALETTE_ENTRY, *HYDRA_PALETTE_ENTRY_PTR;


#pragma pack(1) // this is needed so that word alignment doesn't bloat the data structure, since it needs to be EXACTLY 18 bytes long!
// TGA header
typedef struct TGA_HEADER_TYP
{
    BYTE identsize;          // size of ID field that follows 18 byte header (0 usually)
    BYTE colourmaptype;      // type of colour map 0=none, 1=has palette
    BYTE imagetype;          // type of image 0=none,1=indexed,2=rgb,3=grey,+8=rle packed

    short colourmapstart;     // first colour map entry in palette
    short colourmaplength;    // number of colours in palette
    BYTE colourmapbits;      // number of bits per palette entry 15,16,24,32

    short xstart;             // image x origin
    short ystart;             // image y origin
    short width;              // image width in pixels
    short height;             // image height in pixels
    BYTE bits;               // image bits per pixel 8,16,24,32
    BYTE descriptor;         // image descriptor bits (vh flip bits)
    
    // pixel data follows header....
    
} TGA_HEADER, *TGA_HEADER_PTR; 
#pragma pack()


/*
--------------------------------------------------------------------------------
DATA TYPE 2:  Unmapped RGB images.                                             |
_______________________________________________________________________________|
| Offset | Length |                     Description                            |
|--------|--------|------------------------------------------------------------|
|--------|--------|------------------------------------------------------------|
|    0   |     1  |  Number of Characters in Identification Field.             |
|        |        |                                                            |
|        |        |  This field is a one-byte unsigned integer, specifying     |
|        |        |  the length of the Image Identification Field.  Its value  |
|        |        |  is 0 to 255.  A value of 0 means that no Image            |
|        |        |  Identification Field is included.                         |
|        |        |                                                            |
|--------|--------|------------------------------------------------------------|
|    1   |     1  |  Color Map Type.                                           |
|        |        |                                                            |
|        |        |  This field contains either 0 or 1.  0 means no color map  |
|        |        |  is included.  1 means a color map is included, but since  |
|        |        |  this is an unmapped image it is usually ignored.  TIPS    |
|        |        |  ( a Targa paint system ) will set the border color        |
|        |        |  the first map color if it is present.                     |
|        |        |                                                            |
|--------|--------|------------------------------------------------------------|
|    2   |     1  |  Image Type Code.                                          |
|        |        |                                                            |
|        |        |  This field will always contain a binary 2.                |
|        |        |  ( That's what makes it Data Type 2 ).                     |
|        |        |                                                            |
|--------|--------|------------------------------------------------------------|
|    3   |     5  |  Color Map Specification.                                  |
|        |        |                                                            |
|        |        |  Ignored if Color Map Type is 0; otherwise, interpreted    |
|        |        |  as follows:                                               |
|        |        |                                                            |
|    3   |     2  |  Color Map Origin.                                         |
|        |        |  Integer ( lo-hi ) index of first color map entry.         |
|        |        |                                                            |
|    5   |     2  |  Color Map Length.                                         |
|        |        |  Integer ( lo-hi ) count of color map entries.             |
|        |        |                                                            |
|    7   |     1  |  Color Map Entry Size.                                     |
|        |        |  Number of bits in color map entry.  16 for the Targa 16,  |
|        |        |  24 for the Targa 24, 32 for the Targa 32.                 |
|        |        |                                                            |
|--------|--------|------------------------------------------------------------|
|    8   |    10  |  Image Specification.                                      |
|        |        |                                                            |
|    8   |     2  |  X Origin of Image.                                        |
|        |        |  Integer ( lo-hi ) X coordinate of the lower left corner   |
|        |        |  of the image.                                             |
|        |        |                                                            |
|   10   |     2  |  Y Origin of Image.                                        |
|        |        |  Integer ( lo-hi ) Y coordinate of the lower left corner   |
|        |        |  of the image.                                             |
|        |        |                                                            |
|   12   |     2  |  Width of Image.                                           |
|        |        |  Integer ( lo-hi ) width of the image in pixels.           |
|        |        |                                                            |
|   14   |     2  |  Height of Image.                                          |
|        |        |  Integer ( lo-hi ) height of the image in pixels.          |
|        |        |                                                            |
|   16   |     1  |  Image Pixel Size.                                         |
|        |        |  Number of bits in a pixel.  This is 16 for Targa 16,      |
|        |        |  24 for Targa 24, and .... well, you get the idea.         |
|        |        |                                                            |
|   17   |     1  |  Image Descriptor Byte.                                    |
|        |        |  Bits 3-0 - number of attribute bits associated with each  |
|        |        |             pixel.  For the Targa 16, this would be 0 or   |
|        |        |             1.  For the Targa 24, it should be 0.  For     |
|        |        |             Targa 32, it should be 8.                      |
|        |        |  Bit 4    - reserved.  Must be set to 0.                   |
|        |        |  Bit 5    - screen origin bit.                             |
|        |        |             0 = Origin in lower left-hand corner.          |
|        |        |             1 = Origin in upper left-hand corner.          |
|        |        |             Must be 0 for Truevision images.               |
|        |        |  Bits 7-6 - Data storage interleaving flag.                |
|        |        |             00 = non-interleaved.                          |
|        |        |             01 = two-way (even/odd) interleaving.          |
|        |        |             10 = four way interleaving.                    |
|        |        |             11 = reserved.                                 |
|        |        |                                                            |
|--------|--------|------------------------------------------------------------|
|   18   | varies |  Image Identification Field.                               |
|        |        |  Contains a free-form identification field of the length   |
|        |        |  specified in byte 1 of the image record.  It's usually    |
|        |        |  omitted ( length in byte 1 = 0 ), but can be up to 255    |
|        |        |  characters.  If more identification information is        |
|        |        |  required, it can be stored after the image data.          |
|        |        |                                                            |
|--------|--------|------------------------------------------------------------|
| varies | varies |  Color map data.                                           |
|        |        |                                                            |
|        |        |  If the Color Map Type is 0, this field doesn't exist.     |
|        |        |  Otherwise, just read past it to get to the image.         |
|        |        |  The Color Map Specification describes the size of each    |
|        |        |  entry, and the number of entries you'll have to skip.     |
|        |        |  Each color map entry is 2, 3, or 4 bytes.                 |
|        |        |                                                            |
|--------|--------|------------------------------------------------------------|
| varies | varies |  Image Data Field.                                         |
|        |        |                                                            |
|        |        |  This field specifies (width) x (height) pixels.  Each     |
|        |        |  pixel specifies an RGB color value, which is stored as    |
|        |        |  an integral number of bytes.                              |
|        |        |                                                            |
|        |        |  The 2 byte entry is broken down as follows:               |
|        |        |  ARRRRRGG GGGBBBBB, where each letter represents a bit.    |
|        |        |  But, because of the lo-hi storage order, the first byte   |
|        |        |  coming from the file will actually be GGGBBBBB, and the   |
|        |        |  second will be ARRRRRGG. "A" represents an attribute bit. |
|        |        |                                                            |
|        |        |  The 3 byte entry contains 1 byte each of blue, green,     |
|        |        |  and red.                                                  |
|        |        |                                                            |
|        |        |  The 4 byte entry contains 1 byte each of blue, green,     |
|        |        |  red, and attribute.  For faster speed (because of the     |
|        |        |  hardware of the Targa board itself), Targa 24 images are  |
|        |        |  sometimes stored as Targa 32 images.                      |
|        |        |                                                            |
--------------------------------------------------------------------------------
*/


// this data structure holds the mappy map format
typedef struct MAPPY_MAP_TAG
    {
    int flags;     // general flags field
    int width;     // width of map in tiles
    int height;    // height of map in tiles
    UCHAR *buffer; // pointer to map data, single stream of bytes

} MAPPY_MAP, *MAPPY_MAP_PTR;

// MACROS ///////////////////////////////////////////////////////////////

// this builds a 16 bit color value in 5.5.5 format (1-bit alpha mode)
#define _RGB16BIT555(r,g,b) ((b & 31) + ((g & 31) << 5) + ((r & 31) << 10))

// this builds a 16 bit color value in 5.6.5 format (green dominate mode)
#define _RGB16BIT565(r,g,b) ((b & 31) + ((g & 63) << 5) + ((r & 31) << 11))

// this builds a 24 bit color value in 8.8.8 format
#define _RGB24BIT(a,r,g,b) ((b) + ((g) << 8) + ((r) << 16) )

// this builds a 32 bit color value in A.8.8.8 format (8-bit alpha mode)
#define _RGB32BIT(a,r,g,b) ((b) + ((g) << 8) + ((r) << 16) + ((a) << 24))

// bit manipulation macros
#define SET_BIT(word,bit_flag)   ((word)=((word) | (bit_flag)))
#define RESET_BIT(word,bit_flag) ((word)=((word) & (~bit_flag)))

// used to compute the min and max of two expresions
#define MIN(a, b)  (((a) < (b)) ? (a) : (b))
#define MAX(a, b)  (((a) > (b)) ? (a) : (b))
#define SIGN(a) ( ((a) > 0) ? (1) : (-1) )

// used for swapping algorithm
#define SWAP(a,b,t) {t=a; a=b; b=t;}

// some math macros
#define DEG_TO_RAD(ang) ((ang)*PI/180.0)
#define RAD_TO_DEG(rads) ((rads)*180.0/PI)

#define RAND_RANGE(x,y) ( (x) + (rand()%((y)-(x)+1)))

// PROTOTYPES ///////////////////////////////////////////////////////////

int Load_Bitmap_File(BITMAP_FILE_PTR bitmap, char *filename, int flip=1);
int Load_Bitmap_File2(BITMAP_FILE_PTR bitmap, char *filename, int flip=1);
int Flip_Bitmap(UCHAR *image, int bytes_per_line, int height);
int Extract_Bitmap(int tile_x, int tile_y, int width, int height, int step_x, int step_y, BYTE *bitmap_buffer, BITMAP_FILE_PTR bitmap);
int Build_Palette_From_Bitmap(int tx, int ty, int width, int height, BYTE *bitmap_buffer, int output_bitmap_flag);

// EXTERNALS ////////////////////////////////////////////////////////////


// GLOBALS //////////////////////////////////////////////////////////////

int cmd_B  = 0;  // Enable 1 pixel border templated bitmaps, default no border.
int cmd_TW = 1;  // width of tile set on x-axis, default = 1.
int cmd_TH = 1;  // height of tile set on y-axis, default = 1.
int cmd_W  = 16; // width of tile, default = 16.
int cmd_H  = 16; // height of tile, default = 16.
int cmd_C  = 1;  // total count of tiles to be converted, if omitted assumed to bee tw*th
int cmd_XY = 0;  // flags if x,y should be used for single bitmap extraction
int cmd_X  = 0;  // coordinate of single tile to pull from bitmap, overrides -Cxx
int cmd_Y  = 0; 
int cmd_M  = 0; // Enables mask write as well after each tile
int cmd_FX = 0; // Flips the output bitmap's on the X axis (needed for hel engine 4.0)
int cmd_FY = 0; // Flips the output bitmap on the Y axis
int cmd_I  = 0; // enables interactive mode
int cmd_V  = 0; // verbose flag
int cmd_P  = 0; // palette select, 0 is default

char inputfilename[256]; // input file to converter
char inputfileroot[256]; // input file root without extention

char cstring1[256], cstring2[256]; // working strings
char *cstring_ptr1, *cstring_ptr2; // working string pointers
int cindex1, cindex2; // general search indices

BITMAP_FILE bitmap;                 // a n bit bitmap file
BITMAP_FILE bitmap8bit;             // a 8 bit bitmap file
BITMAP_FILE bitmap16bit;            // a 16 bit bitmap file
BITMAP_FILE bitmap24bit;            // a 24 bit bitmap file

MAPPY_MAP   tile_map;               // working tile map

char		filename[256];			// general filename
char        sbuffer[256];           // working string
int dd_pixel_format = DD_PIXEL_FORMAT565;    // default pixel format

int num_hydra_colors = 86; // number of colors in hydra color map

float r_bias = 0, g_bias = 0, b_bias = 0;
float r_scale = 1.1, g_scale = 0.6, b_scale = 1.1; 

// the Hydra color look up map, use PALETTEENTRY to hold r,g,b and flags field is hydra "color" word

PALETTEENTRY *hydra_color_map = NULL;


// the Hydra color look up map, use PALETTEENTRY to hold r,g,b and flags field is hydra "color" word
PALETTEENTRY hydra_color_map0[256] = 
{
// Grays, black always at index = 0, white always at index = 5

0, 0, 0,        0x02,
56, 56, 56,     0x03,
115, 115, 115,  0x04,    
171, 171, 171,  0x05,
229, 229, 229,  0x06,
255, 255, 255,  0x07,

// LUMA $0A
70, 13, 176,      0x0A,
83, 11, 75,       0x1A,
141, 32, 87,      0x2A,
113, 17,31,       0x3A,
137, 34, 1,       0x4A,
98, 62, 10,       0x5A,
80, 63, 17,       0x6A,
47, 56, 13,       0x7A,
27, 55, 17,       0x8A,
10, 68, 17,       0x9A,
31, 46, 39,       0xAA,
24,38,41,         0xBA,
13,42,60,         0xCA,
26,65,132,        0xDA,
0,0,158,          0xEA,
47,0,128,         0xFA,

// LUMA $0B
117, 21, 189,     0x0B,
153, 20, 137,     0x1B,
201, 46, 124,     0x2B,
202, 30, 54,      0x3B,
218, 54, 1,       0x4B,
154, 98, 15,      0x5B,
145, 119, 32,     0x6B,
109, 130, 27,     0x7B,
62, 128, 40,      0x8B,
21, 164, 40,      0x9B,
86, 133, 113,     0xAB,
81, 125, 136,     0xBB,
32, 106, 153,     0xCB,
42, 108, 218,     0xDB,
1,0,224,          0xEB,
85,0,230,         0xFB,

// LUMA $0C         
194,115,255,      0X0C,
227,75,210,       0X1C,
243,136,190,      0X2C,
245,152,173,      0X3C,
242,140,92,       0X4C,
210,150,62,       0X5C,
208,168,80,       0X6C,
193,219,94,       0X7C,
136,219,79,       0X8C,
42,209,60,        0X9C,
150,204,180,      0XAC,
89,185,207,       0XBC,
45,156,225,       0XCC,
80,146,255,       0XDC,
95,94,255,        0XEC,
150,89,255,       0XFC,

// LUMA $0D       
216,166,255,      0X0D,
255,184,248,      0X1D,
255,189,224,      0X2D,
246,200,210,      0X3D,
255,217,200,      0X4D,
250,216,168,      0X5D,
243,213,149,      0X6D,
231,242,184,      0X7D,
194,254,154,      0X8D,
158,254,167,      0X9D,
192,240,218,      0XAD,
268,235,251,      0XBD,
144,213,255,      0XCD,
143,186,255,      0XDD,
171,172,255,      0XED,
207,279,255,      0XFD,

// LUMA $0E       
241, 219, 255,    0X0E,
255,230,252,      0X1E,
255,224,240,      0X2E,
255,226,234,      0X3E,
255,233,225,      0X4E,
250,233,207,      0X5E,
255,243,216,      0X6E,
251,255,222,      0X7E,
241,255,230,      0X8E,
227,255,230,      0X9E,
224,255,240,      0XAE,
221,244,250,      0XBE,
204,235,255,      0XCE,
210,227,255,      0XDE,
213,212,255,      0XEE,
229,212,255,      0XFE,
};

PALETTEENTRY hydra_color_map1[256] = 
{
// Grays, black always at index = 0, white always at index = 5

0, 0, 0,        0x02,
56, 56, 56,     0x03,
115, 115, 115,  0x04,    
171, 171, 171,  0x05,
229, 229, 229,  0x06,
255, 255, 255,  0x07,

// LUMA $0A set 
87, 108, 255,   0x0A,
139, 107, 255,  0x1A,
182, 98, 255,   0x2A,
226, 70, 180,   0x3A,
231, 58, 45,    0x4A,
211, 49, 33,    0x5A,
174, 44, 25,    0x6A,
102, 46, 18,    0x7A,
30, 85, 31,     0x8A,
18, 122, 44,    0x9A,
27, 141, 51,    0xAA,
23, 142, 51,    0xBA,
30, 137, 157,   0xCA,
45, 129, 254,   0xDA,
70, 125, 255,   0xEA,
73, 115, 255,   0xFA,

// LUMA $0B set
142, 155, 255,  0x0B,
200, 153, 255,  0x1B,
237, 147, 255,  0x2B,
255, 130, 255,  0x3B,
255, 121, 134,  0x4B,
255, 120, 49,   0x5B,
226, 131, 51,   0x6B,
171, 139, 52,   0x7B,
105, 171, 67,   0x8B,
68, 205, 90,    0x9B,
58, 223, 99,    0xAB,
60, 224, 147,   0xBB,
74, 219, 236,   0xCB,
84, 205, 255,   0xDB,
90, 186, 255,   0xEB,
98, 167, 255,   0xFB,

// LUMA $0C set
189, 200, 255,  0X0C,
229, 205, 255,  0X1C,
253, 206, 255,  0X2C,
255, 190, 255,  0X3C,
255, 184, 200,  0X4C,
255, 182, 119,  0X5C,
254, 186, 95,   0X6C,
211, 190, 103,  0X7C,
160, 218, 95,   0X8C,
138, 241, 121,  0X9C,
120, 252, 150,  0XAC,
118, 252, 202,  0XBC,
127, 244, 255,  0XCC,
132, 234, 255,  0XDC,
136, 224, 255,  0XEC,
135, 211, 255,  0XFC,

// LUMA $0D set
221, 234, 255,  0X0D,
243, 239, 255,  0X1D,
248, 242, 255,  0X2D,
255, 231, 255,  0X3D,
255, 221, 236,  0X4D,
255, 217, 184,  0X5D,
255, 214, 162,  0X6D,
244, 212, 148,  0X7D,
203, 249, 121,  0X8D,
181, 255, 159,  0X9D,
119, 251, 151,  0XAD,
176, 255, 236,  0XBD,
185, 252, 255,  0XCD,
197, 244, 255,  0XDD,
188, 241, 255,  0XED,
191, 231, 255,  0XFD,

// LUMA $0E set
235, 242, 255,  0X0E,
248, 247, 252,  0X1E,
249, 249, 250,  0X2E,
250, 250, 250,  0X3E,
255, 244, 247,  0X4E,
255, 237, 214,  0X5E,
255, 237, 160,  0X6E,
255, 233, 138,  0X7E,
220, 254, 143,  0X8E,
204, 255, 182,  0X9E,
200, 255, 219,  0XAE,
203, 255, 246,  0XBE,
227, 247, 251,  0XCE,
225, 246, 252,  0XDE,
215, 245, 255,  0XEE,
211, 241, 255,  0XFE,
};


HYDRA_PALETTE_ENTRY tileset_palettes[256]; // holds up to 256 individual palettes for tile set
int num_tileset_palettes =  0;             // current number of tileset palettes

// FUNCTIONS ////////////////////////////////////////////////////////////

int Extract_Bitmap(int tile_x, int tile_y, // x,y tile location 
                   int width, int height,  // size of tile to extract (should always be 16x16)
                   int step_x, int step_y, // step to move from tile to tile, either 16,16, or 17,17 if there is a pixel border
                   BYTE *bitmap_buffer,    // destination buffer for bitmap data (width*height*3, usually 768 bytes)
                   BITMAP_FILE_PTR bitmap) // pointer to the bitmap structure itself holding pertinent bitmap info
{
// this function extracts a bitmap tile from the large bitmap image

// step 1: locate exact bitmap coordinates to extract from
int xb = (tile_x * step_x) + (step_x-width);
int yb = (tile_y * step_y) + (step_y-height);

// compute starting pixel address to perform copy from
BYTE *source_bitmap_addr = (BYTE *)bitmap->buffer + 3*(xb + yb * bitmap->bitmapinfoheader.biWidth);
BYTE *dest_buffer = bitmap_buffer;

// now copy the pixels from the source to destination
for (int y=0; y < height; y++)
    {
    // copy pixels
    memcpy(dest_buffer, source_bitmap_addr, width*3);

#if 0    
    printf("\ncopying line %d, src_addr = %p, dest_addr = %p\n", y, (void *)source_bitmap_addr, (void *)dest_buffer);
    for (int x=0; x < width*3; x++)
        {
        printf("%d,", source_bitmap_addr[x]);
        dest_buffer [x] = source_bitmap_addr[x];

        } // end for index
    printf("\n");
#endif
 
    // advance pointers
    dest_buffer        += (width*3);
    source_bitmap_addr += (bitmap->bitmapinfoheader.biWidth*3);    
    } // end for y


#if 0
// write TGA file out to confirm image
TGA_HEADER tga;

// open file, if doesn't exist throw error and exit
FILE *fp = fopen("bitmap2.tga", "wb");

// build TGA header
tga.identsize       = 0;   // size of ID field that follows 18 byte header (0 usually)
tga.colourmaptype   = 0;   // type of colour map 0=none, 1=has palette
tga.imagetype       = 2;   // type of image 0=none,1=indexed,2=rgb,3=grey,+8=rle packed

tga.colourmapstart  = 0;    // first colour map entry in palette
tga.colourmaplength = 0;    // number of colours in palette
tga.colourmapbits   = 0;   // number of bits per palette entry 15,16,24,32

tga.xstart          = 0;    // image x origin
tga.ystart          = 0;    // image y origin
tga.width           = bitmap->bitmapinfoheader.biWidth;     // image width in pixels
tga.height          = bitmap->bitmapinfoheader.biHeight;    // image height in pixels
tga.bits            = bitmap->bitmapinfoheader.biBitCount;  // image bits per pixel 8,16,24,32
tga.descriptor      = 0x30; // image descriptor bits (vh flip bits)

 
// write descriptor out
printf("\nWriting TGA header size = %d", sizeof(tga));
fwrite((void *)&tga, sizeof(tga), 1, fp);

printf("\nTGA data size = %d", bitmap->bitmapinfoheader.biSizeImage);
// write the bitmap data out
fwrite((void *)bitmap->buffer, bitmap->bitmapinfoheader.biSizeImage, 1, fp);

// close the file
fclose(fp);

#endif


#if 0
// write TGA file out to confirm image
TGA_HEADER tga;

// build a filename
sprintf(filename,"bitmap_x%d_y%d_w%d_h%d_sx%d_sy%d.tga", tile_x, tile_y, width, height, step_x, step_y);

// open file, if doesn't exist throw error and exit
FILE *fp = fopen(filename, "wb");

// build TGA header
tga.identsize       = 0;    // size of ID field that follows 18 byte header (0 usually)
tga.colourmaptype   = 0;    // type of colour map 0=none, 1=has palette
tga.imagetype       = 2;    // type of image 0=none,1=indexed,2=rgb,3=grey,+8=rle packed

tga.colourmapstart  = 0;    // first colour map entry in palette
tga.colourmaplength = 0;    // number of colours in palette
tga.colourmapbits   = 0;    // number of bits per palette entry 15,16,24,32

tga.xstart          = 0;    // image x origin
tga.ystart          = 0;    // image y origin
tga.width           = width;     // image width in pixels
tga.height          = height;    // image height in pixels
tga.bits            = 24;    // image bits per pixel 8,16,24,32
tga.descriptor      = 0x30;  // image descriptor bits (vh flip bits)

 
// write descriptor out
printf("\nWriting TGA header size = %d", sizeof(tga));
fwrite((void *)&tga, sizeof(tga), 1, fp);

printf("\nTGA data size = %d", width*height*3);
// write the bitmap data out
fwrite((void *)bitmap_buffer, width*height*3, 1, fp);

// close the file
fclose(fp);

#endif


// return success
return(1);


} // end Extract_Bitmap

/////////////////////////////////////////////////////////////////////////

#define DEBUG_BPFM 1

int Build_Palette_From_Bitmap(int tx, int ty,int width, int height, BYTE *bitmap_buffer, int output_bitmap_flag)
{

BYTE spin_conv_bitmap[64*64];  // support bitmaps up to 64x64, but NEVER should they be anything but 16x16 for now
                               // this array is used to convert the bitmap to spin values 2-bit color codes

HYDRA_PALETTE_ENTRY color_histogram[256]; // holds the histogram of colors int the bitmap, supports up to 256 different colors
int num_histogram_colors = 0;             // the number of colors inserted into the histogram

HYDRA_PALETTE_ENTRY match_pal; // the best match color palette constructed, holds indices to map at first
int num_match_pal_colors = 0;  // the number of colors inserted into the match palette
PALETTEENTRY src_col;          // color map compatible palette used to perform searching algorithm

int px, py;                 // indexing variables
BYTE r,g,b;                 // used to extract red, green, blue components of pixel
int index, index2;          // general looping index

// step 1: first scan bitmap and make a histogram of all colors in image including black
for (py = 0; py < height; py++)
    {
    for (px = 0; px < width; px++)
        {
        // extract pixel at (px, py)
        src_col.peBlue  = bitmap_buffer[3*(px + py*width) + 0];
        src_col.peGreen = bitmap_buffer[3*(px + py*width) + 1];
        src_col.peRed   = bitmap_buffer[3*(px + py*width) + 2];
        src_col.peFlags = 0; // not used here, but in master color map hold the actual "chroma|luma" byte value we will need to insert into the palette
        
        int color_found = 0;

        // has color been added to histogram already?
        for (index=0; index < num_histogram_colors; index++)
            {
            // test color histogram for current pixel color
            if ( (color_histogram[index].colors[0] == src_col.peRed) &&
                 (color_histogram[index].colors[1] == src_col.peGreen) &&
                 (color_histogram[index].colors[2] == src_col.peBlue) )
               {
               // increment "weight" of this color
               color_histogram[index].colors[3]++;

               // flag that color has been found
               color_found = 1;

               // exit loop
               break;

               } // end if match

            } // end for index

         // test if color was found, if not, then insert it, and set its count to 1, increment number of colors in histogram
         if (!color_found)
            {
            // insert color at next avaiable spot
            color_histogram[num_histogram_colors].colors[0] = src_col.peRed;
            color_histogram[num_histogram_colors].colors[1] = src_col.peGreen;
            color_histogram[num_histogram_colors].colors[2] = src_col.peBlue;
            // set initial count to 1
            color_histogram[num_histogram_colors].colors[3] = 1;

            // increment number of colors in histogram
            if (++num_histogram_colors > 255)
                num_histogram_colors = 255;

            } // end if
        
        } // end for pixel_x

    } // end for pixel_y

// at this point color histogram is complete!!!
// enable verbose?
if (cmd_V) {
printf("\nNumber of colors in histogram = %d", num_histogram_colors);
}

// enable verbose?
if (cmd_V) {
for (index = 0; index < num_histogram_colors; index++)
    {

    printf("\nColor %d = [%d, %d, %d], occurs %d times", index,
                                                         color_histogram[index].colors[0],
                                                         color_histogram[index].colors[1],
                                                         color_histogram[index].colors[2],
                                                         color_histogram[index].colors[3]);
    } // end for index

printf("\nHistogram construction complete! Analysis histogram now...\n");
}

// ok, now we need to select the 4 highest occuring colors (and always black if its in histogram)
match_pal.colors[0] = -1; 
match_pal.colors[1] = -1; 
match_pal.colors[2] = -1; 
match_pal.colors[3] = -1; 
num_match_pal_colors = 0;

// scan for black first, its always included
for (index=0; index < num_histogram_colors; index++)
    {
    // is this black? Also, used as transparent
    if ((color_histogram[index].colors[0]==0) && (color_histogram[index].colors[1]==0) && (color_histogram[index].colors[2]==0))
        {
        // the match palette has a single color in it, insert the index into color 0, increment number of colors in match palette
        match_pal.colors[0] = index;
        num_match_pal_colors++;            
        // tag black as removed, so its not included in scan, write a -1 to last entry to indicate removed from histogram
        color_histogram[index].colors[3] = -1;

// enable verbose?
if (cmd_V) {
        printf("\nBlack found in histogram, inserting into match palette");
}
        } // end if

    } // end for index


int col_highest_count_index;
int col_highest_count_value;

// now continue finding important colors and add them to the match palette while there are slots left
while( (num_match_pal_colors) < 4 && (num_match_pal_colors < num_histogram_colors) )
    {
    // reset highest count
    col_highest_count_index = -1;
    col_highest_count_value = 0;

    // scan list for highest occuring color
    for (index=0; index < num_histogram_colors; index++)
        {
        // test next color to see if it occurs higher than current max?
        if (color_histogram[index].colors[3] > col_highest_count_value)
           {
           // this new color in histogram occurs more than the previous 
            col_highest_count_value = color_histogram[index].colors[3];
            col_highest_count_index = index;
           } // end if
        } // end for

// enable verbose?
if (cmd_V) {
   printf("\nColor %d = [%d, %d, %d] Freq=%d added to match palette", col_highest_count_index, 
                                                               color_histogram[col_highest_count_index].colors[0],
                                                               color_histogram[col_highest_count_index].colors[1],
                                                               color_histogram[col_highest_count_index].colors[2],
                                                               color_histogram[col_highest_count_index].colors[3]);
    
}

   // at this point, we have highest occuring color in histogram, insert it into match list, then remove it for next pass
   // so it isnt included in search
   match_pal.colors[num_match_pal_colors] = col_highest_count_index;

   // remove color from histogram search
   color_histogram[col_highest_count_index].colors[3] = -1;

   // increment number of colors in match palette
   num_match_pal_colors++;            
   } // end while


// matching palette constrution complete! What a nightmare!

// enable verbose?
if (cmd_V) {
printf("\nPalette analysis and construction complete!");

for (index = 0 ; index < num_match_pal_colors; index++)
    printf("\nColor %d = histogram palette index %d = [%d, %d, %d]",index, match_pal.colors[index],
                                                                    color_histogram[match_pal.colors[index]].colors[0],
                                                                    color_histogram[match_pal.colors[index]].colors[1],
                                                                    color_histogram[match_pal.colors[index]].colors[2]);
}
    
// at this point we have selected top 4 colors that occur the most in the tile bitmap, next we need to map this palette to the actual hydra color map
// itself, then this resulting palette is the FINAL palette for the tile bitmap and we can finally convert the tile bitmap to 2-bit values
// also, if there are less than 4 colors in the matching palette for the tile then we will as a rule add black to entry 0
// start by building final palette with black, grey, grey, white and then we will overwrite it with our match pal information

HYDRA_PALETTE_ENTRY final_palette; // this holds the INDICES to the hydra color map which are the FINAL colors that this tile uses, the each entry has
                                   // 4-fields, RGB, and the propeller color word last (1 byte), thus we will use indices into the color map to maintain
                                   // as much flexibility as possible

int final_pal_num_colors = 0;      // number of colors in final palette inserted thus far

final_palette.colors[0] = 0; // index to black in color table
final_palette.colors[1] = 2; // index to gray in color table
final_palette.colors[2] = 4; // index to gray in color table
final_palette.colors[3] = 5; // index to white in color table

// step 1: test if match palette has black and the number of color in the match palette is less that 4, if so artifically add black to color 0
if ( (num_match_pal_colors < 4) &&  
     (color_histogram[ match_pal.colors[0] ].colors[0]!=0 || 
      color_histogram[ match_pal.colors[0] ].colors[1]!=0 || 
      color_histogram[ match_pal.colors[0] ].colors[2]!=0 ) )
    {
    // update number of final colors by 1, palette index is already inserted into final palette during initialization above
    final_pal_num_colors++;

// enable verbose?
if (cmd_V) {
    printf("\nAdding black to final palette as entry 0");
}
    } // end if

// enable verbose?
if (cmd_V) {
printf("\nfinal palette colors on entry to RGB matching algorithm = %d, num match pal colors = %d", final_pal_num_colors, num_match_pal_colors);
}


int col_dist = 256*256*3;   // used in color matching algorithm to compute distance to color in 3D colorspace
int best_col_match = -1;    // index of best match of color in color matching algorithm

int r_target, g_target, b_target;
int r_test, g_test, b_test;

// now match the colors in the match palette (which refer via index to the histogram RGB values) to the master hydra color map using a 3D RGB
// colorspace matching algorithm, this is an N2 algorithm as written, if we had larger data sets then a more efficient divide and conquer algorithm
// would be needed, but this is ok for small sets and offline processing

// for each color in match palette find the closest match in hydra color map
for (index = 0; index < num_match_pal_colors; index++)
    {
    // reset color distance to max
    col_dist       = 256*256*3;
    best_col_match = -1; 

     // extract target r,g,b that we are trying to match
     r_target = color_histogram[ match_pal.colors[index] ].colors[0];
     g_target = color_histogram[ match_pal.colors[index] ].colors[1];
     b_target = color_histogram[ match_pal.colors[index] ].colors[2];

// enable verbose?
if (cmd_V) {
     printf("\nMatching color index %d = [%d, %d, %d]", index, r_target, g_target, b_target);   
}

    // for each color in hydra color map test if its closer to target color in 3D colorspace
    for (index2 = 0; index2 < num_hydra_colors; index2++)
        {
        // extract test r,g,b we are testing against for match?
        r_test = hydra_color_map[ index2 ].peRed;
        g_test = hydra_color_map[ index2 ].peGreen;
        b_test = hydra_color_map[ index2 ].peBlue;

        // compare test rgb to target rgb and if its closer update best match
        int rgb_dist = (r_target - r_test)*(r_target - r_test) + 
                       (g_target - g_test)*(g_target - g_test) + 
                       (b_target - b_test)*(b_target - b_test);
        
        if (rgb_dist < col_dist)
           {
           // update distance and index 
           col_dist       = rgb_dist; 
           best_col_match = index2;
           } // end if

        } // end for index2
  
    // at this point col_dist and best_col_match are the best matches for the color in question

// enable verbose?
if (cmd_V) {
    printf("\nBest match found at hydra color palette entry %d (e=%d) RGB = [%d, %d, %d] cword=%x",best_col_match, col_dist,
                                                                    hydra_color_map[ best_col_match].peRed,
                                                                    hydra_color_map[ best_col_match].peGreen,        
                                                                    hydra_color_map[ best_col_match].peBlue,
                                                                    hydra_color_map[ best_col_match].peFlags);
}

    // insert the colors into the final palette
    final_palette.colors[final_pal_num_colors] = best_col_match;
    final_pal_num_colors++;
    } // end for index


// enable verbose?
if (cmd_V) {
// print the final palette out for last sanity check

for (index=0; index < 4; index++)
    printf("\nFinal Palette Entry %d -> hydra color map entry %d = [%d, %d, %d] = $%x", index, final_palette.colors[index],
                                                                    hydra_color_map[ final_palette.colors[index] ].peRed,
                                                                    hydra_color_map[ final_palette.colors[index] ].peGreen,        
                                                                    hydra_color_map[ final_palette.colors[index] ].peBlue,
                                                                    hydra_color_map[ final_palette.colors[index] ].peFlags);
}


// save the final palette in the master palette list, so we can print it later and use it as a look up for the tile map functionality
//HYDRA_PALETTE_ENTRY tileset_palettes[256]; // holds up to 256 individual palettes for tile set
//int num_tileset_palettes =  0;             // current number of tileset palettes

tileset_palettes[num_tileset_palettes] = final_palette;
if (++num_tileset_palettes >= 256)
    num_tileset_palettes = 255;

// at this point we have the FINAL palette that the bitmap maps to best, the palette is stored in final_palette as a set of indices into the hydra master
// color map, this gives us the most flexibility, so we can wait till the very end to index and lookup the actual hydra/propeller color word.
// the final palette ALWAYS has 4 colors in it, and based on the color matching rules will always have black as color 0 if the number of colors in the source
// bitmap was less than 4, and after inserting black if there are still slots left in the final palette for example the source bitmap only needed 1,2 colors
// the grays and white will be in the final palette at the upper indices, this helps sprites in the system with black as transparent etc. 

// with that in mind, what we are going to do is convert the bitmap itself to 2-bit codes, the algorithm is; for every pixel in the source bitmap
// find the color that best matches the pixel in the final palette and whatever its index is output that 2-bit code which represents color 0,1,2,3
// also, this bitmap will be constructed in a temp array then as the final step we will output spin code, bitmap masks for sprite bitmaps and the palettes
// as well as take into consideration that the bitmap data must be mirrored left to right for the tile engine.
// first build the bitmap into spin_conv_bitmap then output it based on fliping vars, etc.

for (py = 0; py < height; py++)
    {
if (cmd_V) {
    printf("\n");
}
    for (px = 0; px < width; px++)
        {
        // extract pixel at (px, py)
        b_target = bitmap_buffer[3*(px + py*width) + 0];
        g_target = bitmap_buffer[3*(px + py*width) + 1];
        r_target = bitmap_buffer[3*(px + py*width) + 2];

        // reset color distance to max
        col_dist       = 256*256*3;
        best_col_match = -1; 

        // for each pixel in bitmap match to colors in final palette
        for (index = 0; index < final_pal_num_colors; index++)
            {
            // extract test r,g,b we are testing against for match?
            r_test = hydra_color_map[ final_palette.colors[index] ].peRed;
            g_test = hydra_color_map[ final_palette.colors[index] ].peGreen;       
            b_test = hydra_color_map[ final_palette.colors[index] ].peBlue;
                        
            // compare test rgb to target rgb and if its closer update best match
            int rgb_dist = (r_target - r_test) * (r_target - r_test) + 
                           (g_target - g_test) * (g_target - g_test) + 
                           (b_target - b_test) * (b_target - b_test);
        
            if (rgb_dist < col_dist)
               {
               // update distance and index 
               col_dist       = rgb_dist; 
               best_col_match = index;
               } // end if

            } // end for index
  
        // at this point col_dist and best_col_match are the best matches for the pixel in question, ready to write it out! FINALLY!
if (cmd_V) {
        printf("%2d, ",best_col_match);        
}
        // write data
        spin_conv_bitmap[px + py*width ] = best_col_match;

        } // end for pixel_x

    } // end for pixel_y

if (cmd_V) {
printf("\n\n");
}

// we have everything we need now to output the spin compliant code 

// loop thru image and output spin code
printf("\n\n' Extracted from file \"%s\" at tile=(%d, %d), size=(%d, %d), palette index=(%d)", inputfilename, tx, ty, width, height, num_tileset_palettes-1);
printf("\n%s_tx%d_ty%d_bitmap    LONG", inputfileroot,tx,ty);
for (py = 0; py < height; py++)
    {
    printf("\n              LONG ");

    for (px = 0; px < width; px++)
        {
        // compute final indices taking into consideration mirroring/flipping flags
        int xi = px;
        int yi = py;
        
        if (cmd_FX) 
           xi = (width-1) - xi;

        if (cmd_FY) 
           yi = (height-1) - yi;

        if (px == 0)
            printf("%s%d","%%", spin_conv_bitmap[xi + yi*width ]);
        else
            printf("_%d",spin_conv_bitmap[xi + yi*width ]);
        } // end for px
    } // end for py

// is a mask requested? i.e. this bitmap is for a sprite potentially?
// same thing but map colors [0->0, (1,2,3)->3]
if (cmd_M)
    {
    // loop thru image and output spin code
    printf("\n\n' Extracted from file \"%s\" at tile=(%d, %d), size=(%d, %d), palette index=(%d)", inputfilename, tx, ty, width, height, num_tileset_palettes-1);
    printf("\n%s_tx%d_ty%d_mask", inputfileroot,tx,ty);
    for (py = 0; py < height; py++)
        {
        printf("\n              LONG ");

        for (px = 0; px < width; px++)
            {
            // compute final indices taking into consideration mirroring/flipping flags
            int xi = px;
            int yi = py;
            
            if (cmd_FX) 
            xi = (width-1) - xi;

            if (cmd_FY) 
            yi = (height-1) - yi;

            if (px == 0)
                printf("%s%d","%%", ( (spin_conv_bitmap[xi + yi*width ] > 0) ? 3 : 0)  );
            else
                printf("_%d", ((spin_conv_bitmap[xi + yi*width ] > 0) ? 3 : 0) );
            } // end for px
        } // end for py

    } // end if



// return index of color palette in master list
return(1);

} // end Build_Palette_From_Bitmap

/////////////////////////////////////////////////////////////////////////

int Load_Bitmap_File2(BITMAP_FILE_PTR bitmap, char *filename, int flip)
{
// this function opens a bitmap file and loads the data into bitmap
// it will convert 8, 16, 24 bit bitmaps all into 24-bit data, so 
// palette matching to hydra palette has the most accuracy possible

int file_handle,  // the file handle
    index;        // looping index

UCHAR   *temp_buffer = NULL; // used to convert images to 24 bit
OFSTRUCT file_data;          // the file data information

// open the file if it exists
if ((file_handle = OpenFile(filename,&file_data,OF_READ))==-1)
   return(0);

// now load the bitmap file header
_lread(file_handle, &bitmap->bitmapfileheader,sizeof(BITMAPFILEHEADER));

// test if this is a bitmap file
if (bitmap->bitmapfileheader.bfType!=BITMAP_ID)
   {
   // close the file
   _lclose(file_handle);

   // return error
   return(0);
   } // end if

// now we know this is a bitmap, so read in all the sections

// first the bitmap infoheader

// now load the bitmap file header
_lread(file_handle, &bitmap->bitmapinfoheader,sizeof(BITMAPINFOHEADER));

// compute size of image and store back in structure, some BMP tools mess this up
bitmap->bitmapinfoheader.biSizeImage = bitmap->bitmapinfoheader.biWidth*bitmap->bitmapinfoheader.biHeight*bitmap->bitmapinfoheader.biBitCount/8;

// now load the color palette if there is one
if (bitmap->bitmapinfoheader.biBitCount == 8)
   {
   _lread(file_handle, &bitmap->palette,MAX_COLORS_PALETTE*sizeof(PALETTEENTRY));

   // now set all the flags in the palette correctly and fix the reversed
   // BGR RGBQUAD data format
   for (index=0; index < MAX_COLORS_PALETTE; index++)
       {
       // reverse the red and blue fields
       int temp_color                = bitmap->palette[index].peRed;
       bitmap->palette[index].peRed  = bitmap->palette[index].peBlue;
       bitmap->palette[index].peBlue = temp_color;

       // always set the flags word to this
       bitmap->palette[index].peFlags = PC_NOCOLLAPSE;
       } // end for index

    } // end if

// now, seek to the image data itself
 _lseek(file_handle,-(int)(bitmap->bitmapinfoheader.biSizeImage),SEEK_END);

// now read in the image for 8-bit case
if (bitmap->bitmapinfoheader.biBitCount==8)
   {
   // delete the last image if there was one
   if (bitmap->buffer)
       free(bitmap->buffer);

   // allocate the memory for the 8-bit image
   if (!(temp_buffer = (UCHAR *)malloc(bitmap->bitmapinfoheader.biSizeImage)))
      {
      // close the file
      _lclose(file_handle);

      // return error
      return(0);
      } // end if

   // allocate final 24 bit storage buffer
   if (!(bitmap->buffer=(UCHAR *)malloc(3*bitmap->bitmapinfoheader.biWidth*bitmap->bitmapinfoheader.biHeight)))
      {
      // close the file
      _lclose(file_handle);

      // release working buffer
      free(temp_buffer);

      // return error
      return(0);
      } // end if

   // now read it in to temp file
   _lread(file_handle,temp_buffer,bitmap->bitmapinfoheader.biSizeImage);

   // start the conversion process from 8bit to 24bit
   for (index=0; index < bitmap->bitmapinfoheader.biWidth*bitmap->bitmapinfoheader.biHeight; index++)
       {
        // look up color in palette, compute RGB values
        UCHAR red   = bitmap->palette[ temp_buffer[index] ].peRed;        
        UCHAR green = bitmap->palette[ temp_buffer[index] ].peGreen;
        UCHAR blue  = bitmap->palette[ temp_buffer[index] ].peBlue;
        
       // write colors back out to 24-bit buffer
       ((UCHAR *)bitmap->buffer)[index*3 + 0] = blue;
       ((UCHAR *)bitmap->buffer)[index*3 + 1] = green;
       ((UCHAR *)bitmap->buffer)[index*3 + 2] = red;

       } // end for index

   // finally write out the correct number of bits
   bitmap->bitmapinfoheader.biBitCount=24;

   // recomputing bitmap size
   bitmap->bitmapinfoheader.biSizeImage = bitmap->bitmapinfoheader.biWidth*bitmap->bitmapinfoheader.biHeight*bitmap->bitmapinfoheader.biBitCount/8;

   // release working buffer
   free(temp_buffer);

   } // end if
else
if (bitmap->bitmapinfoheader.biBitCount==24)
   {
   // allocate temporary buffer to load 24 bit image
   if (!(temp_buffer = (UCHAR *)malloc(bitmap->bitmapinfoheader.biSizeImage)))
      {
      // close the file
      _lclose(file_handle);

      // return error
      return(0);
      } // end if

   // allocate final 24 bit storage buffer
   if (!(bitmap->buffer=(UCHAR *)malloc(3*bitmap->bitmapinfoheader.biWidth*bitmap->bitmapinfoheader.biHeight)))
      {
      // close the file
      _lclose(file_handle);

      // release working buffer
      free(temp_buffer);

      // return error
      return(0);
      } // end if

   // now read the file in
   _lread(file_handle,temp_buffer,bitmap->bitmapinfoheader.biSizeImage);

   // now convert each 24 bit BGR value into 24 bit RGB value, simple byte swaping
   for (index=0; index < bitmap->bitmapinfoheader.biWidth*bitmap->bitmapinfoheader.biHeight; index++)
       {
           // extract RGB components (in BGR order)
        UCHAR blue  = temp_buffer[index*3 + 0];
        UCHAR green = temp_buffer[index*3 + 1];
        UCHAR red   = temp_buffer[index*3 + 2];
   
       // write colors back out to buffer
       ((UCHAR *)bitmap->buffer)[index*3 + 0] = blue;
       ((UCHAR *)bitmap->buffer)[index*3 + 1] = green;
       ((UCHAR *)bitmap->buffer)[index*3 + 2] = red;

       } // end for index

   // finally write out the correct number of bits (Redundant)
   bitmap->bitmapinfoheader.biBitCount=24;

   // release working buffer
   free(temp_buffer);

   } // end if 24 bit
else
   {
   // serious problem
   return(0);

   } // end else

if (cmd_V) {
// write the file info out
printf("\nfilename:%s \nsize=%d \nwidth=%d \nheight=%d \nbitsperpixel=%d \ncolors=%d \nimpcolors=%d\n",
        filename,
        bitmap->bitmapinfoheader.biSizeImage,
        bitmap->bitmapinfoheader.biWidth,
        bitmap->bitmapinfoheader.biHeight,
		bitmap->bitmapinfoheader.biBitCount,
        bitmap->bitmapinfoheader.biClrUsed,
        bitmap->bitmapinfoheader.biClrImportant);
}

// close the file
_lclose(file_handle);

// flip the bitmap
if (flip)
    Flip_Bitmap(bitmap->buffer,
                bitmap->bitmapinfoheader.biWidth*(bitmap->bitmapinfoheader.biBitCount/8),
                bitmap->bitmapinfoheader.biHeight);


#if 0
// write TGA file out to confirm image
TGA_HEADER tga;

// open file, if doesn't exist throw error and exit
FILE *fp = fopen("bitmap2.tga", "wb");

// build TGA header
tga.identsize       = 0;   // size of ID field that follows 18 byte header (0 usually)
tga.colourmaptype   = 0;   // type of colour map 0=none, 1=has palette
tga.imagetype       = 2;   // type of image 0=none,1=indexed,2=rgb,3=grey,+8=rle packed

tga.colourmapstart  = 0;    // first colour map entry in palette
tga.colourmaplength = 0;    // number of colours in palette
tga.colourmapbits   = 0;   // number of bits per palette entry 15,16,24,32

tga.xstart          = 0;    // image x origin
tga.ystart          = 0;    // image y origin
tga.width           = bitmap->bitmapinfoheader.biWidth;     // image width in pixels
tga.height          = bitmap->bitmapinfoheader.biHeight;    // image height in pixels
tga.bits            = bitmap->bitmapinfoheader.biBitCount;  // image bits per pixel 8,16,24,32
tga.descriptor      = 0x30; // image descriptor bits (vh flip bits)

 
// write descriptor out
printf("\nWriting TGA header size = %d", sizeof(tga));
fwrite((void *)&tga, sizeof(tga), 1, fp);

printf("\nTGA data size = %d", bitmap->bitmapinfoheader.biSizeImage);
// write the bitmap data out
fwrite((void *)bitmap->buffer, bitmap->bitmapinfoheader.biSizeImage, 1, fp);

// close the file
fclose(fp);

#endif


// return success
return(1);

} // end Load_Bitmap_File2


/////////////////////////////////////////////////////////////////////////

int Load_Bitmap_File(BITMAP_FILE_PTR bitmap, char *filename, int flip)
{
// this function opens a bitmap file and loads the data into bitmap

int file_handle,  // the file handle
    index;        // looping index

UCHAR   *temp_buffer = NULL; // used to convert 24 bit images to 16 bit
OFSTRUCT file_data;          // the file data information

// open the file if it exists
if ((file_handle = OpenFile(filename,&file_data,OF_READ))==-1)
   return(0);

// now load the bitmap file header
_lread(file_handle, &bitmap->bitmapfileheader,sizeof(BITMAPFILEHEADER));

// test if this is a bitmap file
if (bitmap->bitmapfileheader.bfType!=BITMAP_ID)
   {
   // close the file
   _lclose(file_handle);

   // return error
   return(0);
   } // end if

// now we know this is a bitmap, so read in all the sections

// first the bitmap infoheader

// now load the bitmap file header
_lread(file_handle, &bitmap->bitmapinfoheader,sizeof(BITMAPINFOHEADER));

// compute size of image and store back in structure, some BMP tools mess this up
bitmap->bitmapinfoheader.biSizeImage = bitmap->bitmapinfoheader.biWidth*bitmap->bitmapinfoheader.biHeight*bitmap->bitmapinfoheader.biBitCount/8;

// now load the color palette if there is one
if (bitmap->bitmapinfoheader.biBitCount == 8)
   {
   _lread(file_handle, &bitmap->palette,MAX_COLORS_PALETTE*sizeof(PALETTEENTRY));

   // now set all the flags in the palette correctly and fix the reversed
   // BGR RGBQUAD data format
   for (index=0; index < MAX_COLORS_PALETTE; index++)
       {
       // reverse the red and green fields
       int temp_color                = bitmap->palette[index].peRed;
       bitmap->palette[index].peRed  = bitmap->palette[index].peBlue;
       bitmap->palette[index].peBlue = temp_color;

       // always set the flags word to this
       bitmap->palette[index].peFlags = PC_NOCOLLAPSE;
       } // end for index

    } // end if


// finally the image data itself
   _lseek(file_handle,-(int)(bitmap->bitmapinfoheader.biSizeImage),SEEK_END);

// now read in the image
if (bitmap->bitmapinfoheader.biBitCount==8 || bitmap->bitmapinfoheader.biBitCount==16)
   {
   // delete the last image if there was one
   if (bitmap->buffer)
       free(bitmap->buffer);

   // allocate the memory for the image
   if (!(bitmap->buffer = (UCHAR *)malloc(bitmap->bitmapinfoheader.biSizeImage)))
      {
      // close the file
      _lclose(file_handle);

      // return error
      return(0);
      } // end if

   // now read it in
   _lread(file_handle,bitmap->buffer,bitmap->bitmapinfoheader.biSizeImage);

   } // end if
else
if (bitmap->bitmapinfoheader.biBitCount==24)
   {
   // allocate temporary buffer to load 24 bit image
   if (!(temp_buffer = (UCHAR *)malloc(bitmap->bitmapinfoheader.biSizeImage)))
      {
      // close the file
      _lclose(file_handle);

      // return error
      return(0);
      } // end if

   // allocate final 24 bit storage buffer
   if (!(bitmap->buffer=(UCHAR *)malloc(2*bitmap->bitmapinfoheader.biWidth*bitmap->bitmapinfoheader.biHeight)))
      {
      // close the file
      _lclose(file_handle);

      // release working buffer
      free(temp_buffer);

      // return error
       return(0);
      } // end if

   // now read the file in
   _lread(file_handle,temp_buffer,bitmap->bitmapinfoheader.biSizeImage);

   // now convert each 24 bit RGB value into a 16 bit value
   for (index=0; index < bitmap->bitmapinfoheader.biWidth*bitmap->bitmapinfoheader.biHeight; index++)
       {
       // build up 16 bit color word
       USHORT color;

       // build pixel based on format of directdraw surface
       if (dd_pixel_format==DD_PIXEL_FORMAT555)
           {
           // extract RGB components (in BGR order), note the scaling
           UCHAR blue  = (temp_buffer[index*3 + 0] >> 3),
                 green = (temp_buffer[index*3 + 1] >> 3),
                 red   = (temp_buffer[index*3 + 2] >> 3);
           // use the 555 macro
           color = _RGB16BIT555(red,green,blue);
           } // end if 555
       else
       if (dd_pixel_format==DD_PIXEL_FORMAT565)
          {
          // extract RGB components (in BGR order), note the scaling
           UCHAR blue  = (temp_buffer[index*3 + 0] >> 3),
                 green = (temp_buffer[index*3 + 1] >> 2),
                 red   = (temp_buffer[index*3 + 2] >> 3);

           // use the 565 macro
           color = _RGB16BIT565(red,green,blue);

          } // end if 565

       // write color to buffer
       ((USHORT *)bitmap->buffer)[index] = color;

       } // end for index

   // finally write out the correct number of bits
   bitmap->bitmapinfoheader.biBitCount=16;

   // release working buffer
   free(temp_buffer);

   } // end if 24 bit
else
   {
   // serious problem
   return(0);

   } // end else

#if 1
// write the file info out
printf("\nfilename:%s \nsize=%d \nwidth=%d \nheight=%d \nbitsperpixel=%d \ncolors=%d \nimpcolors=%d\n",
        filename,
        bitmap->bitmapinfoheader.biSizeImage,
        bitmap->bitmapinfoheader.biWidth,
        bitmap->bitmapinfoheader.biHeight,
		bitmap->bitmapinfoheader.biBitCount,
        bitmap->bitmapinfoheader.biClrUsed,
        bitmap->bitmapinfoheader.biClrImportant);
#endif

// close the file
_lclose(file_handle);

// flip the bitmap
if (flip)
    Flip_Bitmap(bitmap->buffer,
                bitmap->bitmapinfoheader.biWidth*(bitmap->bitmapinfoheader.biBitCount/8),
                bitmap->bitmapinfoheader.biHeight);

// return success
return(1);

} // end Load_Bitmap_File

/////////////////////////////////////////////////////////////////////////

int Unload_Bitmap_File(BITMAP_FILE_PTR bitmap)
{
// this function releases all memory associated with "bitmap"
if (bitmap->buffer)
   {
   // release memory
   free(bitmap->buffer);

   // reset pointer
   bitmap->buffer = NULL;

   } // end if

// return success
return(1);

} // end Unload_Bitmap_File

/////////////////////////////////////////////////////////////////////////

int Flip_Bitmap(UCHAR *image, int bytes_per_line, int height)
{
// this function is used to flip bottom-up .BMP images

UCHAR *buffer; // used to perform the image processing
int index;     // looping index

// allocate the temporary buffer
if (!(buffer = (UCHAR *)malloc(bytes_per_line*height)))
   return(0);

// copy image to work area
memcpy(buffer,image,bytes_per_line*height);

// flip vertically
for (index=0; index < height; index++)
    memcpy(&image[((height-1) - index)*bytes_per_line],
           &buffer[index*bytes_per_line], bytes_per_line);

// release the memory
free(buffer);

// return success
return(1);

} // end Flip_Bitmap

/////////////////////////////////////////////////////////////////////////

int Load_Mappy_Map(char *filename, MAPPY_MAP_PTR map)
{
// this function loads a mappy map in "simple" .map format, assumes
// that the map output is in the format of 
// maptype="LW1H1A1-0" <--this results in 1 byte per entry, and the format is a binary single array in the format
// importskip=0        <---use dumb import, don't modify anything, just bring the tiles into the tool from your bitmap
// the map can be any size of course

int index; // looping variable
FILE *fp;  // file pointer

// open file, if doesn't exist throw error and exit
if (!(fp = fopen(filename, "rb")))
   {
   printf("\nMappy Loader Error: File not found.\n");
   return(0);
   } // end if
else
    {
    // read width and height
    fread((void *)&map->width, 1, 1, fp);
    fread((void *)&map->height, 1, 1, fp);
    
    // now read in data
    if (!map->height || !map->width)
        {
        // file was possibly corrupt?
        printf("\nMappy Loader Error: Width/Height incorrect.\n");
        fclose(fp);
        return(0);
        } // end if 
   // .. file looks good, let's load the data then...
   // allocate buffer space 
   map->buffer = (UCHAR *)malloc(map->width*map->height);

   // read the bytes in...
  if ( fread((void *)map->buffer, 1, map->width*map->height, fp) != map->width*map->height)
    {
    // file was possibly truncated
    printf("\nMappy Loader Error: File missing data.\n");
    fclose(fp);
    return(0);
    } // end if 

    // all done, now print stats...

    printf("\nLoading map file %s:\n", filename);
    printf("\nWidth = %d", map->width);
    printf("\nHeight = %d", map->height);
    printf("\n");

    // print data out nicely
    for (int row = 0; row < map->height; row++)
        {
        printf("\nRow %2d: ", row);
        for (int col = 0; col < map->width; col++)
            {
            printf("%2X, ", map->buffer[row*map->width + col]);
            } // end for col
        
        } // end for row

    printf("\n");
    // we are done close file, and exit
    fclose(fp);
    return(1);
    } // end else

} // end Load_Mappy_Map


/////////////////////////////////////////////////////////////////////////


void main(int argc, char **argv)
{
BYTE bitmap_buffer[64*64*3];       // used to buffer bitmap as its built and functions are called
int x, y, px, py, tx, ty, index;   // looping vars

// intialize anything here..


// parse the command line 

// test for help request?
if (argc==2 && (!stricmp(argv[1],"-?") || !stricmp(argv[1],"-help")) )
    {
    // print help menu out
    printf("\nUsage BMP2SPIN.exe inputfile [flags] > outputfile");
    printf("\n");
    printf("\nflags = -B -TW[1...255] -TH[1..255] -W[1..256] -H[1..256] -C[1..256] -XYx,y -M -FX -FY -V -I -P[0|1] -?");
    printf("\n");
    printf("\n-B    = Enable 1 pixel border for templated bitmaps, default no border.");
    printf("\n-TWxx = Width of tile set on x-axis, default = 1.");
    printf("\n-THxx = Height of tile set on y-axis, default = 1.");
    printf("\n-Wxx  = Width of tile, default = 16 pixels.");
    printf("\n-Hxx  = Height of tile, default = 16 pixels.");
    printf("\n-Cxx  = Total count of tiles to be converted, if omitted assumed to be tw*th.");
    printf("\n-XYxx,yy = Coordinate of single tile to pull from bitmap, upper left (0,0) overrides -Cxx.");
    printf("\n-M    = Enables mask write as well after each tile.");
    printf("\n-FX   = Flips the output bitmap's on the X axis (needed for hel engine 4.0).");
    printf("\n-FY   = Flips the output bitmap on the Y axis.");
    printf("\n-Px   = Selects the color matching palette 0 or 1, 0 is default, 1 skews color hue 15 degrees approximately.");
    printf("\n-I    = Enables interactive mode.");
    printf("\n-V    = Verbose flag.");
    printf("\n-?    = Prints help.");

    exit(0);
    } // end if


// assume first parm after .exe is the inputfile, good place for more error handling
strcpy(inputfilename, argv[1]);

// now parse thru remaining command line parms and set all command line globals based on them
for (int cmd_index = 2; cmd_index < argc; cmd_index++)
    {
    // what flag is this?
    if (_strnicmp( argv[cmd_index], "-B", 2) == 0)
       {
       //printf("\nFound -B");

       // set border 
       cmd_B = 1;

       } // end if
    else if (_strnicmp( argv[cmd_index], "-TW",3) == 0)
            {
            // parse out the number
            cmd_TW = atoi(argv[cmd_index] + 3);
            //printf("\nFound -TW=%d", cmd_TW);
            } // end if        
    else if (_strnicmp( argv[cmd_index], "-TH", 3) == 0)
            {
            // parse out the number
            cmd_TH = atoi(argv[cmd_index] + 3);
            //printf("\nFound -TH=%d", cmd_TH);

            } // end if        
    else if (_strnicmp( argv[cmd_index], "-W",2) == 0)
            {
            // parse out the number
            cmd_W = atoi(argv[cmd_index] + 2);
            //printf("\nFound -W=%d", cmd_W);

            } // end if        
    else if (_strnicmp( argv[cmd_index], "-H",2) == 0)
            {
            cmd_H = atoi(argv[cmd_index] + 2);
            //printf("\nFound -H=%d", cmd_H);

            } // end if        
    else if (_strnicmp( argv[cmd_index], "-C",2) == 0)
            {
            cmd_C = atoi(argv[cmd_index] + 2);
            //printf("\nFound -C=%d", cmd_C);

            } // end if        
    else if (_strnicmp( argv[cmd_index], "-XY",3) == 0)
            {
            // parse out the numbers in format "xx,yy"
            strcpy(cstring1, argv[cmd_index]+3); 
            strcpy(cstring2, argv[cmd_index]+3); 
        
            // find comma delimeter
            for (cindex1=0; cindex1 < strlen(cstring1); cindex1++)
                if (cstring1[cindex1] == ',')
                   break;

            // xxx,yyy
            //    |
            // cindex1

            // a little error handling
            if (cindex1 >= strlen(cstring1))
               { printf("\nParser error on -XY flag!"); exit(0); }

            // now convert both strings to numbers
            cstring1[cindex1] = 0; // holds x, null terminate
            
            cmd_X = atoi(cstring1);
            cmd_Y = atoi(cstring2+cindex1+1);

            cmd_XY = 1;
            //printf("\nFound -XY=%d, %d", cmd_X, cmd_Y);

            } // end if        
    else if (_strnicmp( argv[cmd_index], "-M", 2) == 0)
            {
            cmd_M = 1;
            //printf("\nFound -M");

            } // end if        
    else if (_strnicmp( argv[cmd_index], "-FX", 3) == 0)
            {
            cmd_FX = 1;
            //printf("\nFound -FX");

            } // end if        
    else if (_strnicmp( argv[cmd_index], "-FY", 3) == 0)
            {
            cmd_FY = 1;
            //printf("\nFound -FY");

            } // end if        
    else if (_strnicmp( argv[cmd_index], "-V", 2) == 0)
            {
            cmd_V = 1;
            //printf("\nEntering verbose debugging mode.");

            } // end if        
    else if (_strnicmp( argv[cmd_index], "-I", 2) == 0)
            {
            cmd_I = 1;
            //printf("\nFound -I");

            } // end if        
    else if (_strnicmp( argv[cmd_index], "-P",2) == 0)
            {
            cmd_P = atoi(argv[cmd_index] + 2);
            //printf("\nFound -P=%d", cmd_P);

            } // end if        
    
    } // end for cmd_index

// set system palette
if (cmd_P==0)
   hydra_color_map = hydra_color_map0;
else
   hydra_color_map = hydra_color_map1;

// extract only root of filename
strcpy(inputfileroot, inputfilename);
for (int i=0; i < strlen(inputfileroot); i++)
    if (inputfileroot[i]=='.') { inputfileroot[i] = 0; break; }

// now shorten name to no longer than 12 characters since it has to be used in spin var names and there is a 30 char limit
if (strlen(inputfileroot) >= 12)
   inputfileroot[12] = 0;

//printf("\ninputfilename root/short = %s", inputfileroot);

if (!Load_Bitmap_File2(&bitmap, inputfilename))
   { printf("\nFile open error!"); exit(0); }

// print header information for SPIN compliant file
printf("\n' Automated output from Bmp2Spin.exe file conversion tool Version 1.0 Nurve Networks LLC\n");
printf("\n' This getter function is used to retrieve the starting address of the tile bitmaps.");
printf("\nPUB tile_bitmaps");
printf("\nRETURN @_tile_bitmaps");

printf("\n\n' This getter function is used to retrieve the starting address of the tile palettes.");
printf("\nPUB tile_palette_map");
printf("\nRETURN @_tile_palette_map");
printf("\n\nDAT\n");
printf("\n_tile_bitmaps    LONG");

// test for mode of operation

// single bitmap tile extraction?
if (cmd_XY)
   {
   // user requested a single tile
    Extract_Bitmap(cmd_X,cmd_Y,             // tile x,y
                   cmd_W,cmd_H,             // width and height of tile
                   cmd_W+cmd_B,cmd_H+cmd_B, // scan step x and y
                   bitmap_buffer, &bitmap);
        
    Build_Palette_From_Bitmap(cmd_X,cmd_Y, cmd_W, cmd_H, bitmap_buffer, 1);

    printf("\n\n' %d palettes extracted from file \"%s\" using palette color map %d", num_tileset_palettes, inputfilename, cmd_P);
    printf("\n_tile_palette_map    LONG");
    printf("\n%s_palette_map    LONG", inputfileroot);
    // print the palettes out
    for (index = 0; index < num_tileset_palettes; index++)
        {
        printf("\n              LONG $%02X_%02X_%02X_%02X ' palette index %d",   hydra_color_map[ tileset_palettes[index].colors[3] ].peFlags,
                                                                                 hydra_color_map[ tileset_palettes[index].colors[2] ].peFlags,
                                                                                 hydra_color_map[ tileset_palettes[index].colors[1] ].peFlags,
                                                                                 hydra_color_map[ tileset_palettes[index].colors[0] ].peFlags,
                                                                                 index);
        } // end for index

   // return 
   exit(0);
   } // end if


// interactive mode?
if (cmd_I)
   {
   printf("\nEntering interactive mode...\n");
    while(1)
        {
        printf("\nEnter \"x y\" to scan bitmap from (enter \"-1 -1\" to exit)?");
        scanf("%d %d", &x, &y);

        if (x==-1 || y==-1) break;

        Extract_Bitmap(x,y,                     // tile x,y
                       cmd_W,cmd_H,             // width and height of tile
                       cmd_W+cmd_B,cmd_H+cmd_B, // scan step x and y
                       bitmap_buffer, &bitmap);
        
        Build_Palette_From_Bitmap(x, y, cmd_W, cmd_H, bitmap_buffer, 1);

        } // end while
   
    printf("\n\n' %d palettes extracted from file \"%s\" using palette color map %d", num_tileset_palettes, inputfilename, cmd_P);
    printf("\n_tile_palette_map    LONG");
    printf("\n%s_palette_map    LONG", inputfileroot);
    // print the palettes out
    for (index = 0; index < num_tileset_palettes; index++)
        {
        printf("\n              LONG $%02X_%02X_%02X_%02X ' palette index %d",   hydra_color_map[ tileset_palettes[index].colors[3] ].peFlags,
                                                                                 hydra_color_map[ tileset_palettes[index].colors[2] ].peFlags,
                                                                                 hydra_color_map[ tileset_palettes[index].colors[1] ].peFlags,
                                                                                 hydra_color_map[ tileset_palettes[index].colors[0] ].peFlags,
                                                                                 index);
        } // end for index

 // return
 exit(0);   

 } // end if interactive mode

// if its not interactive mode and not XY single bitmap mode then user must want standard "template" scan mode, simple, just loop on tile width and height
// and end loop when we reach the "count" he requested

// initialize iterators
px=py=0;

while(cmd_C-- > 0)
    {
    Extract_Bitmap(px,py,                // tile x,y
                cmd_W,cmd_H,             // width and height of tile
                cmd_W+cmd_B,cmd_H+cmd_B, // scan step x and y
                bitmap_buffer, &bitmap);
        
    Build_Palette_From_Bitmap(px, py, cmd_W, cmd_H, bitmap_buffer, 1);

    // move to next tile, if end of template move back left and down 1 row
    if (++px >= cmd_TW)
       { px = 0; py++; }

    } // end while


// print the palettes out
printf("\n\n' %d palettes extracted from file \"%s\" using palette color map %d", num_tileset_palettes, inputfilename, cmd_P);
printf("\n_tile_palette_map    LONG");
printf("\n%s_palette_map    LONG", inputfileroot);

for (index = 0; index < num_tileset_palettes; index++)
    {
    printf("\n              LONG $%02X_%02X_%02X_%02X ' palette index %d",   hydra_color_map[ tileset_palettes[index].colors[3] ].peFlags,
                                                                            hydra_color_map[ tileset_palettes[index].colors[2] ].peFlags,
                                                                            hydra_color_map[ tileset_palettes[index].colors[1] ].peFlags,
                                                                            hydra_color_map[ tileset_palettes[index].colors[0] ].peFlags,
                                                                            index);
    } // end for index

// end tile scan mode ////////////////////////////

} // end main
