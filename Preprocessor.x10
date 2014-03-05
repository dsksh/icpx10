import x10.util.*;

public class Preprocessor[K] {

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
    val listShared:List[IntervalVec[K]];

    // information of the distribution route tree.
    var idRoute:Int;
    var sizeFrontier:Int;
    //var sizeRouteTree:Int;
    val sizeRouteTree:List[Int];

    var minVolume:Double;

    var initPhase:Boolean;

    //public def this(solver:BAPSolver[K]) {
    //public def this(core:BAPSolver.Core[K], prec:Double, paPost:PlaceAgentClocked[K]) {
    public def this(core:BAPSolver.Core[K], prec:Double, pa:PlaceAgentClocked[K]) {
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

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        initPhase = true;
    }

    private val random:Random = new Random(System.nanoTime());
    private var selectedPid:Int = 0;

    protected def selectPlace() : Place {
        // random selection.
        //val id = random.nextInt(nDestinations-1);

        // round-robin selection.
        if (selectedPid == nDestinations) selectedPid = 0;
        val id = selectedPid++ % nDestinations;

        //if (selected == null || !selected.hasNext()) 
        //    //selected = (0..(nDestinations-1)).iterator();
        //    selected = (0..Int.MAX_VALUE).iterator();
        //var id:Int = selected.next() % nDestinations;

        return Place( (id + (nDestinations*here.id()+1)) % Place.numPlaces() );
    }

    public def process(sHandle:PlaceLocalHandle[PlaceAgent[K]]) : Boolean {
        if (sizeRouteTree.getFirst() >= Place.numPlaces()) {
            return false;
        }

        var activated:Boolean = false;
        atomic if (initPhase || list.size()+listShared.size() >= nBoxesMin) {
sHandle().debugPrint(here + ": activated: " + initPhase + ", " + (list.size()+listShared.size()));
            activated = true;

            initPhase = false;

            // append the two lists.
            for (box in listShared)
                list.add(box);

            // reset
            listShared.clear();
        }

        if (activated) {
sHandle().debugPrint(here + ": activated: " + initPhase + ", " + list.size() + ", " + idRoute);

            //sHandle().sortDom();

            // perform BFS.
            while (!list.isEmpty() && list.size() < nBoxesMax) {
                //val box = sHandle().removeDom();
                val box = list.removeFirst();
                solver.search(sHandle, box);
            }

            //sHandle().sortDom();

            finish for (1..list.size()) {
                //val box = sHandle().removeDom();
                val box = list.removeFirst();
//sHandle().debugPrint(here + ": sending box:\n" + box);
                val pv:Box[K] = box.prevVar();
                val p = selectPlace();
sHandle().debugPrint(here + ": selected: " + p);
val b = (p != here);
val vol = box.volume();
if (b) sHandle().totalVolume.addAndGet(-vol);
                async at (p) {
                    box.setPrevVar(pv);
                    (sHandle() as PlaceAgentClocked[K]).addDomShared(box);
if (b) sHandle().totalVolume.addAndGet(vol);
                }
                if (b) sHandle().nSends++;
                if (p.id() < here.id()) sHandle().sentBw.set(true);
            }

            updateSizeRouteTree();

sHandle().debugPrint(here + ": search done, " + list.size());

//            if (here.id() == 0) atomic
//                if (list.isEmpty() && terminate == 0) {
//debugPrint(here + ": start termination");
//                    terminate = 1;
//                }
        }
        else System.sleep(1);

sHandle().tEndPP = System.nanoTime();

        return true;
    }


    // kludge for a success of compilation
    val dummy:Double = 0.;
    val dummyI:Interval = new Interval(0.,0.);
    val dummyR:BAPSolver.Result = BAPSolver.Result.unknown();
}

// vim: shiftwidth=4:tabstop=4:expandtab
