import x10.util.Box;
import x10.util.concurrent.AtomicInteger;

public class VariableSelector[K] {
    public static class Tester[K] {
        public def testPrec(prec:Double, res:BAPSolver.Result, box:IntervalVec[K], v:K) : Boolean {
            return box(v)().width() > prec;
        }
        public def testRegularity(test:(BAPSolver.Result,IntervalVec[K],K)=>Boolean, 
                                  checkScope:(K)=>Boolean,
                                  res:BAPSolver.Result, box:IntervalVec[K], v:K) : Boolean {
            if (res.entails(BAPSolver.Result.regular()) && checkScope(v))
                return false;
            else
                return test(res, box, v);
        }
        //public var nSplits:AtomicInteger;
        public var nSplits:Int;
/*        public def testNSplits(test:(BAPSolver.Result,IntervalVec[K],K)=>Boolean,
                               maxNSplits:Int, 
                               res:BAPSolver.Result, box:IntervalVec[K], v:K) : Boolean {
            if (nSplits.get() >= maxNSplits)
                return false;
            else
                return test(res, box, v);
        }
*/
        public def testNSplits(test:(BAPSolver.Result,IntervalVec[K],K)=>Boolean,
                               maxNSplits:Int, 
                               res:BAPSolver.Result, box:IntervalVec[K], v:K) : Boolean {
            if (nSplits >= maxNSplits)
                return false;
            else 
                if (test(res, box, v)) {
                    //nSplits.getAndIncrement();
                    nSplits++;
                    return true;
                }
                else return false;
        }
        public var maxLSize:Int;
        /*public def testLSize(test:(BAPSolver.Result,IntervalVec[K],K)=>Boolean,
                             listSolver:BAPListSolver[K], 
                             res:BAPSolver.Result, box:IntervalVec[K], v:K) : Boolean {
            if (listSolver.domSize()+1 >= maxLSize) {
//                if (!res.entails(BAPSolver.Result.inner()))
                    maxLSize--;
                return false;
            } 
            else 
                return test(res, box, v);
        }
        */
    }

    public def this(precision:Double) {
        this.test = (res:BAPSolver.Result, box:IntervalVec[K], v:K) =>
            box(v)().width() > precision;
    }
    public def this(test:(BAPSolver.Result,IntervalVec[K],K)=>Boolean) { 
        this.test = test;
    }

    public val test : (BAPSolver.Result,IntervalVec[K],K) => Boolean;

    //private val precision:Double;
    private var variableIt:Iterator[K] = null;

    public def selectGRR(res:BAPSolver.Result, box:IntervalVec[K]) : Box[K] {
atomic {
        if (variableIt == null || !variableIt.hasNext()) variableIt = box.varIterator();
        val v0 = variableIt.next();
        if (test(res, box, v0)) {
            return new Box[K](v0);
        }

        // try rest of the vars.
        while (variableIt.hasNext()) {
            val v = variableIt.next();
            if (test(res, box, v)) {
                return new Box[K](v);
            }
        }

        // try the preceding vars.
        variableIt = box.varIterator();
        while (variableIt.hasNext()) {
            val v = variableIt.next();
            if (v == v0)
                break;
            if (test(res, box, v)) {
                return new Box[K](v);
            }
        }

        return null;
}
    }

    // (local) round-robin selector
    public def selectLRR(res:BAPSolver.Result, box:IntervalVec[K]) : Box[K] {
        var it:Iterator[K] = box.varIterator();

        // find the previously selected var
        while (box.prevVar() != null && it.hasNext()) {
            val v = it.next();
            if (v.equals(box.prevVar()())) {
//Console.OUT.println(here + ": select " + v);
                break;
            }
        }

        if (!it.hasNext()) it = box.varIterator();
        val v0 = it.next();
        if (test(res, box, v0)) {
//Console.OUT.println(here + ": select " + v0);
            val bv = new Box[K](v0);
            box.setPrevVar(bv);
            return bv;
        }

        // try rest of the vars.
        while (it.hasNext()) {
            val v = it.next();
            if (test(res, box, v)) {
//Console.OUT.println(here + ": select " + v);
                val bv = new Box[K](v);
                box.setPrevVar(bv);
                return bv;
            }
        }

        // try the preceding vars.
        it = box.varIterator();
        while (it.hasNext()) {
            val v = it.next();
            if (v.equals(v0))
                break;
            if (test(res, box,v)) {
                val bv = new Box[K](v);
                box.setPrevVar(bv);
                return bv;
            }
        }

        return null;
    }
/*    public def selectLRR(res:BAPSolver.Result, box:IntervalVec[K]) : String {
        if (box.vit == null || !box.vit.hasNext()) box.vit = box.keyIterator();
        val v0 = box.vit.next();
//Console.OUT.println(here + ": v0: " + v0);
        if (test(res, box, v0))
            return v0;

        // try rest of the vars.
        while (box.vit.hasNext()) {
            val v = box.vit.next();
//Console.OUT.println(here + ": v: " + v);
            if (test(res, box, v))
                return v;
        }

        // try the preceding vars.
        box.vit = box.keyIterator();
        while (box.vit.hasNext()) {
            val v = box.vit.next();
//Console.OUT.println(here + ": v: " + v);
            if (v == v0)
                break;
            if (v.equals(v0))
                break;
            if (test(res, box, v))
                return v;
        }

        return null;
    }
*/

    // largest-first selector
    public def selectLF(res:BAPSolver.Result, box:IntervalVec[K]) : Box[K] {
        var variable:Box[K] = null;
        var maxW:Double = 0.;
        val it = box.varIterator();
        while (it.hasNext()) {
            val v = it.next();
            val c = box(v)();
            if (c.width() > maxW && test(res, box, v)) {
                variable = new Box[K](v); 
                maxW = c.width();
            }
        }
        return variable;
    }

    public def selectBoundary(select:(BAPSolver.Result, IntervalVec[K])=>Box[K], 
                              res:BAPSolver.Result, box:IntervalVec[K]) : Box[K] {
        if (res.entails(BAPSolver.Result.inner()))
            return null;
        else
            return select(res, box);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
