import x10.compiler.*;
import x10.util.*;
import x10.io.Console; 

public class BAPListSolverBnd[K] extends BAPListSolver[K] {

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        super(core, selector);
    }

    protected def search(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');

        // add to list if not a dummy box
        if (box.size() > 0)
            addDom(box);

        // TODO: parallelize? 
        while (hasDom()) {
            val dom = removeDom();
            searchBody(sHandle, dom);
        }
    }

    protected def searchBody(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
        val res:Result = contract(sHandle, box);

        if (!res.hasNoSolution()) {
            val v = selectVariable(res, box);
            if (v != null) {
                val bp = box.split(v()); 
                sHandle().nSplits.getAndIncrement();
                addDom(bp.first);
                addDom(bp.second);

                sortDom();
            }
            else {
                sHandle().addSolution(res, box);
            }
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
