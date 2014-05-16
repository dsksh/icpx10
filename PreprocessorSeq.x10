import x10.util.*;

public class PreprocessorSeq[K] {

    static def initSolver[K](core:BAPSolver.Core[K], prec:Double) {

        val tester = new VariableSelector.Tester[K]();
        val test = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => 
                        tester.testPrec(prec, res, box, v);

        val selector = new VariableSelector[K](test);
        val select = (res:BAPSolver.Result, box:IntervalVec[K])=>selector.selectLRR(res, box);
        val select1 = (res:BAPSolver.Result, box:IntervalVec[K])=>selector.selectBoundary(select, res, box);
        
        return new BAPSolverSimpleUnsafe(core, select1);
    }

    val nDestinations:Int;
    val nBoxes:Int;
    val nBoxesMin:Int;
    var nBoxesMax:Int;

    private val solver : BAPSolverSimpleUnsafe[K];

    val list:List[IntervalVec[K]];
    // TODO: not needed?
    val listShared:List[IntervalVec[K]];

    // information of the distribution route tree.
    val sizeRouteTree:List[Int];

    var minVolume:Double;

    var active:Boolean;

    public def this(core:BAPSolver.Core[K], prec:Double, pa:PlaceAgentSeq[K]) {
        this.list = pa.list;
        this.listShared = pa.listShared;

        solver = initSolver[K](core, prec);
        solver.setList(list);

        // read env variables.
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

		// setup the selectPlace parameters.
		var pow:Int = 1;
		while (pow <= here.id()) pow *= nDestinations;
		selectCoeff = pow;
		selectOffset = here.id();		

		// setup the tree size information.
        val sizeRTCache = new ArrayList[Int](distDelay);
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
    private var selectedPid:Int = 0;
	private var selectCoeff:Int = 1;
	private var selectOffset:Int = 0;

    protected def selectPlace() : Place {
        // random selection.
        //val id = random.nextInt(nDestinations-1);

        // round-robin selection.
        if (selectedPid == nDestinations) selectedPid = 0;
        val id = selectedPid++ % nDestinations;

		return Place( (selectCoeff*id + selectOffset) % Place.numPlaces() );
    }

	var activated:Boolean = false;

    public def process(sHandle:PlaceLocalHandle[PlaceAgent[K]]) : Boolean {
		if (!activated) when (sHandle().active) activated = true;

        if (sizeRouteTree.getFirst() >= Place.numPlaces()) {
            return false;
        }

        when (sHandle().active) {
//sHandle().debugPrint(here + ": pp activated: " + active + ", " + (list.size()+(sHandle() as PlaceAgentSeq[K]).listShared.size()));

            active = false;
        }

        (sHandle() as PlaceAgentSeq[K]).joinTwoLists();

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
        for (1..nDestinations)
            sets.add(new ArrayList[IntervalVec[K]]());

        for (i in 1..list.size()) {
            val box = sHandle().removeDom();
            //val pv:Box[K] = box.prevVar();
            sets((i-1) % nDestinations).add(box);
        }

        // TODO: finish needed?
        //finish
        for (bs in sets) {
            val p = selectPlace();

val b = (p != here);
//val vol = box.volume();
//if (b) sHandle().totalVolume.addAndGet(-vol);

            async at (p) {
                (sHandle() as PlaceAgentSeq[K]).joinWithListShared(bs);
                //val ls = (sHandle() as PlaceAgentSeq[K]).listShared;
                //for (box in ls) bs.add(box);
                //(sHandle() as PlaceAgentSeq[K]).listShared = null;
                //(sHandle() as PlaceAgentSeq[K]).listShared = bs;
	            atomic sHandle().active = true;
            }

            if (b) sHandle().nSends++;
            if (p.id() < here.id()) sHandle().sentBw.set(true);
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
