import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicInteger;

public class PlaceAgentSenderInitiated[K] extends PlaceAgentClocked[K] {

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

    //val paPost:PlaceAgentClocked[K];

    //private var solverPP : BAPSolverSimple[K] = null;
    //val listShared:List[IntervalVec[K]];

    // information of the distribution route tree.
    var idRoute:Int;
    var sizeFrontier:Int;
    //var sizeRouteTree:Int;
    val sizeRouteTree:List[Int];

    var minVolume:Double;

    //public def this(solver:BAPSolver[K]) {
    //public def this(core:BAPSolver.Core[K], prec:Double, paPost:PlaceAgentClocked[K]) {
    public def this(core:BAPSolver.Core[K], prec:Double) {
        //super(solver);
        super(initSolver[K](core, prec));
        (solver as BAPSolverSimpleUnsafe[K]).setList(list); //TODO

        //this.paPost = paPost;

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

        //listShared = new ArrayList[IntervalVec[K]]();

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
        //super.setup(sHandle);
        list.add(solver.core.getInitialDomain());

        initPhase = true;
    }

    private val random:Random = new Random(System.nanoTime());
    //private var selected:Iterator[Place] = null;
    private var selected:Iterator[Int] = null;

    protected def selectPlace() : Place {
        // random selection.
        //var id:Int = random.nextInt(nDestinations-1);

        // round-robin selection.
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

    var phasePre:Boolean = true;

    public def searchBody(sHandle:PlaceLocalHandle[PlaceAgent[K]]) : Boolean {
            var activated:Boolean = false;
            atomic if (initPhase || list.size()+listShared.size() > 0) {
debugPrint(here + ": activated: " + initPhase + ", " + list.size()+","+listShared.size());
                activated = true;

                // append the two lists.
                for (box in listShared)
                    list.add(box);

                // reset
                listShared.clear();
            }

        if (phasePre) {
            if (initPhase || list.size() >= nBoxesMin) {
debugPrint(here + ": activated: " + initPhase + ", " + list.size() + ", " + idRoute);

                sortDom();
    
                while (!list.isEmpty() && list.size() < nBoxesMax) {
                    val box = removeDom();
                    solver.search(sHandle, box);
                }
    
                sortDom();
    
                if (!list.isEmpty() && sizeRouteTree.getFirst() >= Place.numPlaces()) {
                    phasePre = false;
debugPrint(here + ": pre phase finished");
                    return;
                }

                //val sizeFullTree = (idRoute >= 0) ? Math.pow(nDestinations, ((Math.log(idRoute)/Math.log(nDestinations)) as Int)+1) as Int : 1;
//debugPrint(here + ": estimate: " + sizeRouteTree);
                finish for (i in 1..list.size()) {
                    val box = removeDom();
                    val pv:Box[K] = box.prevVar();
                    val p = selectPlace();
debugPrint(here + ": selected: " + p);
                    async at (p) {
                        box.setPrevVar(pv);
                        atomic (sHandle() as PlaceAgentSenderInitiated[K]).listShared.add(box);
                    }
                    if (p.id() < here.id()) sentBw.set(true);
                    nSends++;
                }
sHandle().tEndPP = System.nanoTime();

                updateSizeRouteTree();

debugPrint(here + ": search done, " + list.size());

                if (here.id() == 0) atomic
                    if (list.isEmpty() && terminate == 0) {
debugPrint(here + ": start termination");
                        terminate = 1;
                    }
            }
            else System.sleep(1);
        }
        else 
            //paPost.searchBody(sHandle);
            return super.searchBody(sHandle);
    }

    def request(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        while (terminate != 3) {
    		Clock.advanceAll();
    		Clock.advanceAll();
        }
    }

}

// vim: shiftwidth=4:tabstop=4:expandtab
