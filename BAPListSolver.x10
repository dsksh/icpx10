import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.io.*;
import x10.io.Console; 

public class BAPListSolver[K] extends BAPSolver[K] {

    public def this(core:Core[K], selector:(Result, IntervalVec[K])=>Box[K]) {
        super(core, selector);

//        list = new ArrayList[IntervalVec[K]]();
        list1 = new ArrayList[Pair[Result,IntervalVec[K]]]();
    }

    // auxiliary list
    private val list1:List[Pair[Result,IntervalVec[K]]];
    protected atomic def clearDom() {
        list1.clear();
    }
    protected atomic def addDom(res:Result, box:IntervalVec[K]) {
        // add last.
        list1.add(new Pair[Result,IntervalVec[K]](res, box));
    }
    protected atomic def removeDom() : Pair[Result,IntervalVec[K]] {
        return list1.removeFirst();
//        return list1.removeLast();
    }
    protected atomic def hasDom() : Boolean {
        return !list1.isEmpty();
    }

    protected def search(sHandle:PlaceLocalHandle[PlaceAgent[K]], box:IntervalVec[K]) {
//Console.OUT.println(here + ": search:\n" + box + '\n');
//        clearDom();

        // for dummy boxes
        if (box.size() == 0)
            return;

        addDom(Result.unknown(), box);

        while (hasDom()) finish {
            while (hasDom()) {
                val dom = removeDom();
                async searchBody(sHandle, dom);
            }
        }
    }

    protected def searchBody(sHandle:PlaceLocalHandle[PlaceAgent[K]], dom:Pair[Result,IntervalVec[K]]) {
        val res:Result = contract(sHandle, dom.second);

        if (!res.hasNoSolution()) {
            val v = selectVariable(res, dom.second);
            if (v != null) {
                val bp = dom.second.split(v()); 
                sHandle().nSplits.getAndIncrement();
                if (!sHandle().respondIfRequested(sHandle, bp.first))
                    addDom(dom.first, bp.first);
                addDom(dom.first, bp.second);
            }
            else {
                sHandle().addSolution(res, dom.second);
            }
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
