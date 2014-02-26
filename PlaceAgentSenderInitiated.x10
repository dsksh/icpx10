import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicInteger;

public class PlaceAgentSenderInitiated[K] extends PlaceAgent[K] {

    val nBoxes = 96;
    val minNBoxes = 32;
    var maxDomSize:Int;

    val nDestinations:Int = 3;

    private var tester : VariableSelector.Tester[K] = null;
    private var solverPP : BAPSolverSimple[K] = null;
    val listShared:List[IntervalVec[K]];

    // information of the distribution route tree.
    var idRoute:Int;
    var sizeFrontier:Int;
    var sizeRouteTree:Int;

    var minVolume:Double;

    public def this(solver:BAPSolver[K]) {
        super(solver);

        listShared = new ArrayList[IntervalVec[K]]();
        maxDomSize = nBoxes;

        initPhase = false;

        idRoute = here.id()+1;
        sizeFrontier = nDestinations;
        sizeRouteTree = 1;
        while (sizeRouteTree < idRoute) {
            sizeRouteTree += sizeFrontier;
            sizeFrontier *= nDestinations;
        }
    }

    def updateSizeRouteTree() {
        idRoute += Place.numPlaces();
        while (sizeRouteTree < idRoute) {
            sizeRouteTree += sizeFrontier;
            sizeFrontier *= nDestinations;
        }
    }

    public def initPP(core:BAPSolver.Core[K], prec:Double) {

        // create solverPP.

        tester = new VariableSelector.Tester[K]();
        val test = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => 
                        tester.testPrec(prec, res, box, v);
        //val test1 = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => 
        //                tester.testNSplits(test, maxNSplits, res, box, v);
        //val test1 = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => 
        //                tester.testLSize(test, solverPP, res, box, v);

        val selector = new VariableSelector[K](test);
        val select = (res:BAPSolver.Result, box:IntervalVec[K])=>selector.selectLRR(res, box);
        val select1 = (res:BAPSolver.Result, box:IntervalVec[K])=>selector.selectBoundary(select, res, box);
        
        solverPP = new BAPSolverSimpleUnsafe(core, select1);
        solverPP.setList(list);
        //solverPP.maxDomSize = nBoxes;
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
        /*var id:Int;
        id = random.nextInt(nDestinations);
        id = (id + (2*here.id()+1)) % Place.numPlaces();
debugPrint(here + ": selected " + id);
        return Place(id);
        */

        if (selected == null || !selected.hasNext()) 
            selected = (0..(nDestinations-1)).iterator();
        var id:Int = selected.next();
        id = (id + (nDestinations*here.id()+1)) % Place.numPlaces();
//debugPrint(here + ": selected " + id);
        return Place(id);

        /*if (selected == null || !selected.hasNext())
            selected = Place.places().iterator();
        val p = selected.next();
debugPrint(here + ": selected " + p);
        return p;
        */
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

    def removeDom() : IntervalVec[K] {
        return list.removeFirst();
    }

    def sortDom() {
        list.sort(
            (b1:IntervalVec[K],b2:IntervalVec[K]) =>
                b2.volume().compareTo(b1.volume()) );
    }

    public def search(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        while (terminate != 3) {
            var activated:Boolean = false;
            atomic if (initPhase || list.size()+listShared.size() >= minNBoxes) {
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
    
                while (!list.isEmpty() && list.size() < maxDomSize) {
                    val box = removeDom();
                    solverPP.search(sHandle, box);
                }
    
                sortDom();
    
                //val sizeFullTree = (idRoute >= 0) ? Math.pow(nDestinations, ((Math.log(idRoute)/Math.log(nDestinations)) as Int)+1) as Int : 1;
//debugPrint(here + ": estimate: " + sizeRouteTree);
                if (sizeRouteTree < Place.numPlaces()) {
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
                }
                else {
                    maxDomSize = Math.max(nBoxes, list.size())*2;
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
