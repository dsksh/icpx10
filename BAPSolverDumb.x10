//import x10.compiler.*;
import x10.util.*;
import x10.io.Console; 

public class BAPSolverDumb[K] extends BAPSolver[K] {

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        super(core, selector);
    }

    protected def search(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {

        // for dummy boxes
        if (box.size() == 0)
            return;

        sHandle().addSolution(Result.unknown(), box);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
