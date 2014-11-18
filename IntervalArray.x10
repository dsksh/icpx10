import x10.array.*;
import x10.util.*;

// kludge for "Interval is incomplete type" error
class Dummy_IntervalArray {
    val dummy : Interval = new Interval(0.,0.);
}

public class IntervalArray implements IntervalVec[Long] { 
    //val theArray : Array[Interval]{self.rank==1};
    val theArray : Rail[Interval];

    var volume : Double;

    public var vit:Iterator[Long] = null;
    public def vit() : Iterator[Long] { return vit; }
    //public var vit:MyHashMap.KeyIterator[String,Interval] = null;
    //public var prevVar:Long = -1;
    public var prevVar:Long = 0; // cf: rp::SplitSelectRoundRobin
    public def prevVar() : Box[Long] { return (prevVar >= 0) ? new Box(prevVar) : null; }
    //public def prevVar() : Box[Point] { return (prevVar != null) ? new Box(prevVar) : null; }
    public def setPrevVar(v:Box[Long]) : void { prevVar = v != null ? v() : -1; }

    public def this(size:Long) : IntervalArray { 
        theArray = new Rail[Interval](size);
        volume = -1;
    } 
    public def this(rhs:IntervalArray) : IntervalArray { 
        theArray = new Rail[Interval](rhs.theArray);
        this.prevVar = rhs.prevVar;
        this.volume = rhs.volume;
    } 

    public operator this(k:Long) : Box[Interval] = get(k);

    public def get(k:Long) : Box[Interval] {
        // TODO
        return new Box[Interval](theArray(k));
    }
    public def getOrThrow(k:Long) : Interval //throws NoSuchElementException
    {
        return this.theArray(k);
    }

    public def put(k:Long, value:Interval) : Box[Interval] {
        val old = theArray(k);
        theArray(k) = value;
        volume = -1;
        // TODO
        return new Box[Interval](old);
    }

    public def size() : Long {
        return theArray.size;
    }

    public def varIterator() : Iterator[Long] {
        return (0..(theArray.size-1)).iterator();
    }

    public def split(variable:Long) : Pair[IntervalVec[Long],IntervalVec[Long]] {
atomic {
        val b1 = new IntervalArray(this); 
        val b2 = new IntervalArray(this); 
        val ip = get(variable).value.split();
        b1.put(variable, ip.first);
        b2.put(variable, ip.second);
        return new Pair[IntervalVec[Long],IntervalVec[Long]](b1,b2);
}
    }

    public def width() : Double {
        var width:Double = 0.;
        val it = theArray.iterator();
        while (it.hasNext()) {
            val intv:Interval = it.next();
            val w = intv.width();
            if (w > width) width = w;
        }
        return width;
    }

    public def toString() :String {
        return toString(3n);
    }
    public def toString(plot:Int) :String {
        val sb:StringBuilder = new StringBuilder();
        sb.add('{');
        val it = theArray.iterator();
        for (var i:Long = 0; it.hasNext(); i++) {
            sb.add('"'); sb.add(i); sb.add("\" : ");
            sb.add(it.next());
            sb.add(",\n");
        }
        sb.add("\"plot\" : "+plot+",\n");
        sb.add("\"place\" : "+here.id());
        sb.add('}');
        return sb.result();
    }

    public def volume() : Double {
        if (volume == -1.) {
            volume = 1.;
            for (i in theArray)
                volume *= i.width();
        }

        return volume;
    }

    var count:Long = 0;

    public def count() : Long {
        return count++;
    }

    public operator this+(b:IntervalVec[Long]) : IntervalVec[Long] {
        return this;
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
