import x10.util.*;

// kludge for "Interval is incomplete type" error
class Dummy_IntervalVec {
    val dummy : Interval = new Interval(0.,0.);
}

public interface IntervalVec[K] { 
    public operator this(key:K) : Box[Interval];
    public def get(key:K) : Box[Interval];
    public def getOrThrow(key:K) : Interval; //throws NoSuchElementException
    public def put(key:K, value:Interval) : Box[Interval];

    public def varIterator() : Iterator[K];

    public def split(variable:K) : Pair[IntervalVec[K],IntervalVec[K]];
    public def width() : Double;
    public def toString(plot:Int) :String;
    public def toString() :String;

    public def vit() : Iterator[K];
    public def prevVar() : Box[K];
    public def setPrevVar(variable:K) : void;
}

// vim: shiftwidth=4:tabstop=4:expandtab
