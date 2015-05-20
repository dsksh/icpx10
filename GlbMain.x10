import x10.compiler.*;
import x10.util.Option;
import x10.util.OptionsParser;
import x10.util.Box;
import x10.util.Random;
import x10.util.ArrayList;

import glb.GLB;
import glb.GLBParameters;

// kludge for "Interval is incomplete type" error
class Dummy_GlbMain {
    val dummy : Interval = new Interval(0.,0.);
    val dummy_result : BAPSolver.Result = BAPSolver.Result.unknown();
}

//public class GlbMain[K] extends RPX10[K] {
public class GlbMain[K] {
    val dummy : Interval = new Interval(0.,0.);
    val dummy_result : BAPSolver.Result = BAPSolver.Result.unknown();

    public static def init[K](core:BAPSolver.Core[K], prec:Double) {
//Console.OUT.println(here.id() + ": init");

        val tester = new VariableSelector.Tester[K]();
        val test = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => 
            tester.testPrec(prec, res, box, v);

        val selector = new VariableSelector[K](test);
        var select:(BAPSolver.Result,IntervalVec[K])=>Box[K];
        val selectBnd = (select0:(BAPSolver.Result,IntervalVec[K])=>Box[K]) =>
            ((res:BAPSolver.Result, box:IntervalVec[K]) =>
                selector.selectBoundary(select0, res, box) );
        select = selectBnd(
            (res:BAPSolver.Result, box:IntervalVec[K]) => selector.selectLRR(res, box) );

        return new Queue[K](core, select);
    }

    public static def main(args:Rail[String]) {
	    val opts = new OptionsParser(args, new Rail[Option](), [
            Option("n", "", "Number of nodes to process before probing. Default 100."),
            Option("i", "", "Time interval before probing."),
            Option("li", "", "Time interval before logging."),
            Option("w", "", "Number of thieves to send out. Default 1."),
            Option("l", "", "Base of the lifeline"),
            Option("m", "", "Max potential victims"),
            Option("v", "", "Verbose. Default 0 (no)."),
            
            Option("e", "", "Precision (epsilon)."),
            Option("f", "", "Filename of the model."),
            Option("p", "", "Problem ID.") ]);

        val n = opts("-n", 100n);
        val i = opts("-i", 0.1);
        val li = opts("-li", 0.1);
        val l = opts("-l", 32n);
        val m = opts("-m", 1024n);
        val verbose = opts("-v", GLBParameters.SHOW_RESULT_FLAG);

        val prec = opts("-e", 0.1);
        val filename = opts("-f", "hoge");
        val prob = opts("-p", 2n);

        val P = Place.numPlaces();

        var z0:Int = 1n;
        var zz:Int = l;
        while (zz < P) {
            z0++;
            zz *= l;
        }
        val z = z0;

        val w = opts("-w", z);

        Console.OUT.println("{");
        Console.OUT.println("\"problem\":");
        Console.OUT.println("  {\"filename\":\"" + filename +
            "\", \"p\":" + prob + ", \"e\":" + prec + "},");
        Console.OUT.println();
        Console.OUT.println("\"params\":");
        Console.OUT.println("  {\"places\":" + P +
            ", \"w\":" + w + ", \"n\":" + n + ", \"i\":" + i + ", \"li\":" + li + ", \"l\":" + l + ", \"m\":" + m + ", \"z\":" + z + "},");
        Console.OUT.println();
        val init = ()=>{ 
            val core = new IBEX10.CoreIArray(filename, prob);
            return GlbMain.init(core, prec); 
        };
        val glb = 
          new GLB[Queue[Long], Long](
          //new GLB[Queue[Long], SolutionSet[Long]](
            init, GLBParameters(n, i, li, w, l, z, m, verbose), true );
        glb.run(()=>{});

        Console.OUT.println("\"res\":" + 0);
        Console.OUT.println("}");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
