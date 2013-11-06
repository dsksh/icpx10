import x10.io.Console; 
import x10.util.*;

public class PlaceAgentDelayed[K] extends PlaceAgent[K] {

    // number of splitting each component
    static val cutoffD = 4;

    private val solverPP : BAPListSolverBnd[K];

    public def this(core:BAPSolver[K].Core[K], solver:BAPSolver[K]) {
        super(solver);

        // create solverPP.
        val tester = new VariableSelector.Tester[K]();
        // TODO: termination criterion
        val test = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => tester.testPrec(1., res, box, v);

        val selector = new VariableSelector[K](test);
        val select = (res:BAPSolver.Result, box:IntervalVec[K])=>selector.selectGRR(res, box);
        val select1 = (res:BAPSolver.Result, box:IntervalVec[K])=>selector.selectBoundary(select, res, box);
        
        solverPP = new BAPListSolverBnd(core, select1);

        initPhase = false;
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) {
        super.setup(sHandle);

        // construct a btree-formed network.
        var dst:Int = 0;
        var pow2:Int = 1;
        finish for (pi in 1..(Place.numPlaces()-1)) {
            async at (Place(dst)) sHandle().reqQueue.addLast(pi);
Console.OUT.println(here + ": linked "+dst+" -> "+pi);
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

            while (reqQueue.getSize() > 0) { // has some requests...
                // move from the PlaceAgent's list to the solverPP's list.
                while (!list.isEmpty())
                    solverPP.addDom(list.removeLast());

                solverPP.search(sHandle, solver.core.dummyBox());

                // distribute the half of the search space.
                val pi = reqQueue.removeFirstUnsafe();
        
                val nB = list.size();
//Console.OUT.println(here + ": nB: " + nB);
                var b:Boolean = true;
                finish for (i in 1..nB) {
                    val box = list.removeFirst();
                    async at (b ? here : Place(pi)) sHandle().list.add(box);
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

//Console.OUT.println(here + ": initPhase done");

        super.run(sHandle);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
