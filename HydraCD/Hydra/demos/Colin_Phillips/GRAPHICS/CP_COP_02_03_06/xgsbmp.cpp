// xgsbmp - does various image/file conversions for the XGS Pico/Micro/Hydra
// Colin Phillips - colin.phillips@gmail.com

#include "stdafx.h"
#include <io.h>
#include <string.h>
#include <math.h>

#define VERSION_STR		"1.05"

typedef unsigned char BYTE;
typedef unsigned long DWORD;
typedef signed long LONG;
typedef unsigned short int WORD;

#define rgb32(r,g,b) ((r<<16)|(g<<8)|b)
/*DWORD g_color_wheel[16] = { // these were color values from the TV (from Andre's XGS e-Book)
0xAAA83F,
0xD8B03E,
0xEFBC56,
0xEEBC77,

0xE6B780,
0xF0A699,
0xE5A4C0,
0xD1A1D1,

0xB57DBB,
0xCE95E9,
0xA977D6,
0x9063D8,

0x7657CF,
0x6658CB,
0x5267ED,
0xFFFFFF,
};*/

DWORD g_color_wheel[16] = { // these are from the XGSEmu //
0xFEFE00,
0xFEBE00,
0xFE7F00,
0xFE3F00,

0xFE0000,
0xFE003F,
0xFE007F,
0xFE00BE,

0xFE00FE,
0xBE00FE,
0x7F00FE,
0x3F00FE,

0x0000FE,
0x007FFE,
0x00FEFE,
0xFFFFFF
};

// Colors: 86

DWORD g_color_wheel_HYDRA[] = {
// 0
0x2A0278, 0x090B83, 0x1A396E, 0x132B3B, 
0x1D292C, 0x203027, 0x113F15, 0x1C3514, 
0x2F3611, 0x483A13, 0x58370E, 0x732207, 
0x67141F, 0x741E48, 0x4F1145, 0x420F65, 
// 1
0x4509B7, 0x1213A8, 0x2554A1, 0x225779, 
0x41626B, 0x446B57, 0x1C7B27, 0x376924, 
0x5A681F, 0x725E20, 0x7B4F14, 0xA1330E, 
0x9C2532, 0x982B60, 0x791A6C, 0x661A96, 
// 2
0x794ACF, 0x4D4FC0, 0x4072C0, 0x2E7CAC, 
0x4F8FA0, 0x6D9C85, 0x32A23A, 0x69A642, 
0x94A54C, 0x9F8442, 0xA37637, 0xB86E4C, 
0xBC737F, 0xB86891, 0xAC439D, 0x9F5AC9, 
// 3
0xA38BCB, 0x7E81BE, 0x6D8DC0, 0x6C9FBE, 
0x7FAEBB, 0x8EB4A2, 0x78B87B, 0x92BD75, 
0xADB686, 0xB6A072, 0xBCA07B, 0xC0A091, 
0xBB979E, 0xBE8DA7, 0xBC85B5, 0xB085CB, 
// 4
0xC0B3D7, 0xA8A8CA, 0xA5B4CC, 0xA2BBCC, 
0xAFC3C9, 0xB2CABF, 0xB3CBB5, 0xBECCB3, 
0xC8CBB0, 0xCBC0A8, 0xCABAA5, 0xCCBAB2, 
0xCBB4B9, 0xCAAFBD, 0xC8B2C5, 0xCBB7D6, 
// B/W
0x000000, 0x383838, 0x737373, 0xABABAB, 
0xE5E5E5, 0xFFFFFF, 
};

DWORD g_color_trans = 0x000000; // RGB 0,0,0 is considered transparancy defaultly.

typedef struct {
BYTE res[10];
DWORD img_off; // 10th-Offset to the start of the Image (Pixels) [0x436]
			   // Subtract 1k to get start of Palette Data.
} BITMAPFILEHEADER_typ; // 14 bytes.

typedef struct {
DWORD size;	// 14th byte.
DWORD width;
DWORD height;
WORD planes;
WORD bitcnt;
DWORD comp;
DWORD sizeimg;
LONG xppm;
LONG yppm;
DWORD clrused;
DWORD clrimp;	// 40 bytes.
} BITMAPINFO_typ;

BITMAPFILEHEADER_typ bmph;
BITMAPINFO_typ bmpi;


#define MAX_IMGSIZE		(640*480)
DWORD img_buf[MAX_IMGSIZE];


// CSource ////////////////////////////////////////////////////////////////////////////////////////////////////
#define MAX_LINE_LENGTH	4096
class CSource {
public:
char m_title[256];				// title of source file/macro
char m_line[MAX_LINE_LENGTH]; // Max line length
int m_line_i;
int m_start;
int m_offset;
int m_length;
char *m_data;
CSource();
~CSource();
int Load(char *fname);
char *ReadLine(int strip_comments = 0);
void strcpy(char *str);
void SetTitle(char *str);
char *GetTitle(void);
};

CSource::CSource()
{
	m_offset = 0;
	m_line_i = 0; // first line is 1
	m_length = 0;
	m_title[0] = 0; // untitled
}

CSource::~CSource()
{
	if(m_length) delete m_data;
}

int CSource::Load(char *fname)
{
	if(m_length) delete m_data;
	FILE *fptr;
	int fno;
	fptr = fopen(fname,"rb");
	if(!fptr)
	{
	printf("File not found '%s'\n",fname);
	return 0;
	}
	fno = fileno(fptr);
	m_length = filelength(fno);
	m_data = new char[m_length];
	//printf("Loading %s (%ldbytes):", fname, m_length);
	fread(m_data, m_length, 1, fptr);
	fclose(fptr);
	//printf("Done\n");
	m_offset = 0;
	m_line_i = 0; // first line is 1
	return 1;
}

void CSource::strcpy(char *str)
{
	if(m_length) delete m_data;
	m_length = strlen(str)+1;
	m_data = new char[m_length];
	memcpy(m_data, str, m_length);
	m_offset = 0;
	m_line_i = 0; // first line is 1
}

