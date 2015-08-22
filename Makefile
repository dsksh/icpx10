TARGET		= Optimizer

all: $(TARGET)

## NOTE: the C++ compiler must match the one configured for x10c++.
CC          = g++
BUILD       = ar rs    # for static libraries
CFLAGS      += -O0 -g $(INCLUDES)
#CFLAGS      += -g -O3 -Wall
CFLAGS		+= $(shell pkg-config --cflags ibex)
LDFLAGS		+= $(shell pkg-config --libs  ibex)

X10_SOURCES		= $(wildcard *.x10)
X10_SOURCES		+= $(wildcard glb/*.x10)
X10_HEADERS     = IbexAdapter__Core.h util.h innerVerification.h config.h
X10_CPP_SOURCES = IbexAdapter__Core.cc innerVerification.cc

%.o:%.cc
	$(CC) $(CFLAGS) -c $< -o $@


## X10 STUFF ##
X10CXX          = x10c++
#X10CXX		    += -VERBOSE_CHECKS
#X10CXX		    += -STATIC_CHECKS
#X10CXX         += -x10rt mpi
#X10CXX		    += -O
X10CXX         += -NO_CHECKS
X10CXX         += -report postcompile=1
X10CXX         += -debugpositions
OUTDIR          = out_dir
OUTDIR_REVERSE  = ..

X10_POST_CMD    = \# \# $(CFLAGS) -I . \# -L . $(LDFLAGS) 

Main: $(X10_HEADERS) $(X10_SOURCES) $(X10_CPP_SOURCES)
	$(X10CXX) Main.x10 -d $(OUTDIR) -post '$(X10_POST_CMD)' -o Main

Optimizer: $(X10_HEADERS) $(X10_SOURCES) $(X10_CPP_SOURCES)
	$(X10CXX) Optimizer.x10 -d $(OUTDIR) -post '$(X10_POST_CMD)' -o Optimizer

.makedirs: $(X10_HEADERS) $(X10_SOURCES) $(X10_CPP_SOURCES) $(SAT_HEADERS)
	touch .makedirs
	mkdir -p $(OUTDIR)/$(SAT_X10_WRAPPERS_DIR)
	mkdir -p $(OUTDIR)/$(MINISAT_2.2.0_BASE)/{core,mtl,utils}

clean:
	rm -f $(TARGET)
	rm -fr .makedirs $(OUTDIR)
