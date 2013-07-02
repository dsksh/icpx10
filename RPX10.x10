import x10.io.Console; 
import x10.compiler.*;
import x10.util.*;
import x10.io.*;

public class RPX10 {

    static def format(t:Long) = (t as Double) * 1.0e-9;

    public static def main(args:Array[String](1)) {
        // create a solver at each place
        val everyone = Dist.makeUnique();
        //val sHandle = PlaceLocalHandle.make[Solver](everyone, 
        //        () => new Solver((box:IntervalVec)=>(new VariableSelector(1E-8)).selectLRR(box), args(0)) );
        //val sHandle = PlaceLocalHandle.make[PipelineSolver](everyone, 
        //    () => new PipelineSolver((box:IntervalVec)=>(new VariableSelector(1E-8)).selectLRR(box), args(0)) );
        val sHandle = PlaceLocalHandle.make[ClusterDFSSolver](everyone, 
            () => new ClusterDFSSolver((box:IntervalVec)=>(new VariableSelector(1E-8)).selectLRR(box), args(0)) );

        val masterP = here;

        var time:Long = -System.nanoTime();
        sHandle().setup(sHandle);

        finish for (p in Place.places()) at (p) async {
		    val solver = sHandle();
            //solver.solve();
            solver.solve(sHandle);
        }

        /*val it = solutions.iterator();
        for (var i:Int = 0; it.hasNext(); ++i) {
            val p = it.next();
   		    //Console.OUT.println("solution " + i + ":");
   		    Console.OUT.println(p.second);
   		    Console.OUT.println();
        }
        */

        time += System.nanoTime();
        Console.OUT.println();
        Console.OUT.println("time: " + format(time) + " s");

        // sum up the # solutions at each place
        val nSols = new GlobalRef(new Cell(0));
        Console.OUT.print("# sols:");
        for (p in Place.places()) at (p) {
            val v = sHandle().nSols.get();
            at (masterP) {
                Console.OUT.print((p == here ? " " : " + ") + v);
                nSols().value += v;
            }
        }
        Console.OUT.println(" = " + nSols().value);

        // sum up the # contracts at each place
        val nContracts = new GlobalRef(new Cell(0));
        val nSplits = new GlobalRef(new Cell(0));
        val nReqs = new GlobalRef(new Cell(0));
        val nSends = new GlobalRef(new Cell(0));
        val cContracts = new Cell[String]("# contracts:"); val gContracts = GlobalRef[Cell[String]](cContracts);
        val cSplits = new Cell[String]("# splits:"); val gSplits = GlobalRef[Cell[String]](cSplits);
        val cReqs = new Cell[String]("# reqs:"); val gReqs = GlobalRef[Cell[String]](cReqs);
        val cSends = new Cell[String]("# sends:"); val gSends = GlobalRef[Cell[String]](cSends);
        for (p in Place.places()) at (p) {
            val vContacts = sHandle().nContracts.get();
            val vSplits = sHandle().nSplits.get();
            val vReqs = sHandle().nReqs.get();
            val vSends = sHandle().nSends.get();
            /*at (masterP) {
                Console.OUT.print((p == here ? " " : " + ") + v);
                nContracts().value += v;
            }*/
            at (gContracts.home) {
                gContracts().set(gContracts()() + (p == here ? " " : " + ") + vContacts);
                nContracts().value += vContacts;
            }
            at (gSplits.home) {
                gSplits().set(gSplits()() + (p == here ? " " : " + ") + vSplits);
                nSplits().value += vSplits;
            }
            at (gReqs.home) {
                gReqs().set(gReqs()() + (p == here ? " " : " + ") + vReqs);
                nReqs().value += vReqs;
            }
            at (gSends.home) {
                gSends().set(gSends()() + (p == here ? " " : " + ") + vSends);
                nSends().value += vSends;
            }
        }
        Console.OUT.println(cContracts() + " = " + nContracts().value);
        Console.OUT.println(cSplits() + " = " + nSplits().value);
        Console.OUT.println(cReqs() + " = " + nReqs().value);
        Console.OUT.println(cSends() + " = " + nSends().value);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
