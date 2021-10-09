IDIR =include
CC=g++


ODIR=obj
LDIR =lib
WXDIR =c:/wxWidgets-2.6.3
MINGWDIR =c:/MinGW
LIBS=-lwxctb-0.8 -lwxbase26d  -lkernel32 -luser32 -lgdi32 -lole32 -luuid
CFLAGS=-I$(IDIR) -L$(LDIR) -L$(WXDIR)/lib/gcc_lib -I$(WXDIR)/include -L$(MINGWDIR)/lib -DwxUSE_GUI=0 -D__WXMSW__ -D__WXDEBUG__ -DHAVE_W32API_H

#_DEPS = hellomake.h
#DEPS = $(patsubst %,$(IDIR)/%,$(_DEPS))

_OBJ = HydraCom.o
OBJ = $(patsubst %,$(ODIR)/%,$(_OBJ))


$(ODIR)/%.o: %.cpp $(DEPS)
	$(CC)  -c -o $@ $< $(CFLAGS)

all: HydraCom

HydraCom: $(OBJ)
	$(CC) -o $@ $^ $(CFLAGS) $(LIBS)

.PHONY: clean

clean:
	rm -f $(ODIR)\*.o *~ core $(INCDIR)\*~ HydraCom.exe