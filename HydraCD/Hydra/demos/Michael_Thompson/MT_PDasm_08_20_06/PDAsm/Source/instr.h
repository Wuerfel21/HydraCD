/********************************************************************
*** instr.h
*** Written by Michael Thompson
***
*** This file declares an array which serves as a lookup table
*** between the identifying bits of an instruction WORD and its
*** equivelant assembly keyword and makes it available externally.
********************************************************************/

#ifndef PDASM_INSTR_H
#define PDASM_INSTR_H

extern char gInstrName[512][8];

#endif

/* EOF */