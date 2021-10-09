PDasm Readme Version 0.9.0


1) Overview
2) How it works
3) Usage
4) Known Issues


1. Overview -

The PDasm program disassembles Propeller (PChip) Binary images into its constituting ASM instructions. No attempt is made to identify Data elements or SPIN code as of this release. It should work on any 32k propeller .bin file.


2. How it works -

The process works by breaking down Code Words into thier atomic elements (refer to the Hydra Demo Coder's manual for more info) and using this data to identify the instruction. Primarily, the 9 highest bits are used to identify the instruction, and the 4 condition bits are used to identify the conditional modifiers. Because there are several conditional modifiers for each 4 bit encoding, it is impossible to restore the exact conditional modifier used in the original asm code, however it may be possible to infer the correct modifier based on preceding instructions in the future.

3. Usage -

Usage is: 'pdasm.exe <input file> <output file> <begin> <number>'
	<input file>	Required	Name of file to read.
	<output file>	Optional	Name of file to write.
	<begin>		Optional	WORD at which to begin disassembly (0-8191)
	<number>	Optional	Number of WORDs to disassemble (0-8192)

4. Known Issues -

a) No attempt to infer correct conditional modifiers at this time.
b) Some instructions are not correctly handled at this time, namely:
	CLKSET
	COGID
	COGINIT
	COGSTOP
	LOCKNEW
	LOCKRET
	LOCKSET
	LOCKCLR
   These instructions require further decoding and logic to correctly identify.