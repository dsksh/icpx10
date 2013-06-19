import x10.util.*;

public struct Interval {
    public val left:Double;
    public val right:Double;

    public def this(left:Double, right:Double) : Interval {
        this.left = left;
        this.right = right;
    }

    public def width() : Double {
        return right - left;
    }
    
    public def split() : Pair[Interval,Interval] {
        val mid = (left+right)/2;
        return new Pair(new Interval(left,mid), new Interval(mid,right));
    }

    public def toString() : String {
        return "[" + left+ ", " + right + "]";
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
