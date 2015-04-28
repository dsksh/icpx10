//import x10.compiler.*;
import x10.util.*;
import x10.io.Console; 

public class BAPSolverSimpleUnsafe[K] extends BAPSolverSimple[K] {

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        super(core, selector);
    }

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K], list:List[IntervalVec[K]]) {
        super(core, selector, list);
    }

    protected def returnDom(box:IntervalVec[K]) {
        // add last.
		list.add(box);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
