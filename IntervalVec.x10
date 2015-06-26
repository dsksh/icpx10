import x10.util.Box;
import x10.util.Pair;

public interface IntervalVec[K] { 
    public operator this(key:K) : Box[Interval];
    public def size() : Long;

    public def varIterator() : Iterator[K];

    public def split(variable:K) : Pair[IntervalVec[K],IntervalVec[K]];
    public def width() : Double;
    public def toString(plot:Long) :String;
    public def toString() :String;

    public def vit() : Iterator[K];
    public def prevVar() : Box[K];
    public def setPrevVar(variable:Box[K]) : void;

    public def volume() : Double;

    public def depth() : Long;
    public def deepen() : void;

    public def count() : Long;

    public def get(key:K) : Box[Interval];
    public def getOrThrow(key:K) : Interval; //throws NoSuchElementException
    public def put(key:K, value:Interval) : Box[Interval];
}

// vim: shiftwidth=4:tabstop=4:expandtab
