import x10.array.*;
import x10.util.*;

// kludge for "Interval is incomplete type" error
class Dummy_IntervalArray {
    val dummy : Interval = new Interval(0.,0.);
}

public class IntervalArray implements IntervalVec[Int] { 
    val theArray : Array[Interval]{self.rank==1};
    public var vit:Iterator[Int] = null;
    public def vit() : Iterator[Int] { return vit; }
    //public var vit:MyHashMap.KeyIterator[String,Interval] = null;
    public var prevVar:Int = -1;
    public def prevVar() : Box[Int] { return (prevVar >= 0) ? new Box(prevVar) : null; }
    //public def prevVar() : Box[Point] { return (prevVar != null) ? new Box(prevVar) : null; }
    public def setPrevVar(variable:Int) : void { prevVar = variable; }

    public def this(size:Int) : IntervalArray { 
        theArray = new Array[Interval](size);
    } 
    public def this(lhs:IntervalArray) : IntervalArray { 
        theArray = new Array[Interval](lhs.theArray);
        this.prevVar = lhs.prevVar;
    } 

    public operator this(k:Int) : Box[Interval] = get(k);

    public def get(k:Int) : Box[Interval] {
        // TODO
        return new Box[Interval](theArray(k));
    }
    public def getOrThrow(k:Int) : Interval //throws NoSuchElementException
    {
        return this.theArray(k);
    }

    public def put(k:Int, value:Interval) : Box[Interval] {
        val old = theArray(k);
        theArray(k) = value;
        // TODO
        return new Box[Interval](old);
    }

    public def varIterator() : Iterator[Int] {
        return (0..(theArray.size-1)).iterator();
    }

    public def split(variable:Int) : Pair[IntervalVec[Int],IntervalVec[Int]] {
        val b1 = new IntervalArray(this); 
        val b2 = new IntervalArray(this); 
        val ip = get(variable).value.split();
        b1.put(variable, ip.first);
        b2.put(variable, ip.second);
        return new Pair[IntervalVec[Int],IntervalVec[Int]](b1,b2);
    }

    public def width() : Double {
        var width:Double = 0.;
        val it = theArray.values().iterator();
        while (it.hasNext()) {
            val intv:Interval = it.next();
            val w = intv.width();
            if (w > width) width = w;
        }
        return width;
    }

    public def toString() :String {
        return toString(3);
    }
    public def toString(plot:Int) :String {
        val sb:StringBuilder = new StringBuilder();
        sb.add('{');
        sb.add("\"plot\" : "+plot+",\n");
        val it = theArray.values().iterator();
        var b:Boolean = false;
        for (var i:Int = 0; it.hasNext(); i++) {
            if (b) sb.add(",\n"); else b = true;
            sb.add('"'); sb.add(i); sb.add("\" : ");
            sb.add(it.next());
        }
        sb.add('}');
        return sb.result();
    }

}

// vim: shiftwidth=4:tabstop=4:expandtab
