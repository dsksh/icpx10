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

    val list:List[IntervalVec[K]];

    // information of the distribution route tree.
    val sizeRouteTree:List[Long];

    var minVolume:Double;

    var active:Boolean;

    public def this(core:BAPSolver.Core[K], prec:Double, pa:PlaceAgent[K]) {
        this.list = pa.list;

        solver = initSolver[K](core, prec);
        solver.setList(list);

        // read env variables.
		val gND = new GlobalRef(new Cell[Long](0));
		val gNBM = new GlobalRef(new Cell[Long](0));
		val gDD = new GlobalRef(new Cell[Long](0));
		at (Place(0)) {
   			val sND = System.getenv("RPX10_N_DESTINATIONS");
   			val sNBM = System.getenv("RPX10_N_BOXES_MIN");
   			val sDD = System.getenv("RPX10_DIST_DELAY");
			val nD:Long = sND != null ? Long.parse(sND) : 2;
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
		var pow:Long = 1;
		while (pow <= here.id()) pow *= nDestinations;
		selectCoeff = pow;
		selectOffset = here.id();		

		// setup the tree size information.
        val sizeRTCache = new ArrayList[Long](distDelay);
        for (0..(distDelay-1))
            sizeRTCache.add(1);

        sizeRTCache.add(selectCoeff);

        sizeRouteTree = sizeRTCache;

        //active = false;
        active = pa.active;
    }

    def updateSizeRouteTree() {
		selectCoeff *= nDestinations;
		//selectOffset *= nDestinations;

        sizeRouteTree.removeFirst();
        sizeRouteTree.add(selectCoeff);
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        active = true;
    }

    private val random:Random = new Random(System.nanoTime());
    private var selectedPid:Long = 0;
	private var selectCoeff:Long = 1;
	private var selectOffset:Long = 0;

    protected def selectPlace() : Place {
        // random selection.
        //val id = random.nextInt(nDestinations-1);

        // round-robin selection.
        if (selectedPid == nDestinations) selectedPid = 0;
        val id = selectedPid++ % nDestinations;

		return Place( (selectCoeff*id + selectOffset) % Place.numPlaces() );
    }

	//var activated:Boolean = false;

    public def process(sHandle:PlaceLocalHandle[PlaceAgent[K]]) : Boolean {
		//if (!activated) when (sHandle().active) activated = true;

        if (sizeRouteTree.getFirst() >= Place.numPlaces()) {
            return false;
        }

sHandle().debugPrint(here + ": wait");
        when (sHandle().active) {
            active = false;
        }

        sHandle().joinTwoLists();
        sHandle().sortDom();

        // perform BFS.
        while (!list.isEmpty() && list.size() < nBoxesMax) {
            //val box = sHandle().removeDom();
            val box = list.removeFirst();
            solver.search(sHandle, box);
        }

        sHandle().sortDom();

sHandle().debugPrint(here + ": search done, " + list.size());

        val sets = new ArrayList[List[IntervalVec[K]]](nDestinations);
        for (1..nDestinations) {
            val l = new ArrayList[IntervalVec[K]]();
            sets.add(l);
        }

        for (i in 1..list.size()) {
            val box = sHandle().removeDom();
            //val pv:Box[K] = box.prevVar();
            sets((i-1) % nDestinations).add(box);
        }

        // TODO: finish needed?
        //finish
        for (bs in sets) {
            val p = selectPlace();
sHandle().debugPrint(here + ": sending to: " + p);

            if (p.id() <= here.id()) {
                sHandle().joinWithListShared(bs);
	            atomic sHandle().active = true;
            }
            else {

val b = (p != here);
//val vol = box.volume();
//if (b) sHandle().totalVolume.addAndGet(-vol);

                async at (p) {
                    sHandle().joinWithListShared(bs);
    	            atomic sHandle().active = true;
                }
    
                if (b) sHandle().nSends.incrementAndGet();
                //if (p.id() < here.id()) sHandle().sentBw.set(true);
            }
        }

        updateSizeRouteTree();

        return true;
    }

    // kludge for a success of compilation
    val dummy:Double = 0.;
    val dummyI:Interval = new Interval(0.,0.);
    val dummyR:BAPSolver.Result = BAPSolver.Result.unknown();
}

// vim: shiftwidth=4:tabstop=4:expandtab
