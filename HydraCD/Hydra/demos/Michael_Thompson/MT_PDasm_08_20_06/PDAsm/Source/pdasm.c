/********************************************************************
*** pdasm.c
*** Written by Michael Thompson
***
*** This file contains main and support functions for the Propeller
*** Disassembler (PDAsm) and defines a maximum supported code size of
*** 8K Words (or 32K bytes.)
********************************************************************/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "instr.h"
#include "cond.h"

/* Maximum code size in WORDs - 8192 = 32K bytes */
#define MAX_CODE_SIZE 8192

unsigned int code[MAX_CODE_SIZE] = {0};


/****************************************************************
*** Reads the contents of a given file into the code buffer up to
*** MAX_CODE_SIZE.
****************************************************************/
void LoadBuffer(const char * fn)
{
	FILE*	in;

	if(in = fopen(fn, "rb"))
		fread(code, sizeof(unsigned int), MAX_CODE_SIZE, in);

	fclose(in);
}


/****************************************************************
*** Extracts data from given mnemonic opcode and prints the info
*** in a human-readable format.
****************************************************************/
void printMnemonic(unsigned int mnemonic)
{
	int id = (mnemonic & 0xFF800000) >> 23;			/* extract opcode lookup key */
	int op = (mnemonic & 0xFC000000) >> 26;			/* ... opcode */
	int zf = (mnemonic & 0x02000000) ? 'z' : '-';	/* ... z flag */
	int	cf = (mnemonic & 0x01000000) ? 'c' : '-';	/* ... c flag */
	int	uf = (mnemonic & 0x00800000) ? 'r' : '-';	/* ... r flag */
	int	sf = (mnemonic & 0x00400000) ? 'i' : '-';	/* ... i flag */
	int	am = (mnemonic & 0x00400000) ? '#' : ' ';	/* if immediate show #, else show space */
	int cx = (mnemonic & 0x003C0000) >> 18;			/* extract condition lookup key */
	int ca = (mnemonic & 0x00200000) >> 21;			/* ... 1st cond. flag */
	int cb = (mnemonic & 0x00100000) >> 20;			/* ... 2nd cond. flag */
	int cc = (mnemonic & 0x00080000) >> 19;			/* ... 3rd cond. flag */
	int cd = (mnemonic & 0x00040000) >> 18;			/* ... 4th cond. flag */
	int dr = (mnemonic & 0x0003FE00) >> 9;			/* ... destination register */
	int sr = (mnemonic & 0x000001FF);				/* ... source register */

	/* if cx is set, its a valid instruction, otherwise use special 'NOP' printing method */
	if(cx)
		printf("%.8X | %2X | %c%c%c%c | %d%d%d%d | %12s %8s %.3d, %c%.3d", mnemonic, op, zf, cf, uf, sf, ca, cb, cc, cd, gCondName[cx], gInstrName[id], dr, am, sr);
	else
		printf("%.8X | %2X | %c%c%c%c | %d%d%d%d | %12s %8s", mnemonic, op, zf, cf, uf, sf, ca, cb, cc, cd, gCondName[cx], "NOP");

}


/****************************************************************
*** Accepts and configures command line arguments, performs setup
*** & preamble and finally loops to decode binary source.
****************************************************************/
int main(int argc, char **argv)
{
	int		iLine = 0;
	int		nLine = MAX_CODE_SIZE;
	int		start = 0;
	char *	iname = 0;

	switch(argc)
	{
	case 4:
		nLine = atoi(argv[3]);
	case 3:
		start = atoi(argv[2]);
	case 2:
		iname = argv[1];
		break;
	default:
		/* If theres not at least 1 argument (the input file) */
		printf("\nUsage is: 'pdasm.exe <input file> <begin> <number>'\n");
		printf("  <input file>\tRequired\tName of file to read.\n");
		printf("  <begin>\tOptional\tWORD at which to begin disassembly (0-8191)\n");
		printf("  <number>\tOptional\tNumber of WORDs to disassemble (0-8192)\n\n");
		printf("output may be redirected into a file using the '>' operator.\n");
		printf("  example: 'pdasm.exe asteroids.bin 0 256 > out.txt'\n\n");
		printf("Press [enter] to return...");
		
		getchar();
		
		return 0;
	}

	LoadBuffer(iname);

	/* Make sure we stay within the extents */
	if((start && nLine > (MAX_CODE_SIZE - start)) || nLine > 0x4FFF)
		nLine = (MAX_CODE_SIZE - start);


	/* one time header */
	printf(" Location | ByteCode | Op | Flag | Cond | Code:\n");
	printf("----------+----------+----+------+------+--------------------------------------\n");

	/* loop for all code words from start through start + nLine */
	for(iLine = start; iLine < start + nLine; ++iLine)
	{
		/* print address(hex), decoded instruction & newline */
		printf(" %8.8X | ", iLine); printMnemonic(code[iLine]); printf("\n");
	}
}

/* EOF */