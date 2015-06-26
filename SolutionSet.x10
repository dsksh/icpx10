import x10.compiler.*;

public struct SolutionSet[K] implements Arithmetic[SolutionSet[K]] {
    public val data:Rail[IntervalVec[K]];
    public def this(sols:Rail[IntervalVec[K]]) {
        data = sols;
    }

    public operator this*(that:SolutionSet[K]) : SolutionSet[K] { return this; }
    public operator +this : SolutionSet[K] { return this; }
    public operator this+(that:SolutionSet[K]) : SolutionSet[K] { 
        val sols = new SolutionSet[K](new Rail[IntervalVec[K]](this.data.size+that.data.size));
        var i:Long = 0;
        for (; i < this.data.size; ++i) sols.data(i) = this.data(i);
        for (var j:Long = 0; j < that.data.size; ++i, ++j) sols.data(i) = that.data(j);
        return sols;
    }
    public operator -this : SolutionSet[K] { return this; }
    public operator this-(that:SolutionSet[K]) : SolutionSet[K] { return this; }
    public operator this/(that:SolutionSet[K]) : SolutionSet[K] { return this; }
}

// vim: shiftwidth=4:tabstop=4:expandtab
