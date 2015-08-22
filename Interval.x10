import x10.util.Pair;
import x10.util.Box;

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

    public def intersect(rhs:Interval) : Box[Interval] {
        //if (is_empty()) {
        //    return *this;
        //}

        var left :Double = this.left;
        var right:Double = this.right;
        if (!(rhs.left <= left)) { // rhs.left == NaN => left <- NaN
            left = rhs.left;
        }
        if (!(rhs.right >= right)) {
            right = rhs.right;
        }

        if (left <= right)
            return new Box[Interval](new Interval(left, right));
        else
            return null;
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