void CSource::SetTitle(char *str)
{
	//::strcpy(m_title,str);
	int n;
	char *p;
	if(str[0] == 0)
	{
	m_title[0] = 0;
	return;
	}

	p = m_title;
	//*p++='_';
	for(n=0;n<256;n++) // just copy the first word upto whitespace
	{
	*p = str[n];
	if(str[n]<=32) break;
	p++;
	}
	*p = 0; // terminator
	//sprintf(p,"%d",g_unique);
	//g_unique++;
		
	//char *GetTitle(void);
	//printf("[%s]",m_title);

}

char *CSource::GetTitle(void)
{
	return m_title;
}

char *CSource::ReadLine(int strip_comments)
{
	int end;
	int i;
	int rem;
	int t;

	if(m_offset>=m_length) return NULL;
	m_start = m_offset;
	end = m_offset;
	i = 0;
	rem = 0;
	while(end<m_length)
	{
	if(!rem)
	{
	m_line[i] = m_data[end];
	
	if(m_line[i]==0x09) {
						t = (i&3); // 0,1,2,3
						t = 4-t;
						//if(t==0) t = 4;
						while(t)
						{
						m_line[i] = ' ';
						i++;
						t--;
						}
						i--;
						}

	if(m_line[i]==0x0d || m_line[i]==0x0a);  // [+] get tab in there too later //
	else if(m_line[i]==';' && strip_comments) rem = 1; // rem mode (ignore rest of line) [+] have to add some code which will cater to strings that have the rem code
	else i++;

	}
	end++;
	if(m_data[end-1]=='\n') break; // end of line //
	}
	m_line[i] = 0; // terminator //
	m_offset = end;
	m_line_i++;
	return m_line;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////


int g_output_file_hex_write;
int g_output_file_hex_l;
int g_output_file_hex_p;
int g_output_file_hex_i = 0;
int g_output_file_limit_hit = 0;
DWORD g_output_file_hex_org;
DWORD g_output_file_hex_limit;
FILE *g_output_file_fptr;
char g_output_file_label[80];

char g_source[80];
char g_dest[80];
char g_dest2[80];
void bmpload32(DWORD *buf,DWORD pitch,char *fname);
void convertsrcXGS(char *fname);
void convertsrcXGSRAW(char *fname);
void generateSINEWAVE(char *fname);
int g_flag_rle = 0;
int g_flag_sin = 0;
int g_flag_bin = 0;
int g_flag_asciimap = 0;
int g_flag_op = 0;
char g_op_arg[32];
signed long g_sin_amp;
signed long g_sin_wavelength;
signed long g_sin_cut;
int g_palette = 0;
int g_mode;
int g_phase;
float g_bias_r = 1;
float g_bias_g = 1;
float g_bias_b = 1;

#define XGS_MICRO			0
#define XGS_HYDRA			1


char *empty_STR = "";

// text file system ripped from the SXASM project //
CSource *g_textfile;

void convertsrcXGSASCIIMAP(char *fname);
void convertsrcXGSCOMBINE(char *src1, char *src2, char *dest);

void setlabel(char *fname)
{
	int n;
	char c;
	for(n=0;n<80;n++)
	{
	c = fname[n];
	if(c>='a' && c<='z');
	else if(c>='A' && c<='Z') c+=32;
	else if(c>='0' && c<='9');
	else if(!c);
	else c = '_';
	g_output_file_label[n] = c;
	if(!c) break;
	}
}

int closest_color(float r, float g, float b);

int main(int argc, char* argv[])
{
	int n;
	int i;
	char c;
	int file_arg;
	char tmp_arg[80];
	char *ext_arg;

	//i = closest_color(255,0,0);
	//printf("%lx",i);

	g_textfile = new CSource();
	g_output_file_hex_org = 0x000;
	g_flag_rle = 0;
	g_flag_sin = 0;
	g_flag_bin = 0; // binary output
	g_flag_asciimap = 0;
	g_flag_op = 0;
	g_op_arg[0] = 0;
	g_output_file_hex_limit = 0x7fffffff;
	g_mode = XGS_MICRO;

	g_sin_amp = 255;
	g_sin_wavelength = 256;
	g_sin_cut = 64;
	g_phase = 0x02;

	printf("XGSBMP Ver %s\n", VERSION_STR);

	file_arg = 0;
	for(n=1;n<argc;n++)
	{
	//printf("%d:%s\n",n, argv[n]);
	strcpy(tmp_arg, argv[n]);
	ext_arg = empty_STR;
	for(i=0;i<80;i++)
	{
	if(!tmp_arg[i]) break;
	if(tmp_arg[i] == ':') {
							ext_arg = &tmp_arg[i+1];
							tmp_arg[i] = 0;
							break;
						}
	}
	if(!strcmpi(tmp_arg, "-org")) sscanf(ext_arg,"%lx",&g_output_file_hex_org);
	else if(!strcmpi(tmp_arg, "-limit")) sscanf(ext_arg,"%lx",&g_output_file_hex_limit);
	else if(!strcmpi(tmp_arg, "-rle")) g_flag_rle = 1;
	else if(!strcmpi(tmp_arg, "-sin")) {
										sscanf(ext_arg,"%ld,%ld",&g_sin_amp,&g_sin_wavelength);
										g_flag_sin = 1; // generate a sine wave 0-90 degrees
										}
	else if(!strcmpi(tmp_arg, "-bin")) g_flag_bin = 1; // binary output
	else if(!strcmpi(tmp_arg, "-asciimap")) g_flag_asciimap = 1; // ascii map conversion
	else if(!strcmpi(tmp_arg, "-op")) {
									strcpy(g_op_arg, ext_arg);
									g_flag_op = 1;
									}
	else if(!strcmpi(tmp_arg, "-hydra")) {
		g_mode = XGS_HYDRA;
		}
	else if(!strcmpi(tmp_arg, "-phase")) sscanf(ext_arg,"%lx",&g_phase);
	else if(!strcmpi(tmp_arg, "-palette")) g_palette = 1;
	else if(!strcmpi(tmp_arg, "-trans")) sscanf(ext_arg,"%lx",&g_color_trans); // set transparancy check color.
	else if(!strcmpi(tmp_arg, "-bias_red")) sscanf(ext_arg," %f", &g_bias_r);
	else if(!strcmpi(tmp_arg, "-bias_green")) sscanf(ext_arg," %f", &g_bias_g);
	else if(!strcmpi(tmp_arg, "-bias_blue")) sscanf(ext_arg," %f", &g_bias_b);
	else {
	switch(file_arg)
		{
		case 0:strcpy(g_source, tmp_arg);
			   printf("Source: %s\n", tmp_arg);
			   break;
		case 1:strcpy(g_dest, tmp_arg);
			   printf("Dest: %s\n", tmp_arg);
			   break;
		case 2:strcpy(g_dest2, tmp_arg);
			   printf("Dest2: %s\n", tmp_arg);
			   break;
		default:printf("Invalid Argument '%s'\n", tmp_arg);
				return 0;
		}
	file_arg++;
	}

	}

	// Sine Wave Generation //
	if(g_flag_sin)
	{
	printf("Amp: %ld\nWavelength: %ld\nCut: >=%ld\n", g_sin_amp, g_sin_wavelength, g_sin_cut);
	if(file_arg<1) {
					printf("\n\tUsage: XGSBMP <output.src> <-sin:%ld,%ld,%ld>\n\n",g_sin_amp, g_sin_wavelength, g_sin_cut);
				return 0;
				}
	setlabel(g_source);
	generateSINEWAVE(g_source);
	return 0;
	}

	if(file_arg<2) {
					printf("\n\tUsage: XGSBMP <source.*> <dest.*> [-org:000] [-rle] [-sin:255,256,64] [-asciimap] [-op:][-bin][-limit:]\n\n");
					printf("\t<source.*> \tsource file (e.g. source.bmp, map.txt..)\n");
					printf("\t<dest.*> \tdestination file (e.g. image.src, map.bin..)\n");
					printf("\t-bin \t\tbinary file output\n");
					printf("\t-org:XXX \thexadecimal starting address for data\n");
					printf("\t-limit:XXX \thexadecimal limiting address for data (e.g. -limit:fff for XGS/SX52)\n");
					printf("\t-rle \t\tGenerate Run Length Encoded image <Source> <Dest>\n");
					printf("\t-sin: \t\tAmp,WaveLength,CutOff Generate Sine table <Dest>\n");
					printf("\t-asciimap \tAscii map <Source> <Dest>\n");
					printf("\t-op:opcode \tFile combine Operation -op:or, -op:and, -op:add, -op:sub, -op:replacenotzero <Source> <Source2> <Dest>\n");
					printf("\t-hydra \t XGS Hydra color output\n");
					printf("\t-phase \t XGS Hydra phase/luma offset (default 02)\n");
					printf("\t-palette \t Generate Hydra Palette from first 86 colors\n");
					printf("\t-trans:RRGGBB \t Specify Transparancy HEX color e.g. -trans:FFFFFF for white. (Transparent pixels stored as $00)\n");
					printf("\t-bias_red:Float \t Specify Red Bias in color matching e.g. -bias_red:0.4 (default 1.0) \n");
					printf("\t-bias_green:Float \t Specify Green Bias in color matching e.g. -bias_green:0.7 (default 1.0)\n");
					printf("\t-bias_blue:Float \t Specify Blue Bias in color matching e.g. -bias_blue:1.0 (default 1.0)\n");
					return 0;
					}
	// File Operation
	if(g_flag_op)
	{
		if(file_arg<3) {
						printf("\n\tUsage: XGSBMP <source1.*> <source2.*> <dest.*> <-op:opcode>\n\n");
						return 0;
						}
	setlabel(g_dest2); // label is the name of the destination file - since it's a combination of stuff //
	convertsrcXGSCOMBINE(g_source, g_dest, g_dest2);
	return 0;
	}
	// Ascii Map conversion //
	if(g_flag_asciimap)
	{
	if(!g_textfile->Load(g_source)) return 0; // Failed to load text file //
	setlabel(g_source);
	convertsrcXGSASCIIMAP(g_dest);
	return 0;
	}
	// Default BMP conversion //
	bmpload32(img_buf, 0, g_source);
	printf("Dimensions: %ldx%ld\n",bmpi.width, bmpi.height);
	printf("Org: $%03lX\n", g_output_file_hex_org);
	setlabel(g_source);
	if(g_palette)
	{
	if(g_flag_rle) convertsrcXGS("xgsbmp.tmp"); // RLE Compressed image
	else convertsrcXGSRAW("xgsbmp.tmp");	// RAW image
	}
	else {
	if(g_flag_rle) convertsrcXGS(g_dest); // RLE Compressed image
	else convertsrcXGSRAW(g_dest);	// RAW image
	}
	return 0;
}
#define BMPLOAD_MAXRES 1280
void bmpload32(DWORD *buf,DWORD pitch,char *fname)
{// Loads a Bmp image at 24bpp. Dumps it into the *ptr of 16bpp
	FILE *fptr;
	DWORD ptr;
	DWORD x,y;
	DWORD pitch_arg;


	BYTE RGBCOLBUF[3*BMPLOAD_MAXRES];	// Max Res. of 1280 across.
	BYTE *RGBCOLPTR;
	DWORD PACK;	// Colour PACK.
	DWORD d_shft1,d_shft2;
	d_shft1 = 8;//Mgfx.rshft-Mgfx.gshft;
	d_shft2 = 8;//Mgfx.gshft-Mgfx.bshft;
	fptr = fopen(fname,"rb");			// Open the File!
	fseek(fptr,10,SEEK_SET);
	fread(&ptr,4,1,fptr);				// Find Start of Colour DATA.
	fseek(fptr,14,SEEK_SET);			// [*] Something HERE IS messed UP!!!!!!!
										// It SHOULD WORK WITHOUT THIS LINE!!!
	fread(&bmpi,sizeof(bmpi),1,fptr);	// Dump this into the Buffer. [ INFO ]
	// IF YOU WANT IMG_DATA, FSEEK to (bmph.img_off)
	fseek(fptr,ptr,SEEK_SET);			// Start of Image - File[Pixel(0,HEIGHT-1);]
	if(!pitch) pitch_arg = bmpi.width;	// Already in Pixels.
	else pitch_arg = pitch>>2; // In Pixels Dewd.
	ptr = pitch_arg*(bmpi.height-1);	// Point to buf[Pixel(0,HEIGHT-1);]
	//pitch_arg<<=1;	// Need for quicker Calc.
	pitch_arg+=bmpi.width; // BUG FIX
	buf+=ptr; // Jump to this location.
	for(y=0;y<bmpi.height;y++) // Go down the ROWS [FILE]. & UP THE ROWS [DATA]
	{
	fread(RGBCOLBUF,bmpi.width*3,1,fptr);	// Dump 1 line into tempo buffer.
	RGBCOLPTR = (BYTE *) RGBCOLBUF;	// Point to start of this buffer.
	for(x=0;x<bmpi.width;x++)
	{
	PACK = (RGBCOLPTR[2]);//>>Mgfx.rshft2;
	PACK<<=d_shft1;
	PACK|= (RGBCOLPTR[1]);//>>Mgfx.gshft2;
	PACK<<=d_shft2;
	PACK|= (RGBCOLPTR[0]);//>>Mgfx.bshft2;
	*buf++=PACK;
	RGBCOLPTR+=3;
	}
	buf-=pitch_arg;	// Go up by 2 lines. [Back to start of this line, Then Up a line]
	}
	fclose(fptr);
}

int closest_color(float r, float g, float b)
{
	int n;
	float r2,g2,b2;
	int z_best;
	float z_value;
	float z;
	int luma;
	int chroma;

	// Calculate Luma /////////////////////////////////////////////////////////
	luma = r;
	if(g>luma) luma = g;
	if(b>luma) luma = b;

	// luma range from 0-255 => 6->15 [9 shades]
	luma = ((luma*10)/256) + 6;
	if(luma>15) luma = 15;
	else if(luma<6) luma = 6;

	return (luma<<4)|luma;

	// Calculate Chroma B/W ///////////////////////////////////////////////////

	//  r (roughly) = g (roughly) = b
	if(r-g < 5 && r-g > -5)
	if(g-b < 5 && g-b > -5) return 15<<4 | luma;

	// Calculate Chroma Color /////////////////////////////////////////////////

	z_best = -1;
	z_value = 0;
	
		for(n=0;n<16;n++)
		{
		r2 = (g_color_wheel[n]>>16)&0xff;
		g2 = (g_color_wheel[n]>>8)&0xff;
		b2 = (g_color_wheel[n])&0xff;

		z = (r2-r)*(r2-r)+
			(g2-g)*(g2-g)+
			(b2-b)*(b2-b);
		// closer value //
		if(z<z_value || z_best==-1) z_best = n, z_value = z;
		}

	return z_best<<4 | luma;
}

#define COLOR_WHEEL_HYDRA_TOTAL	(16*5 + 6)

int cclut_counter = 0;

DWORD g_color_wheel_gen[COLOR_WHEEL_HYDRA_TOTAL];

int closest_color_HYDRA(float r, float g, float b)
{
	int n;
	float r2,g2,b2;
	int z_best;
	float z_value;
	float z;
	int luma;
	int chroma;

	// Generate Palette (palette mode) ////////////////////////////////////////

	if(g_palette)
		{
			if(cclut_counter<COLOR_WHEEL_HYDRA_TOTAL)
			{
				int rx, gx, bx;
				int x,y,t;
				rx = r;
				gx = g;
				bx = b;
				if(rx>255) rx = 255;
				if(gx>255) gx = 255;
				if(bx>255) bx = 255;

				g_color_wheel_gen[cclut_counter] = rx<<16 | gx<<8 | bx;
				if(cclut_counter==COLOR_WHEEL_HYDRA_TOTAL-1)
				{
				FILE *fptr;
				fptr = fopen(g_dest,"wb"); // "colorwheel_lut.cpp"

				fprintf(fptr, "// Colors: %d\r\n\r\n",cclut_counter+1);
				fprintf(fptr, "DWORD g_color_wheel_HYDRA[] = {");

				t = 0;
				for(y=0;y<6;y++) // do 96 colors for now.
				for(x=0;x<16;x++)
				{
				if(!(x&3)) fprintf(fptr, "\r\n");
				fprintf(fptr, "0x%06lX, ", g_color_wheel_gen[t]);//0xffffff);
				t++;
				if(t>=COLOR_WHEEL_HYDRA_TOTAL) break;
				}
				fprintf(fptr, "\r\n};");

				fclose(fptr);
				}
			} 
			cclut_counter++;
			return 0;
		}

	// Find Closest Color /////////////////////////////////////////////////
	z_best = -1;
	z_value = 0;
	
		for(n=0;n<COLOR_WHEEL_HYDRA_TOTAL;n++)
		{
		r2 = (g_color_wheel_HYDRA[n]>>16)&0xff;
		g2 = (g_color_wheel_HYDRA[n]>>8)&0xff;
		b2 = (g_color_wheel_HYDRA[n])&0xff;

		z = (r2-r)*(r2-r)*g_bias_r+
			(g2-g)*(g2-g)*g_bias_g+
			(b2-b)*(b2-b)*g_bias_b;
		// closer value //
		if(z<z_value || z_best==-1) z_best = n, z_value = z;
		}

		/*
// 0x4D4FC0
    r2 = 77; //72;//(g_color_wheel_HYDRA[n]>>16)&0xff;
	g2 = 79; //72;//(g_color_wheel_HYDRA[n]>>8)&0xff;
	b2 = 192; //136;//(g_color_wheel_HYDRA[n])&0xff;

	z = (r2-r)*(r2-r)+
		(g2-g)*(g2-g)+
		(b2-b)*(b2-b);
	// closer value //
	if(z<z_value || z_best==-1) z_best = 1 + 3*16, z_value = z;
*/
	int c;

	if(z_best<16*5) 
	{
	c = ((z_best<<4)&0xf0) | (z_best>>4) + 0x08; // COLOR pixels.
	c+= g_phase;
	}
	else 
	{
	c = (z_best&0x0f) + 0x00; // B/W pixels
	if(c==0x00) c = 0x10; // if full black we put to black with the hue phase slightly off, so it's not treated as transparant.
	}
	
	return c&0xff;
}

/*int closest_color(float r, float g, float b)
{
	double y,i,q;
	float sat;
	double angle;
	int index;
	int luma;
	//
	//if(r-g < 5 && r-g > -5)
	//if(g-b < 5 && g-b > -5) return 15;

	r*=(double) 1/255; // scale down to 0-1 range
	g*=(double) 1/255;
	b*=(double) 1/255;
	
	// convert from RGB => YIQ
	// http://www.ee.washington.edu/conselec/CE/kuhn/ntsc/95x4.htm
	y = 0.3*r + 0.59*g + 0.11*b;
	i = 0.6*r - 0.28*g - 0.32*b; // orange-cyan 'X'
	q = 0.21*r - 0.52*g + 0.31*b; // green-purple 'Y'
	sat = sqrt(i*i + q*q); // saturation 0...1

	luma = 6+y*10; // 6..15
	if(luma<6) luma = 6;
	else if(luma>15) luma=15;

	if(sat<0.1) return (15<<4)|luma; // not enough saturation (<10%), we'll assume it's a gray shade
	
	angle = atan2(q,i); // atan (q/i) => -pi to pi (Starts From i = 1, q = 0, 57 degrees off Yellow Burst)
	if(angle<0) angle+=2*3.14159265359; // give an angle between 0 - 2pi.

	angle+= 57*(3.14159265359/180); // add 57 degrees (since our default reference is yellow)
	if(angle>2*3.14159265359) angle-=2*3.14159265359; // wrap around (incase the added angle exceeded 2pi "360")
	// phase: Color 
	// 0: Yellow (Burst)
	// 76: Red
	// 299: Green
	// 193: Blue
	angle*=(360/15)/(2*3.14159265359); // give angle as an index every 15 degrees 
	index = angle;
	// index will range between 0-23
	// for now, if a color is out of bounds then we lock it at the boundary color - cause it might just be slightly out
	if(index>19) index = 0; // 20...23 => 0
	else if(index>14) index=14; // 15..19 => 14
	
	//printf("%d",index);

	return (index<<4)|luma;
}*/

BYTE convert32BitToXGS(DWORD rgb)
{
	int r,g,b;
	int x;
	int luma;
	
	r = (rgb>>16)&255;
	g = (rgb>>8)&255;
	b = (rgb)&255;
	if(g_mode==XGS_HYDRA) 
	{
	if(rgb==g_color_trans) return 0x00; // Transparancy. HYDRA only.
	return closest_color_HYDRA(r,g,b);
	}
			
	return closest_color(r,g,b);
}

void output_file_hexRAW(int x)
{
	if(!g_output_file_hex_write) // suppress writing
	{
	g_output_file_hex_p++;
	g_output_file_hex_l++;
	return;
	}
	if(g_flag_bin)
	{
	//fprintf(g_output_file_fptr,"org\t$%03lx\r\n",g_output_file_hex_p);
	WORD val16;
	if(!g_output_file_hex_l) // fill with zero's up to the ORG on first time round //
	{
	int t;
	val16 = 0;
	for(t=0;t<g_output_file_hex_p;t++)
	fwrite(&val16, 2, 1, g_output_file_fptr);
	}
	
	val16 = x;

	if(g_output_file_hex_p<g_output_file_hex_limit)
	fwrite(&val16, 2, 1, g_output_file_fptr);
	}
else
{
	if(!g_output_file_hex_l) 
	{
	if(g_mode == XGS_HYDRA)
		{
		// No Org
		fprintf(g_output_file_fptr,"_%s\r\n",g_output_file_label);
		}
	else 
		{
		fprintf(g_output_file_fptr,"org\t$%03lx\r\n",g_output_file_hex_p);
		fprintf(g_output_file_fptr,"_%s\r\n",g_output_file_label);
		}
	}

	if(g_output_file_hex_p<g_output_file_hex_limit)
	{
	if(g_mode == XGS_HYDRA)
		{
		if(g_flag_asciimap) // tile maps to hydra
			{
			if(!g_output_file_hex_i) fprintf(g_output_file_fptr,"                        word    ");
			else fprintf(g_output_file_fptr,", ");
			fprintf(g_output_file_fptr,"$%04lx", x);
			if(g_output_file_hex_i==15) fprintf(g_output_file_fptr,"\r\n");	
			}
		else { // normal sprites/bitmaps to hydra
			if(!g_output_file_hex_i) fprintf(g_output_file_fptr,"                        byte    ");
			else fprintf(g_output_file_fptr,", ");
			fprintf(g_output_file_fptr,"$%02lx", x);
			if(g_output_file_hex_i==15) fprintf(g_output_file_fptr,"\r\n");
			}
		}
	else { // Micro/Pico
	if(!g_output_file_hex_i) fprintf(g_output_file_fptr,"\tdw\t");
	else fprintf(g_output_file_fptr,", ");
	fprintf(g_output_file_fptr,"$%03lx", x);
	if(g_output_file_hex_i==15) fprintf(g_output_file_fptr,"\r\n");
		}
	}
}
	if(g_output_file_hex_p<g_output_file_hex_limit)
	{
	g_output_file_hex_i++;
	g_output_file_hex_i&=15;
	g_output_file_hex_p++;
	g_output_file_hex_l++;
	}
	else g_output_file_limit_hit++;
}

void output_file_hex(int x) // RLE format saves the address of the next mode address in the upper 4 bits of the dw.
{
	int p;
	p = g_output_file_hex_p+1;
	p&=0xf00;
	output_file_hex(p|x);
}

void convertsrcXGS(char *fname)
{
	int x,y;
	int l;
	int ittr;
	BYTE c;
	DWORD *img_row;

	g_output_file_fptr = fopen(fname,"wb");
	g_output_file_hex_write = 0;

for(ittr=0;ittr<2;ittr++)
{
	g_output_file_hex_i = 0;
	g_output_file_hex_p = g_output_file_hex_org;
	g_output_file_hex_l = 0;
	
	img_row = img_buf;
	//printf("%06lx",img_row[0]);
	for(y=0;y<bmpi.height;y++)
	{
	x = 0;

	do {

	l = 0;
	c = convert32BitToXGS(img_row[x]);
	while(c==convert32BitToXGS(img_row[x]))
	{
	x++;
	l++;
	if(x==bmpi.width) break;
	}
	//printf("%d: %d run of %02x\n",y, l, c);
	if(l>1) // 2,3,4,5, etc. pixels we can render
	{
	l--;
	output_file_hex(0x00|l);
	}
	else { // 1 pixel we can't render. so we must render as 2 pixels. and skip the next pixel
	output_file_hex(0x00|l);
	if(x!=bmpi.width) x++; //
	}
	output_file_hex(0x00|c);


	} while(x!=bmpi.width);
	output_file_hex(0x00); // end of line
	
	
	img_row+=bmpi.width; // go up a line
	}
	output_file_hex(0x00); // end of image

	g_output_file_hex_write = 1; // now start writing //
	if(ittr==0) // write this first //
	{
		if(!g_flag_bin)
		{
		fprintf(g_output_file_fptr,"; Data Type: Run Length Encoded Bitmap\r\n");
		fprintf(g_output_file_fptr,"; Dimensions: %ldx%ld\r\n", bmpi.width, bmpi.height);
		fprintf(g_output_file_fptr,"; Size: %ld Words\r\n", g_output_file_hex_l);
		fprintf(g_output_file_fptr,"; Range: %03lX -> %03lX\r\n", g_output_file_hex_org, g_output_file_hex_p);
		}
	}
}	
	fclose(g_output_file_fptr);

	printf("Size: %ld words\n",g_output_file_hex_l);
}

void convertsrcXGSRAW(char *fname)
{
	g_output_file_fptr = fopen(fname,"wb");
	g_output_file_hex_write = 1;

	g_output_file_hex_i = 0;
	g_output_file_hex_p = g_output_file_hex_org;
	g_output_file_hex_l = 0;

	if(!g_flag_bin)
	{
	if(g_mode == XGS_HYDRA)
		{
	fprintf(g_output_file_fptr,"PUB data\r\n");
	fprintf(g_output_file_fptr,"RETURN @_%s\r\n\r\n",g_output_file_label);
	fprintf(g_output_file_fptr,"DAT\r\n");
	fprintf(g_output_file_fptr,"' Data Type: RAW Bitmap\r\n");
	fprintf(g_output_file_fptr,"' Dimensions: %ldx%ld\r\n", bmpi.width, bmpi.height);
	fprintf(g_output_file_fptr,"' Size: %ld Bytes\r\n", bmpi.height*bmpi.width);
	fprintf(g_output_file_fptr,"' Range: %lX -> %lX\r\n", g_output_file_hex_org, g_output_file_hex_org+bmpi.height*bmpi.width);
		}
	else {		// MICRO/PICO
	fprintf(g_output_file_fptr,"; Data Type: RAW Bitmap\r\n");
	fprintf(g_output_file_fptr,"; Dimensions: %ldx%ld\r\n", bmpi.width, bmpi.height);
	fprintf(g_output_file_fptr,"; Size: %ld Words\r\n", bmpi.height*bmpi.width);
	fprintf(g_output_file_fptr,"; Range: %03lX -> %03lX\r\n", g_output_file_hex_org, g_output_file_hex_org+bmpi.height*bmpi.width);
		}
	}

	int x,y;
	BYTE c;
	for(y=0;y<bmpi.height;y++)
	for(x=0;x<bmpi.width;x++)
	{
	c = convert32BitToXGS(img_buf[y*bmpi.width+x]);
	output_file_hexRAW(c);
	}

	fclose(g_output_file_fptr);
	if(g_mode == XGS_HYDRA) printf("Size: %ld bytes\n",g_output_file_hex_l);
	else printf("Size: %ld words\n",g_output_file_hex_l);
}

void generateSINEWAVE(char *fname)
{
	int n;
	DWORD c;
	float x,y;
	int iy;
	g_output_file_fptr = fopen(fname,"wb");
	g_output_file_hex_write = 1;

	if(!g_flag_bin)
	{
	fprintf(g_output_file_fptr,"; Data Type: Sine Wave\r\n");
	fprintf(g_output_file_fptr,"; Amplitude: %ld\r\n", g_sin_amp);
	fprintf(g_output_file_fptr,"; WaveLength: %ld\r\n", g_sin_wavelength);
	fprintf(g_output_file_fptr,"; Cut Off: >=%ld\r\n", g_sin_cut);
	}

	for(n=0;n<g_sin_cut;n++)
	{
	x = ((float) n)/((float) g_sin_wavelength);
	x*= 3.1415926535*2;
	y = sin(x);
	y*= (float) g_sin_amp;
	iy = y;
	// lock it
	if(iy>g_sin_amp) iy = g_sin_amp;
	else if(iy<-g_sin_amp) iy = -g_sin_amp;
	c = iy;
	c&=0xfff; // let the have 12-bit outputs. some people might actually use such precision.

	output_file_hexRAW(c);
	}

	fclose(g_output_file_fptr);
	printf("Size: %ld words\n",g_output_file_hex_l);
}

int g_ASCII_LUT[256]; // look up table for conversion of each ascii symbol
WORD g_ASCII_LINE[MAX_LINE_LENGTH];

void getcoords(char *str, int *x, int *y)
{
	int n;
	char c;
	char d;
	int arg_n;
	int start;
	arg_n = 0;
	start = -1;
	// default args
	*x = 0;
	*y = 0;
	for(n=0;n<80;n++)
	{
	c = str[n];
	if(c>='0' && c<='9') 
		{
		if(start==-1) start = n; // First number
		}
	else {
		if(start!=-1) { // First end
					// &str[start] -> &str[n-1]
					d = str[n]; // save

					str[n] = 0; // throw a terminator on it.
					//printf("{%d:%s}\n",arg_n,&str[start]);
					switch(arg_n)
						{
						case 0:sscanf(&str[start],"%d",x);
								break;
						case 1:sscanf(&str[start],"%d",y);
								break;
						}


					start = -1;					
					arg_n++;

					str[n] = d; // restore
					}
		}	
	if(!str[n]) break;
	}
}

void convertsrcXGSASCIIMAP(char *fname)
{
	char *tag;
	char *args;
	char *str;
	int x,y;
	int start;
	int arg_i[8];
	int arg_cnt;
	int arg_width;
	int arg_height;
	int arg_default;
	int arg_vram_width;
	int arg_vram_height;
	int arg_tile_width;
	int arg_tile_height;
	int error;
	int y_cnt;
	int tx,ty;
	for(x=0;x<256;x++) g_ASCII_LUT[x] = -1; // no mappings //


	g_output_file_fptr = fopen(fname,"wb");
	g_output_file_hex_write = 1;

	g_output_file_hex_i = 0;
	g_output_file_hex_p = g_output_file_hex_org;
	g_output_file_hex_l = 0;

	arg_default = 0;
	arg_vram_width = 128;
	arg_vram_height = 128;
	arg_tile_width = 1;
	arg_tile_height = 1;

	start = 0;
	arg_cnt = 0;
	y_cnt = 0;
	while(str = g_textfile->ReadLine(1))
	{
	if(!start) // START == 0 //
	{
	x = 0;
	while(str[x]<=32 && str[x]!=0) x++; // move to first solid space on line //
	if(!str[x]) continue; // empty line //
	tag = &str[x]; // make tag point to the start of the first solid space on line
	while(str[x]>32) x++; // move to first white space on line //
	y = x; // save this marker point //
	while(str[x]<=32 && str[x]!=0) x++; // move to second solid space on line //
	args = &str[x]; // make args point to start of second solid space on line.
	str[y] = 0; // throw a terminator at the marker point
	
	arg_cnt = 0;
	x = 0;
	while(1)
	{
		while(args[x]<=32 && args[x]!=0) x++; // move to next solid space on line //
		if(args[x]=='\'') // '
		{
		if(args[x+1]=='\\') {
							switch(args[x+2])
							{
							case 'r':arg_i[arg_cnt] = '\r';
									 break;
							case 'n':arg_i[arg_cnt] = '\n';
									 break;
							case 't':arg_i[arg_cnt] = '\t';
									 break;
							default:arg_i[arg_cnt] = args[x+2]; // "\?" => '?'
							}
							x++;
							}
		else arg_i[arg_cnt] = args[x+1];
		x+=3;
		} else if(args[x]!=0) { // number //
		if(args[x]=='$') sscanf(&args[x+1],"%lx",&y); // HEX
		else if(args[x]=='%') sscanf(&args[x+1],"%b",&y); // Binary
		else if(args[x]=='(') {
								getcoords(&args[x], &tx, &ty); // '(%d,%d)'
								y = (tx*arg_tile_width);
								y = arg_tile_height*(y/arg_tile_width) + y%arg_tile_width; // if x reference goes out side of tile map, jump down by 1 line - so people can use (t,0) to reference all tiles linearly.								
								y+= (ty*arg_tile_height)*arg_vram_width;
								}
		else sscanf(&args[x],"%ld",&y); // Assumed Decimal otherwise
		arg_i[arg_cnt] = y;		
		while(args[x]>32) x++; // move to white space
		} else { // All Args done //
		//printf("Tag: %s\n", tag);
		//for(y=0;y<arg_cnt;y++)
		//printf("Arg #%d: %ld\n", y, arg_i[y]);

		error = 0;
		if(!strcmpi(tag, "width")) {
									if(arg_cnt>=1) arg_width = arg_i[0];
									else error = 1;
									}
		else if(!strcmpi(tag, "height")) {
									if(arg_cnt>=1) arg_height = arg_i[0];
									else error = 1;
									}
		else if(!strcmpi(tag, "vram_width")) {
										if(arg_cnt>=1) arg_vram_width = arg_i[0];
									else error = 1;
									}
		else if(!strcmpi(tag, "vram_height")) {
										if(arg_cnt>=1) arg_vram_height = arg_i[0];
									else error = 1;
									}
		else if(!strcmpi(tag, "tile_width")) {
										if(arg_cnt>=1) arg_tile_width = arg_i[0];
									else error = 1;
									}
		else if(!strcmpi(tag, "tile_height")) {
										if(arg_cnt>=1) arg_tile_height = arg_i[0];
									else error = 1;
									}
		else if(!strcmpi(tag, "start")) start = 1;
		else if(!strcmpi(tag, "define")) {
									if(arg_cnt>=2) g_ASCII_LUT[arg_i[0]&0xff] = arg_i[1];
									else error = 2;
										}
		else if(!strcmpi(tag, "default")) {
									if(arg_cnt>=1) arg_default = arg_i[0];
									}
		else printf("(Line %d) Error: Unhandled tag: '%s'\n", g_textfile->m_line_i, tag);

		if(error)
		{
		printf("(Line %d) Error: Insufficient args for tag '%s', requires %d args\n", g_textfile->m_line_i, tag, error);
		}

		break;
		}
		arg_cnt++;
	} // end while
		
	if(start)
		{
		printf("Converting Map (%ldx%ld)\n", arg_width, arg_height);
		printf("Character Mappings:\n");
		for(x=0;x<256;x++) 
		if(g_ASCII_LUT[x]!=-1)
		{
		printf("%c (%d) -> $%lx\n", x, x, g_ASCII_LUT[x]);
		}

		if(!g_flag_bin)
		{
			
		if(g_mode==XGS_HYDRA)
			{
			fprintf(g_output_file_fptr,"PUB data\r\n");
			fprintf(g_output_file_fptr,"RETURN @_%s\r\n\r\n",g_output_file_label);
			fprintf(g_output_file_fptr,"DAT\r\n");
			fprintf(g_output_file_fptr,"' Data Type: RAW MAP\r\n");
			fprintf(g_output_file_fptr,"' Dimensions: %ldx%ld\r\n", arg_width, arg_height);
			fprintf(g_output_file_fptr,"' Size: %ld Words\r\n", arg_width*arg_height);
			fprintf(g_output_file_fptr,"' Range: %lX -> %lX\r\n", g_output_file_hex_org, g_output_file_hex_org+arg_width*arg_height);
			}
		else {
		fprintf(g_output_file_fptr,"; Data Type: RAW MAP\r\n");
		fprintf(g_output_file_fptr,"; Dimensions: %ldx%ld\r\n", arg_width, arg_height);
		fprintf(g_output_file_fptr,"; Size: %ld Words\r\n", arg_width*arg_height);
		fprintf(g_output_file_fptr,"; Range: %03lX -> %03lX\r\n", g_output_file_hex_org, g_output_file_hex_org+arg_width*arg_height);
			}
		}


		}
	} else // START == 1 //
	{
	for(x=0;x<arg_width;x++)
	{
	if(!str[x]) break; // the line ended abruptly
	if(g_ASCII_LUT[str[x]]==-1) g_ASCII_LINE[x] = str[x]; // if there is no mapping just copy the character value over
	else g_ASCII_LINE[x] = g_ASCII_LUT[str[x]]; // convert it based on the mapping table
	}
	for(x=x;x<arg_width;x++) // fill the rest of the line with the default entry. - default entry defaults to 0.
	g_ASCII_LINE[x] = arg_default;
	
	for(x=0;x<arg_width;x++) // write this to the file //
	output_file_hexRAW(g_ASCII_LINE[x]);

	y_cnt++;
	if(y_cnt==arg_height) start = 0, y_cnt = 0;
	}

	} // end while

	fclose(g_output_file_fptr);
	printf("Size: %ld words\n",g_output_file_hex_l);
}

#define OPCODE_OR				0
#define OPCODE_AND				1
#define OPCODE_ADD				2
#define OPCODE_SUB				3
#define OPCODE_REPLACENOTZERO	4

void convertsrcXGSCOMBINE(char *src1, char *src2, char *dest)
{
	FILE *fptr[2];
	int fno[2];
	int length[2];
	int n;
	int i;
	char *fname[2];
	int max_length;
	BYTE *buffer;
	BYTE *buffer2;
	int opcode;
	fname[0] = src1;
	fname[1] = src2;

	for(n=0;n<2;n++)
	{
	fptr[n] = fopen(fname[n],"rb");
	if(!fptr[n])
	{
	printf("File not found '%s'\n",fname[n]);
	return;
	}
	fno[n] = fileno(fptr[n]);
	length[n] = filelength(fno[n]);
	}

	// get max length //
	if(length[0]>length[1]) max_length = length[0];
	else max_length = length[1];

	buffer = new BYTE[max_length]; // destination
	buffer2 = new BYTE[length[1]]; // src2

	opcode = -1;

	if(!strcmpi(g_op_arg, "or")) opcode = OPCODE_OR;
	else if(!strcmpi(g_op_arg, "and")) opcode = OPCODE_AND;
	else if(!strcmpi(g_op_arg, "add")) opcode = OPCODE_ADD;
	else if(!strcmpi(g_op_arg, "sub")) opcode = OPCODE_SUB;
	else if(!strcmpi(g_op_arg, "replacenotzero")) opcode = OPCODE_REPLACENOTZERO;

	printf("Max Length: %ld words\n", max_length/2);
	if(opcode==-1) {
		printf("Error: Unknown Operation '%s'", g_op_arg);
		return;
		}
	printf("Operation: %s = %s %s %s\n", dest, src1, g_op_arg, src2);
	
	memset(buffer, 0, max_length); // clear buffer out first with 0's
	// copy src1 over first //
	fread(buffer, length[0], 1, fptr[0]);
	fclose(fptr[0]);
	// copy src2 into second buffer //
	fread(buffer2, length[1], 1, fptr[1]);
	fclose(fptr[1]);

	BYTE arg1, arg2, y;

	for(i=0;i<length[1];i++) 
		{
		arg1 = buffer[i];
		arg2 = buffer2[i];
		switch(opcode)
			{
			case OPCODE_OR:arg1|=arg2;
						   break;
			case OPCODE_AND:arg1&=arg2;
						   break;
			case OPCODE_ADD:arg1+=arg2;
						   break;
			case OPCODE_SUB:arg1-=arg2;
						   break;
			case OPCODE_REPLACENOTZERO:if(arg2) arg1=arg2;
										break;
			}		
		buffer[i] = arg1;
		}

	// output to our destination file now.

	g_output_file_fptr = fopen(dest,"wb");
	g_output_file_hex_write = 1;

	g_output_file_hex_i = 0;
	g_output_file_hex_p = g_output_file_hex_org;
	g_output_file_hex_l = 0;

	if(!g_flag_bin)
		{
		fprintf(g_output_file_fptr,"; Data Type: Combined Data\r\n");
		fprintf(g_output_file_fptr,"; Size: %ld Words\r\n", max_length/2);
		fprintf(g_output_file_fptr,"; Range: %03lX -> %03lX\r\n", g_output_file_hex_org, g_output_file_hex_org+max_length/2);
		}

	WORD *p16;
	p16 = (WORD *) buffer;

	for(i=0;i<max_length/2;i++)
	{
	output_file_hexRAW(p16[i]);
	}

	fclose(g_output_file_fptr);
	printf("Size: %ld words\n",g_output_file_hex_l);

	delete buffer2;
	delete buffer;
}
