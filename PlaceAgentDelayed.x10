import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicInteger;

public class PlaceAgentDelayed[K] extends PlaceAgent[K] {

    static val nBoxes = 64;
    static val factor = 4;

    private var tester : VariableSelector.Tester[K] = null;
    private var solverPP : BAPListSolverBnd[K] = null;

    public def this(solver:BAPSolver[K]) {
        super(solver);

        initPhase = false;
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
        
        solverPP = new BAPListSolverBnd(core, select1, list);
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        //super.setup(sHandle);
        //list.add(solver.core.getInitialDomain());

        // construct a btree-formed network.
        var dst:Int = 0;
        var pow2:Int = 1;
        finish for (pi in 1..(Place.numPlaces()-1)) {
            at (Place(dst)) //async 
            {
                sHandle().reqQueue.addLast(pi);
//Console.OUT.println(here + ": reqQueue: "+sHandle().reqQueue.getSize());
            }
//Console.OUT.println(here + ": linked "+Place(dst)+" -> "+pi);
            if (++dst == pow2) { dst = 0; pow2 *= 2; }
        }

        initPhase = true;

        // initial splitting at Place(0).
        //tester.maxLSize = nBoxes/2;
        solverPP.maxDomSize = nBoxes;
        solverPP.search(sHandle, solver.core.getInitialDomain());
    }

/*    public atomic def addSolution(res:BAPSolver.Result, box:IntervalVec[K]) {
        if (initPhase && !res.entails(BAPSolver.Result.inner())) {
            list.add(box);
//atomic solutions.add(new Pair[BAPSolver.Result,IntervalVec[K]](res, box));
        }
        else 
            super.addSolution(res, box);
    }
*/

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {

        while (true) if (initPhase) {
//Console.OUT.println(here + ": start PP");

            while (reqQueue.getSize() > 0) { // has some requests...
//Console.OUT.println(here + ": handle req: " + reqQueue.getSize());
//Console.OUT.println(here + ": lsize: " + list.size());

                // move from the PlaceAgent's list to the solverPP's list.
//                while (!list.isEmpty()) {
//                    solverPP.addDom(list.removeLast());
//                }

                //tester.nSplits.set(0);
                //tester.nSplits = 0;
//Console.OUT.println(here + ": nB0: " + solverPP.domSize());
                //tester.maxLSize = solverPP.domSize() * 2;
                solverPP.maxDomSize = solverPP.domSize() * 2;
                solverPP.search(sHandle, solver.core.dummyBox());
//sHandle().tEndPP = System.nanoTime();

//                finish list.sort(
//                    (b1:IntervalVec[K],b2:IntervalVec[K]) =>
//                        b2.volume().compareTo(b1.volume()) );

                // distribute the half of the search space.
                val pi = reqQueue.removeFirstUnsafe();
        
                val nB = solverPP.domSize();
//Console.OUT.println(here + ": nB: " + nB + ", dest: " + pi);
                var b:Boolean = true;
                finish for (i in 1..nB) {
                    val box = solverPP.removeDom();
                    val pv:Box[K] = box.prevVar();
                    at (b ? here : Place(pi)) //async 
                    {
                        box.setPrevVar(pv);
                        atomic sHandle().list.add(box);
                    }
//Console.OUT.println(here + ": append at " + (b ? here.id : pi));
//Console.OUT.println(here + ": " + box);
                    if (!b) nSends++;
                    b = !b;
                }

                at (Place(pi)) atomic sHandle().initPhase = true;
            }

            initPhase = false;
            break;
        }
        else when (initPhase) {}

//Console.OUT.println(here + ": PP done");
sHandle().tEndPP = System.nanoTime();

        super.run(sHandle);

//while (!list.isEmpty()) {
//    val box = list.removeLast();
//    atomic solutions.add(new Pair[BAPSolver.Result,IntervalVec[K]](BAPSolver.Result.unknown(), box));
//    nSols.getAndIncrement();
//}
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
