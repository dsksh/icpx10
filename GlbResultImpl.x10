import x10.compiler.*;
import x10.util.ArrayList;
import x10.util.Team;
import glb.GLBResult;

public class GlbResultImpl[K,D] extends GLBResult[D] {

    public static struct Paving[K] implements Arithmetic[Paving[K]] {
        val data:Rail[IntervalVec[K]];
        public def this(data:Rail[IntervalVec[K]]) {
            this.data = data;
        }
        public operator this*(that:Paving[K]) : Paving[K] { return this; }
        public operator +this : Paving[K] { return this; }
        public operator this+(that:Paving[K]) : Paving[K] { 
            val sols = new Paving[K](new Rail[IntervalVec[K]](data.size+that.data.size));
            var i:Long = 0;
            for (; i < data.size; ++i) sols.data(i) = data(i);
            for (var j:Long = 0; j < that.data.size; ++i, ++j) sols.data(i) = that.data(j);
            return sols;
        }
        public operator -this : Paving[K] { return this; }
        public operator this-(that:Paving[K]) : Paving[K] { return this; }
        public operator this/(that:Paving[K]) : Paving[K] { return this; }

        public def toString() : String { return data.size.toString(); }
    }

    val data:D;

    public def this(data:D) {
        this.data = data;
    }
    
    public def getResult() : Rail[D] {
        val l = new ArrayList[D]();
        l.add(data);
        return l.toRail();
    }
    public def getReduceOperator() : Int {
        return Team.ADD;
    }
    public def display(r:Rail[D]) : void {
        Console.OUT.println("# results: " + r(0));
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
