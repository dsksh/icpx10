import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicInteger;

public class PlaceAgentSenderInitiated[K] extends PlaceAgent[K] {

    val nDestinations:Int;
    val nBoxes:Int;
    val nBoxesMin:Int;
    var nBoxesMax:Int;

    private var tester : VariableSelector.Tester[K] = null;
    private var solverPP : BAPSolverSimple[K] = null;
    val listShared:List[IntervalVec[K]];

    // information of the distribution route tree.
    var idRoute:Int;
    var sizeFrontier:Int;
    //var sizeRouteTree:Int;
    val sizeRouteTree:List[Int];

    var minVolume:Double;

    public def this(solver:BAPSolver[K]) {
        super(solver);

		val gND = new GlobalRef(new Cell[Int](0));
		val gNBM = new GlobalRef(new Cell[Int](0));
		val gDD = new GlobalRef(new Cell[Int](0));
		at (Place(0)) {
   			val sND = System.getenv("RPX10_N_DESTINATIONS");
   			val sNBM = System.getenv("RPX10_N_BOXES_MIN");
   			val sDD = System.getenv("RPX10_DIST_DELAY");
			val nD:Int = sND != null ? Int.parse(sND) : 2;
			val nBM:Int = sNBM != null ? Int.parse(sNBM) : 32;
			val nDD:Int = sDD != null ? Int.parse(sDD) : 0;
			at (gND.home) {
				gND().set(nD);
				gNBM().set(nBM);
				gDD().set(nDD);
            }
		}
    	nDestinations = gND().value;
    	nBoxesMin = gNBM().value;
    	val distDelay = gDD().value;
        nBoxes = nBoxesMin * nDestinations;
        nBoxesMax = nBoxes;

        listShared = new ArrayList[IntervalVec[K]]();

        val sizeRTCache = new ArrayList[Int](distDelay);
        for (0..(distDelay-1))
            sizeRTCache.add(1);

        idRoute = here.id()+1;
        sizeFrontier = nDestinations;
        var sizeRT:Int = 1;
        while (sizeRT < idRoute) {
            sizeRT += sizeFrontier;
            sizeFrontier *= nDestinations;
        }
        sizeRTCache.add(sizeRT);

        sizeRouteTree = sizeRTCache;

        initPhase = false;
    }

    def updateSizeRouteTree() {
        idRoute += Place.numPlaces();
        var sizeRT:Int = sizeRouteTree.removeFirst();
        while (sizeRT < idRoute) {
            sizeRT += sizeFrontier;
            sizeFrontier *= nDestinations;
        }
        sizeRouteTree.add(sizeRT);
    }

    public def initPP(core:BAPSolver.Core[K], prec:Double) {

        // create solverPP.

        tester = new VariableSelector.Tester[K]();
        val test = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => 
                        tester.testPrec(prec, res, box, v);

        val selector = new VariableSelector[K](test);
        val select = (res:BAPSolver.Result, box:IntervalVec[K])=>selector.selectLRR(res, box);
        val select1 = (res:BAPSolver.Result, box:IntervalVec[K])=>selector.selectBoundary(select, res, box);
        
        solverPP = new BAPSolverSimpleUnsafe(core, select1);
        solverPP.setList(list);
        //solverPP.nBoxesMax = nBoxes;
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        //super.setup(sHandle);
        list.add(solver.core.getInitialDomain());

        initPhase = true;
    }

    private val random:Random = new Random(System.nanoTime());
    //private var selected:Iterator[Place] = null;
    private var selected:Iterator[Int] = null;

    protected def selectPlace() : Place {
        //var id:Int = random.nextInt(nDestinations-1);

        if (selected == null || !selected.hasNext()) 
            selected = (0..(nDestinations-1)).iterator();
        var id:Int = selected.next();

        id = (id + (nDestinations*here.id()+1)) % Place.numPlaces();
//debugPrint(here + ": selected " + id);
        return Place(id);
    }

    public def respondIfRequested(sHandle:PlaceLocalHandle[PlaceAgent[K]], 
                                  box:IntervalVec[K]) : Boolean {
        return false;
    }


    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
   		debugPrint(here + ": start solving... ");

