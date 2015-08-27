import x10.compiler.*;
import x10.util.ArrayList;
import x10.util.Team;
import glb.GLBResult;

// kludge for "Interval is incomplete type" error
class Dummy_GlbResultImpl {
    val dummy : Interval = new Interval(0.,0.);
}

public class GlbResultImpl[K,D] extends GLBResult[D] {

    public static struct Paving[K] implements Arithmetic[Paving[K]] {
        val data:Rail[IntervalVec[K]];
        val obj:Interval;
        public def this(data:Rail[IntervalVec[K]], obj:Interval) {
            this.data = data;
            this.obj = obj;
        }
        public def this(data:Rail[IntervalVec[K]]) {
            this(data, new Interval(Double.NEGATIVE_INFINITY, Double.POSITIVE_INFINITY));
        }
        public operator this*(that:Paving[K]) : Paving[K] { return this; }
        public operator +this : Paving[K] { return this; }
        public operator this+(that:Paving[K]) : Paving[K] { 
            val ub = Math.min(obj.right, that.obj.right);
            val lb = Math.min(obj.left, that.obj.left);
            val obj1 = new Interval(lb, /*obj.right*/ ub);
            val sols = new Paving[K](new Rail[IntervalVec[K]](data.size+that.data.size), obj1);
            var i:Long = 0;
            for (; i < data.size; ++i) sols.data(i) = data(i);
            for (var j:Long = 0; j < that.data.size; ++i, ++j) sols.data(i) = that.data(j);
            return sols;
        }
        public operator -this : Paving[K] { return this; }
        public operator this-(that:Paving[K]) : Paving[K] { return this; }
        public operator this/(that:Paving[K]) : Paving[K] { return this; }

        public def toString() : String { 
            //return data.size.toString(); 
            return obj.toString();
        }
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
        Console.OUT.println("resulting data: " + r(0));
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
