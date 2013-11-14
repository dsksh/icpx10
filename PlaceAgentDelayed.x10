import x10.io.Console; 
import x10.util.*;
import x10.util.concurrent.AtomicInteger;

public class PlaceAgentDelayed[K] extends PlaceAgent[K] {

    static val maxNSplits = 4;

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
        val test1 = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => 
                        tester.testNSplits(test, maxNSplits, res, box, v);

        val selector = new VariableSelector[K](test1);
        val select = (res:BAPSolver.Result, box:IntervalVec[K])=>selector.selectGRR(res, box);
        val select1 = (res:BAPSolver.Result, box:IntervalVec[K])=>selector.selectBoundary(select, res, box);
        
        solverPP = new BAPListSolverBnd(core, select1);
    }

/*    private var nSplits:AtomicInteger;
    private def testNSplits(test:(BAPSolver.Result,IntervalVec[K],K)=>Boolean,
                            res:BAPSolver.Result, box:IntervalVec[K], v:K) : Boolean {
        if (nSplits.get() >= maxNSplits)
            return false;
        else 
            if (test(res, box, v)) {
                nSplits.getAndIncrement();
                return true;
            }
            else return false;
    }
*/

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        //super.setup(sHandle);
        list.add(solver.core.getInitialDomain());

        // construct a btree-formed network.
        var dst:Int = 0;
        var pow2:Int = 1;
        finish for (pi in 1..(Place.numPlaces()-1)) {
            async at (Place(dst)) sHandle().reqQueue.addLast(pi);
//Console.OUT.println(here + ": linked "+dst+" -> "+pi);
            if (++dst == pow2) { dst = 0; pow2 *= 2; }
        }

        initPhase = true;
    }

    public atomic def addSolution(res:BAPSolver.Result, box:IntervalVec[K]) {
        if (initPhase && res == BAPSolver.Result.unknown()) {
            list.add(box);
        }
        else
            super.addSolution(res, box);
    }

    public def run(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {

        while (true) if (initPhase) {
//Console.OUT.println(here + ": start PP");

            while (reqQueue.getSize() > 0) { // has some requests...
                // move from the PlaceAgent's list to the solverPP's list.
                while (!list.isEmpty()) {
                    solverPP.addDom(list.removeLast());
                }

                //tester.nSplits.set(0);
                tester.nSplits = 0;
                solverPP.search(sHandle, solver.core.dummyBox());

                finish list.sort(
                    (b1:IntervalVec[K],b2:IntervalVec[K]) =>
                        b2.volume().compareTo(b1.volume()) );

                // distribute the half of the search space.
                val pi = reqQueue.removeFirstUnsafe();
        
                val nB = list.size();
//Console.OUT.println(here + ": nB: " + nB);
                var b:Boolean = true;
                finish for (i in 1..nB) {
                    val box = list.removeFirst();
                    val pv:Box[K] = box.prevVar();
                    async at (b ? here : Place(pi)) {
                        box.setPrevVar(pv);
                        sHandle().list.add(box);
                    }
//Console.OUT.println(here + ": append at " + (b ? here.id : pi));
//Console.OUT.println(here + ": " + box);
                    nSends.getAndIncrement();
                    b = !b;
                }

                at (Place(pi)) atomic sHandle().initPhase = true;
            }

            initPhase = false;
            break;
        }
        else when (initPhase) {}

//Console.OUT.println(here + ": PP done");

        super.run(sHandle);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
