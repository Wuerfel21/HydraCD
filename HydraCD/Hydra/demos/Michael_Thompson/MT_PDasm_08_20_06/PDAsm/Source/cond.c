/********************************************************************
*** cond.c
*** Written by Michael Thompson
***
*** This file defines an array which serves as a lookup table between
*** the identifying bits of a condition code and one of its
*** equivilant assembly keywords.
********************************************************************/

#include "cond.h"


const char gCondName[16][16] = {
	"",				// NEVER
	"IF_NC_AND_NZ",	//  / IF_NZ_AND_NC / IF_A",
	"IF_NC_AND_Z",	//  / IF_Z_AND_NC",
	"IF_NC",		//  / IF_AE",
	"IF_C_AND_NZ",	//  / IF_NZ_AND_C",
	"IF_NZ",		//  / IF_NE",
	"IF_C_NE_Z",	//  / IF_Z_NE_C",
	"IF_NC_OR_NZ",	//  / IF_NZ_OR_NC",
	"IF_C_AND_Z",	//  / IF_Z_AND_C",
	"IF_C_EQ_Z",	//  / IF_Z_EQ_C",
	"IF_Z",			//  / IF_E",
	"IF_NC_OR_Z",	//  / IF_Z_OR_NC",
	"IF_C",			//  / IF_B",
	"IF_C_OR_NZ",	//  / IF_NZ_OR_C",
	"IF_C_OR_Z",	//  / IF_Z_OR_C / IF_BE",
	""				// ALWAYS
};

/* EOF */