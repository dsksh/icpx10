import x10.compiler.*;
import x10.util.*;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.io.*;
import x10.io.Console; 

public class PlaceAgentMSplit[K] extends PlaceAgent[K] {

    public def this(solver:BAPSolverMSplit[K]) {
        super(solver);
    }

    public def setup(sHandle:PlaceLocalHandle[PlaceAgent[K]]) { 
//Console.OUT.println(here + ": initD: " + solver.core.getInitialDomain());
        list.add(solver.core.getInitialDomain());

        for (pi in 1..(Place.numPlaces()-1)) {
            reqQueue.addLast(pi);
        }
    }

    public atomic def getMultipleRequests(nMax:Int) : List[Int] {
        val n = Math.min( nMax<0 ? Int.MAX_VALUE : nMax, reqQueue.getSize() );
        val list = new ArrayList[Int](n);
        for (i in 1..n) {
            val id = reqQueue.removeFirstUnsafe();
            list.add(id);
        }
        return list;
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
