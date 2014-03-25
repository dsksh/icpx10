TARGET		= RPX10

all: $(TARGET)

##
#RP_HOME	= /Users/ishii/workspace/realpaver-1.1hgsvn

## NOTE: the C++ compiler must match the one configured for x10c++.
CC          = g++
BUILD       = ar rs    # for static libraries
INCLUDES	+= -I$(RP_HOME)/src
CFLAGS      += -O0 -g $(INCLUDES)
#CFLAGS      += -O3 -arch i386 -arch x86_64
#CFLAGS      += -g -O3 -Wall
#CFLAGS      += -pg -O0
LDFLAGS     += -L$(RP_HOME)/src -lrealpaver -lgaol -lgdtoa -lultim

X10_HEADERS     = RPX10__Core.h RPX10__CoreProj.h RPX10__CoreEx.h RPX10__CoreIArray.h RPX10__CoreIMap.h
X10_SOURCES     = RPX10.x10 PlaceAgent.x10 PlaceAgentSeparated.x10 PlaceAgentClocked.x10 PlaceAgentSenderInitiated.x10 PlaceAgentDelayed.x10 PlaceAgentMSplit.x10 BAPSolver.x10 BAPListSolver.x10 BAPListSolverBnd.x10 BAPSolverSimple.x10 BAPSolverMSplit.x10 VariableSelector.x10 Interval.x10 IntervalVec.x10 IntervalArray.x10 IntervalMap.x10 CircularQueue.x10 MyHashMap.x10
X10_CPP_SOURCES = RPX10__Core.cc RPX10__CoreProj.cc RPX10__CoreIArray.cc RPX10__CoreIMap.cc

%.o:%.cc
	$(CC) $(CFLAGS) -c $< -o $@


## X10 STUFF ##
X10CXX          = x10c++
#X10CXX		   += -STATIC_CHECKS
X10CXX         += -x10rt mpi
#X10CXX		   += -O
X10CXX         += -NO_CHECKS
X10CXX         += -report postcompile=1
OUTDIR          = out_dir
OUTDIR_REVERSE  = ..

X10_POST_CMD    = \# \# $(CFLAGS) -I . \# -L . $(LDFLAGS) 

RPX10: $(X10_HEADERS) $(X10_SOURCES) $(X10_CPP_SOURCES)
	$(X10CXX) RPX10.x10 -d $(OUTDIR) -post '$(X10_POST_CMD)' -o RPX10

Test: $(X10_HEADERS) $(X10_SOURCES) $(X10_CPP_SOURCES)
	$(X10CXX) Test.x10 -d $(OUTDIR) -post '$(X10_POST_CMD)' -o Test

#SatX10.standalone: $(X10_HEADERS) $(X10_SOURCES) $(X10_CPP_SOURCES) $(SAT_HEADERS) $(SAT_LIBS) .makedirs
#	$(X10CXX) SatX10.x10 -d $(OUTDIR) -x10rt standalone -post '$(X10_POST_CMD)' -o SatX10.standalone
#
#SatX10.pami: $(X10_HEADERS) $(X10_SOURCES) $(X10_CPP_SOURCES) $(SAT_HEADERS) $(SAT_LIBS) .makedirs
#	$(X10CXX) SatX10.x10 -d $(OUTDIR) -x10rt pami -post '$(X10_POST_CMD)' -o SatX10.pami

.makedirs: $(X10_HEADERS) $(X10_SOURCES) $(X10_CPP_SOURCES) $(SAT_HEADERS)
	touch .makedirs
	mkdir -p $(OUTDIR)/$(SAT_X10_WRAPPERS_DIR)
	mkdir -p $(OUTDIR)/$(MINISAT_2.2.0_BASE)/{core,mtl,utils}

clean:
	rm -f $(TARGET)
	rm -fr .makedirs $(OUTDIR)
