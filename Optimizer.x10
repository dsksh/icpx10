import x10.compiler.*;
import x10.util.Option;
import x10.util.OptionsParser;
import x10.util.Box;
import x10.io.File;
import x10.io.FileWriter;

import glb.GLB;
import glb.GLBParameters;

public class Optimizer[K] {

    public static def init[K,R](core:BAPSolverOpt.Core[K], prec:Double,
                                initResult:(Rail[IntervalVec[K]], Interval)=>R) {

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

        return new GlbQueueImplOpt[K,R](core, select, initResult);
    }

    public static def main(args:Rail[String]) {
	    val opts = new OptionsParser(args, new Rail[Option](), [
            Option("-n", "", "Number of nodes to process before probing. Default 100.", 1n),
            Option("-i", "", "Time interval before probing."),
            Option("-li", "", "Time interval before logging."),
            Option("-w", "", "Number of thieves to send out. Default 1."),
            Option("-l", "", "Base of the lifeline"),
            Option("-m", "", "Max potential victims"),
            Option("-v", "", "Verbose. Default 0 (no)."),
            
            Option("-e", "", "Precision (epsilon)."),
            Option("-f", "", "Filename of the model."),
            Option("-p", "", "Problem ID."),

            Option("-o", "", "Filename of the paving output.") ]);

        val n = opts("-n", 100n);
        val i = opts("-i", 0.1);
        val li = opts("-li", 0.1);
        val l = opts("-l", 32n);
        val m = opts("-m", 1024n);
        val verbose = opts("-v", GLBParameters.SHOW_RESULT_FLAG);

        val prec = opts("-e", 0.1);
        val filename = opts("-f", "hoge");
        val prob = opts("-p", 2n);

        val outputFilaname = opts("-o", "");

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
            val core = new IbexAdapter.CoreOpt();
            if (!core.initialize(filename, prob))
                throw new Exception("initialization failed.");
            //val initR = (sols:Rail[IntervalVec[Long]])=>{ return sols.size; };
            val initR = (sols:Rail[IntervalVec[Long]], obj:Interval)=>
                { return GlbResultImpl.Paving[Long](sols, obj); };
            //return Optimizer.init[Long,Long](core, prec, initR); 
            return Optimizer.init[Long,GlbResultImpl.Paving[Long]](core, prec, initR); 
        };
        val glb = 
          //new GLB[GlbQueueImplOpt[Long,Long], Long](
          new GLB[GlbQueueImplOpt[Long,GlbResultImpl.Paving[Long]], GlbResultImpl.Paving[Long]](
            init, GLBParameters(n, i, li, w, l, z, m, verbose), true );
        val res = glb.run(()=>{});

        if (outputFilaname != "") {
            val writer = new FileWriter(new File(outputFilaname));
            //for (v in res(0).data) {
            //    writer.write(v + "\n\n");
            //    writer.flush();
            //}
            writer.write("" + res(0));
        }

        Console.OUT.println("\"res\":" + 0);
        Console.OUT.println("}");
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
