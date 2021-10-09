Instrgen Readme Version 0.9.0

1) Overview
2) The 'instr.txt' file
3) Sample file contents


Overview -

The instrgen.exe program is a tool which generates a C language source file which defines an array of 512 mnemonic strings. The tool reads a file 'instr.txt' located in the same directory as the tool. This file is a tab-delineated list of the binary mnemonic identifiers and their Assembly equivilant. The generated output file 'instr.c' is then compiled into the PDAsm tool. The instrgen.exe tool is provided to add new or missed operations to future versions of the PDAsm tool.


The 'instr.txt' file -

The 'instr.txt' file defines a list of decodable instructions and their equivilant assembly names. Each line of the file contains a 9-digit binary number which cooresponds to the most signifigant 9 binary digits of an instruction word followed by a single tab and its cooresponding assembly keyword. The very last line must read 'xxxxxxxxx<TAB>NOP' to signal the end of the file.


Sample file contents -

-opcode-|-<TAB>-|-keyword-

[BEGIN SAMPLE]

000000001	RDBYTE
000001001	RDWORD
000010001	RDLONG
000100000	WRBYTE
...		...
xxxxxxxxx	NOP