        clocked 
        finish {

            // search task
            clocked 
            async search(sHandle);
    
            // termination
            clocked 
            async terminate(sHandle);

        } // finish
    }

    public def search(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        while (terminate != 3) {
            var activated:Boolean = false;
            atomic if (initPhase || list.size()+listShared.size() >= nBoxesMin) {
debugPrint(here + ": activated: " + initPhase + ", " + (list.size()+listShared.size()) + ", " + idRoute);
                activated = true;

                initPhase = false;

                // append the two lists.
                for (box in listShared)
                    list.add(box);

                // reset
                listShared.clear();
            }

            if (activated) {

                sortDom();
    
                while (!list.isEmpty() && list.size() < nBoxesMax) {
                    val box = removeDom();
                    solverPP.search(sHandle, box);
                }
    
                sortDom();
    
                //val sizeFullTree = (idRoute >= 0) ? Math.pow(nDestinations, ((Math.log(idRoute)/Math.log(nDestinations)) as Int)+1) as Int : 1;
//debugPrint(here + ": estimate: " + sizeRouteTree);
                if (sizeRouteTree.getFirst() < Place.numPlaces()) {
                    updateSizeRouteTree();
                    finish for (i in 1..list.size()) {
                        val box = removeDom();
                        val pv:Box[K] = box.prevVar();
                        val p = selectPlace();
                        async at (p) {
                            box.setPrevVar(pv);
                            atomic (sHandle() as PlaceAgentSenderInitiated[K]).listShared.add(box);
                        }
                        if (p.id() < here.id()) sentBw.set(true);
                        nSends++;
                    }
sHandle().tEndPP = System.nanoTime();
                }
                else {
                    nBoxesMax = Math.max(nBoxes, list.size())*2;
                }

debugPrint(here + ": search done, " + list.size());

                if (here.id() == 0) atomic
                    if (list.isEmpty() && terminate == 0) {
debugPrint(here + ": start termination");
                        terminate = 1;
                    }
            }
            else System.sleep(1);

			Clock.advanceAll();
        }

debugPrint(here + ": search finished");
    }

    def terminate(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        var term:Int = 0;
    
		while (initPhase) {
			Clock.advanceAll();
		}

        while (term != 3) {

			Clock.advanceAll();

            var termBak:Int = 0;
            //when (list.isEmpty() && term != terminate) {
            var activated:Boolean = false;
            atomic if (list.isEmpty() && term != terminate) {
            //atomic {
debugPrint(here + ": terminate: " + terminate);
                activated = true;

                termBak = terminate;
                if (here.id() == 0 && terminate == 2)
                    terminate = 3;
                else if (here.id() == 0 && terminate == 4)
                    terminate = 1;
                else if (here.id() > 0 && terminate != 3) 
                    terminate = 1;
    
                term = terminate;
            }

            if (activated) {
    
            // begin termination detection
            if (here.id() == 0 && term == 1) {
                at (here.next()) atomic {
                    sHandle().terminate = 2;
                    // put a dummy box
                    //sHandle().list.add(sHandle().solver.core.dummyBox());
                }
debugPrint(here + ": sent token 2 to " + here.next());
            }
            // termination token went round.
            else if (here.id() == 0 && term == 3) {
                at (here.next()) atomic {
                    sHandle().terminate = 3;
                    //sHandle().list.add(sHandle().solver.core.dummyBox());
                    //sHandle().initPhase = true;
                }
debugPrint(here + ": sent token 3 to " + here.next());
            }
            else if (here.id() > 0) {
                val v = (termBak == 2 && sentBw.getAndSet(false)) ? 4 : termBak;
                //atomic terminate = 0;
                at (here.next()) atomic {
                    sHandle().terminate = v;
                    //sHandle().list.add(sHandle().solver.core.dummyBox());
                    //if (v == 3) sHandle().initPhase = true;
                }
debugPrint(here + ": sent token " + v + " to " + here.next());
    
                //if (term != 3)
                //    atomic terminate = 1;
            }

            }
        }

debugPrint(here + ": terminate finished");
    }

}

// vim: shiftwidth=4:tabstop=4:expandtab
