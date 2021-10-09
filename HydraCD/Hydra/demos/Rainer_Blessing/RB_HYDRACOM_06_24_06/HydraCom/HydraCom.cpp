#if ( GPIB )
# include "wx/ctb/gpib.h"
#endif
#include "wx/ctb/iobase.h"
#include "wx/ctb/serport.h"
#include "wx/ctb/timer.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wx/file.h>
#include <wx/utils.h>
#include <wx/cmdline.h>
#include <wx/msgout.h>
#include <wx/app.h>
#include <wx/log.h>
#include <iostream>

using namespace std;
// HydraCom 0.2
// Author: Rainer Blessing

// ----------------- globals -------------------------------
wxBaud baudrate = wxBAUD_115200;
wxString filename;
char *devname = wxCOM3;
int timeout = 1000;
const char SOH =0x01;
const char EOT =0x04;
const char ACK =0x06;
const char NAK =0x15;
const char ETB =0x17;

int calcrc(char *ptr, int count)
{
    int  crc;
    char i;

    crc = 0;
    while (--count >= 0)
    {
        crc = crc ^ (int) *ptr++ << 8;
        i = 8;
        do
        {
            if (crc & 0x8000)
                crc = crc << 1 ^ 0x1021;
            else
                crc = crc << 1;
        } while(--i);
    }
    return (crc);
}

int main(int argc,char* argv[])
{
    int quit = 0;
    int val;
    wxMessageOutput::Set(new wxMessageOutputStderr());
    
	#if wxUSE_UNICODE
    	wxChar **wxArgv = new wxChar *[argc + 1];

    	{
        	int n;

	        for (n = 0; n < argc; n++ )
    	    {
        	    wxMB2WXbuf warg = wxConvertMB2WX(argv[n]);
            	wxArgv[n] = wxStrdup(warg);
	        }

    	    wxArgv[n] = NULL;
		}
	#else // !wxUSE_UNICODE
    	#define wxArgv argv
	#endif // wxUSE_UNICODE/!wxUSE_UNICODE

	wxApp::CheckBuildOptions(WX_BUILD_OPTIONS_SIGNATURE, "program");
	
	  static const wxCmdLineEntryDesc cmdLineDesc[] =
  {
    { wxCMD_LINE_SWITCH,"s","send","send file" },
    { wxCMD_LINE_SWITCH,"r","receive","receive file" },
    { wxCMD_LINE_SWITCH,"h","help","print usage" },
    { wxCMD_LINE_OPTION,"c","port","serial port (default COM3)",wxCMD_LINE_VAL_NUMBER },    
    { wxCMD_LINE_PARAM,  NULL, NULL, "filename", wxCMD_LINE_VAL_STRING, wxCMD_LINE_PARAM },
    { wxCMD_LINE_NONE }
  };

  wxCmdLineParser parser(cmdLineDesc, argc, wxArgv);

    switch ( parser.Parse() )
    {
        case -1:
            wxLogMessage(_T("Help was given, terminating."));
            break;

        case 0:
            break;

        default:
            wxLogMessage(_T("Syntax error detected, aborting."));
            break;
    }

    if(parser.Found("h")||argc==1){
    	 parser.Usage();
    	 exit(0);
    }

    long port;
    if(parser.Found("c",&port)){
    	switch(port){
    		case 1:
		    	devname=wxCOM1;
		    	break;		    	
    		case 2:
		    	devname=wxCOM2;
		    	break;
    		case 3:
		    	devname=wxCOM3;		    	
		    	break;
    		case 4:
		    	devname=wxCOM4;	
		    	break;	    	
    		case 5:
		    	devname=wxCOM5;	
		    	break;	    	
    		case 6:
		    	devname=wxCOM6;	
		    	break;	    	
		    	
    		default:    		
   				std::cout<<"COM1-COM6 only"<<std::endl;
   		    	exit(0);
    	}
    }
    
    // like a virtual instrument in NI
    wxIOBase* dev;

#if ( GPIB )
    if(!strncmp(devname,wxGPIB1,strlen(wxGPIB1))) {
	   // device is GPIB
	   dev = new wxGPIB();
	   // try to open the device at address 1 (default)
	   if(dev->Open(devname) < 0) {
		  printf("Cannot open %s\n",devname);
		  delete dev;
		  return -1;
	   }
    }
    else {
#endif
	   // device is a serial port
	   dev = new wxSerialPort();
	   // try to open the given port
	   if(dev->Open(devname) < 0) {
		  printf("Cannot open %s\n",devname);
		  delete dev;
		  return -1;
	   }
	   // set the baudrate
	   ((wxSerialPort*)dev)->SetBaudRate(baudrate);
#if ( GPIB )
    }
#endif
    // ok, device is ready for communication
    
    int packetno=1;
    char packet[132];
        
    char data[128];
    char start=0;

    wxString filename;
    filename=parser.GetParam(0);    
        
    if(parser.Found("s")){
    	if(!wxFile::Exists(filename)){
 	  		printf("File does not exist: %s\n",filename.c_str());
    	   	return -1;
	    }
    wxFile file(filename,wxFile::read);
    packet[0]=ACK;
    dev->Write(packet,1); 
 
    while(start!='C'){
    	dev->Read(&start,1);
    	wxMilliSleep(10);    	
    }
    wxMilliSleep(100);
   
	int read;
	int total=0;
    memset (data,0,128);
    while((read=file.Read(data,128))>0){
    	total+=read;
    	memset (packet,0,133);
	    packet[0]=SOH;
	    packet[1]=packetno&0xff;
	    packet[2]=(packetno&0xff)^0xff;
	    packetno++;
	    memcpy(packet+3,data,128);
    	packet[131]=calcrc(data,128)&0xff;
    	packet[132]=calcrc(data,128)&0xff00>>8;
	    dev->Write(packet,133);	    
       	memset (data,0,128);
       	start=0;
	    while(data[0]!=ACK){
	    	dev->Read(&data[0],1);
    		wxMilliSleep(10);
    	}
    	if(read<128)break;
    	std::cout<<"Send Bytes: "<<total<<std::endl;
    }
    file.Close();   
    packet[0]=EOT;
    dev->Write(packet,1);    
    start=0;	
    while(start!=ACK){
	  	dev->Read(&start,1);
	    wxMilliSleep(10);    	
    }
    }else if(parser.Found("r")){
   	    wxFile file(filename,wxFile::write);   	    	  
       	 packet[0]=NAK;
         dev->Write(packet,1);
         packet[0]='C';         
         dev->Write(packet,1);
         
		 memset (packet,0,133);
         dev->Readv(packet,1,0);
         int total=0;
    	 while(packet[0]!=EOT){    	 	
		    if(packet[0]==SOH){
	        	dev->Readv(packet,132,0);
	        	total+=128;
	        	std::cout<<"Received Bytes: "<<total<<std::endl;
	    	    memcpy(data,packet+2,128);	    	    
		    	file.Write(data,128);
		   		packet[0]=ACK;
			    dev->Write(packet,1);
	        }
		    dev->Readv(packet,1,0);
		}
		// EOT
	   	packet[0]=ACK;
	    dev->Write(packet,1);   	 		
        file.Close();
    }
    dev->Close();
    delete dev;
    return 0;
}
