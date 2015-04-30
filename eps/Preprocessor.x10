import x10.util.*;

public class Preprocessor[K] {

    static def initSolver[K](core:BAPSolver.Core[K], prec:Double) {

        val tester = new VariableSelector.Tester[K]();
        val test = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => 
                        tester.testPrec(prec, res, box, v);

        val selector = new VariableSelector[K](test);
        val select = (res:BAPSolver.Result, box:IntervalVec[K])=>selector.selectLRR(res, box);
        val select1 = (res:BAPSolver.Result, box:IntervalVec[K])=>selector.selectBoundary(select, res, box);
        
        return new BAPSolverImpl(core, select1);
    }


    val nDestinations:Long;
    val nBoxes:Long;
    val nBoxesMin:Long;
    var nBoxesMax:Long;

    private val solver : BAPSolverImpl[K];

    var active:Boolean;

    public def this(core:BAPSolver.Core[K], prec:Double, pa:PlaceAgent[K]) {
        solver = initSolver[K](core, prec);
        solver.setList(pa.list);

        // read env variables.
		val gND  = new GlobalRef(new Cell[Long](0));
		val gNBM = new GlobalRef(new Cell[Long](0));
		val gDD  = new GlobalRef(new Cell[Long](0));
		at (Place(0)) {
   			val sND  = System.getenv("RPX10_N_DESTINATIONS");
   			val sNBM = System.getenv("RPX10_N_BOXES_MIN");
   			val sDD  = System.getenv("RPX10_DIST_DELAY");
			val nD :Long = sND != null ? Long.parse(sND) : 2;
			val nBM:Long = sNBM != null ? Long.parse(sNBM) : 32;
			val nDD:Long = sDD != null ? Long.parse(sDD) : 0;
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


		// setup the selectPlace parameters.
		var nth:Long = 1;
		while (nth <= here.id()) nth *= nDestinations;
		selectCoeff = nth;

		selectOffset = here.id();		
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        active = true;
    }


    public def process(sHandle:PlaceLocalHandle[PlaceAgent[K]]) : Boolean {
        if (selectCoeff >= Place.numPlaces()) {
            return false;
        }

sHandle().debugPrint(here + ": wait");
        when (sHandle().active) {
            active = false;
        }

        sHandle().joinTwoLists();
        sHandle().sortDom();

        // perform BFS.
        while (!sHandle().list.isEmpty() && sHandle().list.size() < nBoxesMax) {
            //val box = sHandle().removeDom();
            val box = sHandle().list.removeFirst();
            solver.search(sHandle, box);
        }

        sHandle().sortDom();

sHandle().debugPrint(here + ": search done, " + sHandle().list.size());

        val sets = new ArrayList[List[IntervalVec[K]]](nDestinations);
        for (1..nDestinations) {
            val l = new ArrayList[IntervalVec[K]]();
            sets.add(l);
        }

        for (i in 1..sHandle().list.size()) {
            val box = sHandle().removeDom();
            sets((i-1) % nDestinations).add(box);
        }

        for (bs in sets) {
            val p = selectPlace();
sHandle().debugPrint(here + ": sending to: " + p);

            if (p.id() <= here.id()) {
                sHandle().joinWithListShared(bs);
	            atomic sHandle().active = true;
            }
            else {
                async at (p) {
                    sHandle().joinWithListShared(bs);
    	            atomic sHandle().active = true;
                }
    
                sHandle().nSends.incrementAndGet();
            }
        }

        updateRouteInfo();

        return true;
    }


    private val random:Random = new Random(System.nanoTime());
    private var selectedPid:Long = 0;
	private var selectCoeff:Long = 1;
	private var selectOffset:Long = 0;

    protected def selectPlace() : Place {
        // round-robin selection.
        val id = selectedPid++;
        if (selectedPid == nDestinations) selectedPid = 0;

		return Place( (selectCoeff*id + selectOffset) % Place.numPlaces() );
    }

    def updateRouteInfo() {
		selectCoeff *= nDestinations;
    }


    // kludge for a success of compilation
    val dummy:Double = 0.;
    val dummyI:Interval = new Interval(0.,0.);
    val dummyR:BAPSolver.Result = BAPSolver.Result.unknown();
}

// vim: shiftwidth=4:tabstop=4:expandtab
