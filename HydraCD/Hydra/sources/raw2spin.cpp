////////////////////////////////////////////////////////////////////////
// Raw2Spin.cpp - Converts RAW audio data files into SPIN DAT format
// compatible with sound driver. 
// Author: Andre' LaMothe
// Last Modified: 7.7.06
// Usage: Raw2Spin soundfile.raw
// Where "soundfile.raw" is a RAW audio format PCM file with 8-bit
// samples, mono, signed @ 11 KHz.
//
// The program simply outputs the SPIN data right to the console/STDOUT,
// so you can redirect it to a file like so:
// Raw2Spin soundfile.raw > soundfile.spin
// 
////////////////////////////////////////////////////////////////////////


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

// TYPES ////////////////////////////////////////////////////////////////
// basic unsigned types
typedef unsigned short USHORT;
typedef unsigned short WORD;
typedef unsigned char  UCHAR;
typedef unsigned char  BYTE;
typedef unsigned int   QUAD;
typedef unsigned int   UINT;

// MACROS ///////////////////////////////////////////////////////////////

// bit manipulation macros
#define SET_BIT(word,bit_flag)   ((word)=((word) | (bit_flag)))
#define RESET_BIT(word,bit_flag) ((word)=((word) & (~bit_flag)))

// used to compute the min and max of two expresions
#define MIN(a, b)  (((a) < (b)) ? (a) : (b))
#define MAX(a, b)  (((a) > (b)) ? (a) : (b))
#define SIGN(a) ( ((a) > 0) ? (1) : (-1) )

// used for swapping algorithm
#define SWAP(a,b,t) {t=a; a=b; b=t;}


#define RAND_RANGE(x,y) ( (x) + (rand()%((y)-(x)+1)))


// PROTOTYPES ///////////////////////////////////////////////////////////



// EXTERNALS ////////////////////////////////////////////////////////////


// GLOBALS //////////////////////////////////////////////////////////////


char		filename[256];     // general filename

// FUNCTIONS ////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////

int Raw2Spin(char *filename)
{
int index;       // looping variable
FILE *fp;        // file pointer
int filesize;    // length of file
unsigned char rawbuffer[32768]; // 32K raw data buffer

// open file, if doesn't exist throw error and exit
if (!(fp = fopen(filename, "rb")))
   {
   printf("\nRAW To Spin Error: File not found.\n");
   return(0);
   } // end if

// read entire file at once, impossible to have file larger than 32K
filesize = fread((void *)rawbuffer, sizeof(UCHAR), 32768, fp);

// step 1: output header information comaptible with sound driver's API interface
printf("\n' Automated output from Raw2Spin.exe file conversion tool Version 1.0 Nurve Networks LLC\n");
printf("\n' This getter function is used to retrieve the starting address of the sound sample.");
printf("\nPUB ns_hydra_sound");
printf("\nRETURN @_ns_hydra_sound");

printf("\n\n' This getter function is used to retrieve the ending address of the sound sample.");
printf("\nPUB ns_hydra_sound_end");
printf("\nRETURN @_ns_hydra_sound_end");

printf("\n\nDAT");
printf("\n' Data Type: RAW signed audio data");
printf("\n' Original filename - %s", filename);
printf("\n' Size: %d Bytes", filesize);
printf("\n' Range: 0 -> $%X\n", filesize-1);
printf("\n_ns_hydra_sound\n"); 

// step 2: output data statements 16 per line

for (index=0; index < filesize; index++)
    {
    // test if this is first element
    if ((index % 16) == 0) 
        { printf("\n        BYTE $%02X", rawbuffer[index]); }
    else 
        { printf(" ,$%02X", rawbuffer[index]); }
    } // end for index

// step 3: output final closing header information
printf("\n\n_ns_hydra_sound_end\n"); 

// return the filesize
return(filesize);

} // end Raw2Spin

////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////

void main(int argc, char **argv)
{
int index, ch, filesize;

// test for help
if (argc == 1)
    printf("\nUsage Raw2Spin.exe source.raw");
else
    // perform the conversion
    Raw2Spin((char *)argv[1]);

} // end main
