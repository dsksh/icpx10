//package legacy;

import x10.compiler.*;
import x10.util.Option;
import x10.util.OptionsParser;
import x10.util.Box;
import x10.util.Random;
import x10.util.ArrayList;
import x10.util.StringBuilder;
import x10.regionarray.Dist;

import glb.GLB;
import glb.GLBParameters;

// kludge for "Interval is incomplete type" error
class Dummy_Main {
    val dummy : Interval = new Interval(0.,0.);
    val dummy_result : BAPSolver.Result = BAPSolver.Result.unknown();
}

public class Main[K] extends RPX10[K] {
    static def format(t:Long) = (t as Double) * 1.0e-9;

    static def setup[K](core:BAPSolver.Core[K], args:Rail[String]) : PlaceAgent[K] {

        val tester = new VariableSelector.Tester[K]();
        var an:Long = 2;
        val prec = Double.parse(args(an++));
        //val debug = Boolean.parse(args(an++));
        val test = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => 
            tester.testPrec(prec, res, box, v);
//        val test1 = (res:BAPSolver.Result, box:IntervalVec[K], v:K) => 
//            tester.testRegularity(test, (v:K)=>!core.isProjected(v), res, box, v);

        val selector = new VariableSelector[K](test);
        var select:(BAPSolver.Result,IntervalVec[K])=>Box[K];
        val selectBnd = (select0:(BAPSolver.Result,IntervalVec[K])=>Box[K]) =>
            ((res:BAPSolver.Result, box:IntervalVec[K]) =>
                selector.selectBoundary(select0, res, box) );
        switch (Int.parse(args(an++))) {
        case 0n:
            select = selectBnd(
                (res:BAPSolver.Result, box:IntervalVec[K]) =>
                     selector.selectGRR(res, box) );
            break;
        case 1n:
            select = selectBnd(
                (res:BAPSolver.Result, box:IntervalVec[K]) =>
                     selector.selectLRR(res, box) );
            break;
        default:
            select = selectBnd(
                (res:BAPSolver.Result, box:IntervalVec[K]) =>
                     selector.selectLF(res, box) );
            break;
        }

        var solver:BAPSolverImpl[K] = null;
        switch (Int.parse(args(an++))) {
        case 0n:
            solver = new BAPSolverImpl[K](core, select);
            break;
        case 1n:
            solver = new BAPListSolver[K](core, select);
            break;
        case 2n:
            solver = new BAPSolverSimple[K](core, select);
            break;
        case 3n:
            solver = new BAPSolverDumb[K](core, select);
            break;
        default:
            solver = new BAPListSolver[K](core, select);
        }

        switch (Int.parse(args(an++))) {
        case 0n:
            return new PlaceAgent[K](solver);
        case 1n:
            //return new PlaceAgentSeparated[K](solver);
            return new PlaceAgentSeqSI[K](solver);
        case 11n:
            return new PlaceAgentSeqSID[K](solver);
        //case 2n:
        //    //return new PlaceAgentClockedRequest[K](solver);
        //    return new PlaceAgentClockedSI[K](solver);
        case 4n: {
            val pa = new PlaceAgentSeq[K](solver);
            val pp = new PreprocessorSeq[K](core, prec, pa);
            pa.setPreprocessor(pp);
            return pa;
        }
        //case 5n: {
        //    val pa = new PlaceAgentClockedSI[K](solver);
        //    val pp = new PreprocessorClocked[K](core, prec, pa);
        //    pa.setPreprocessor(pp);
        //    return pa;
        //}
        case 6n: {
            val pa = new PlaceAgentSeqSI[K](solver);
            val pp = new PreprocessorSeq[K](core, prec, pa);
            pa.setPreprocessor(pp);
            return pa;
        }
        case 16n: {
            val pa = new PlaceAgentSeqSID[K](solver);
            val pp = new PreprocessorSeq[K](core, prec, pa);
            pa.setPreprocessor(pp);
            return pa;
        }
        case 7n: {
            val pa = new PlaceAgentSeqRI[K](solver);
            val pp = new PreprocessorSeq[K](core, prec, pa);
            pa.setPreprocessor(pp);
            return pa;
        }
        default:
            val pa = new PlaceAgentDelayed[K](solver);
            pa.initPP(core, prec);
            return pa;
        }
    }

    // kludge for a success of compilation
    val dummy:Double = 0.;
    val dummyI:Interval = new Interval(0.,0.);
    val dummyR:BAPSolver.Result = BAPSolver.Result.unknown();

    public static def main(args:Rail[String]) {

        if (args.size < 6) {
            Console.OUT.println("usage: RPX10 prob.rp n prec sel solver pagent");
            return;
        }

        Console.OUT.print("\n{\"args\" : \"" + args + "\",");
		Console.OUT.println("\"# places\" : " + Place.numPlaces() + "}\n");

        // create a solver at each place
        val everyone = Dist.makeUnique();
        val sHandle = PlaceLocalHandle.make[PlaceAgent[Long]](
            //everyone, 
            Place.places(),
            ()=> {
                val main = new Main[Long]();
                val core = new CoreIArray(args(0), Int.parse(args(1)));
                return main.setup[Long](core, args);
            } );

        val masterP = here;

        var time0:Long = System.nanoTime();
        //finish 
        //for (p in Place.places()) at (p) async 
        sHandle().setup(sHandle);

        //@Pragma(Pragma.FINISH_SPMD) 
        finish for (p in Place.places()) at (p) async {
            sHandle().run(sHandle);
        }

        var time:Long = System.nanoTime() - time0;

        // print solutions
        //Console.OUT.println(); 
        //for (p in Place.places()) { 
        //at (p) {
        //    val ss = sHandle().getSolutions();
        //    val it = ss.iterator();
        //    while (it.hasNext()) {
        //        val pair = it.next();
        //        val plot = pair.first.entails(BAPSolver.Result.inner()) ? 5 : 3;
        //        val stringB = pair.second.toString(plot);
        //at (Place(0)) {
        //        Console.OUT.println(stringB);
        //        Console.OUT.println(); 
        //        Console.OUT.flush();
        //}
        //    }
        //}
	      //  Console.OUT.flush();
        //}

        // print count
        //Console.OUT.println(); 
        //for (p in Place.places()) { 
		  //at (p) {
        //    val ss = sHandle().getSolutions();
        //    var max:Int = 0;
        //    var avg:Int = 0;
        //    for (pair in ss) {
        //        val c = pair.second.count();
        //        if (c > max) max = c;
        //        avg += c;
        //    }
        //    avg /= ss.size();

        //    Console.OUT.println("{\"count max\" : " + max + ", \"count avg\" : " + avg + "}");
        //    Console.OUT.println(); 
        //}
	      //  Console.OUT.flush();
        //}

        // print load log
        Console.OUT.println(); 
        val sbLog = new StringBuilder();
        val sbLogG = new GlobalRef[StringBuilder](sbLog);
        sbLog.add("{");
        var first:Boolean = true;
        for (p in Place.places()) { 
            if (first) first = false;
            else
                sbLog.add(",\n");
    		finish at (p) {
                val sbl = new StringBuilder();
                sbl.add("{");
                val ld = (sHandle() as PlaceAgentSeqSID[Long]).logData;
                var f:Boolean = true;
                for (lp in ld) {
                    if (f) f = false;
                    else
                        sbl.add(",");
                    sbl.add("{"+lp.first+","+lp.second+"}");
                }
                sbl.add("}");
                at (sbLogG.home) sbLogG().add(sbl.result());
            }
        }
        sbLog.add("}");
        Console.OUT.println(sbLog);
        Console.OUT.println();
        Console.OUT.flush();

        // print description of the solving process.
        val sb = new StringBuilder();
        val sbG = new GlobalRef[StringBuilder](sb);
        sb.add("{\"summary\" : {");
        sb.add(" \"time (s)\" : " + format(time) + ",\n");

        // sum up the # solutions at each place
        val nSols = new GlobalRef(new Cell(0));
        sb.add("  \"# sols (sep)\" : [");
        for (p in Place.places()) at (p) {
            val v = sHandle().nSols;//.get();
            at (masterP) {
                at (sbG.home)
                    sbG().add((p == here ? " " : ", ") + v);
                nSols().value += v;
            }
        }
        sb.add("],");
        sb.add(" \"# sols\" : " + nSols().value + ",\n");

        // sum up the # contracts at each place
        val tEndPP     = new GlobalRef(new Cell(0.));
        //val tSearch    = new GlobalRef(new Cell(0.));
        val nContracts = new GlobalRef(new Cell(0));
        //val tContracts = new GlobalRef(new Cell(0.));
        val nSplits    = new GlobalRef(new Cell(0));
        val nReqs      = new GlobalRef(new Cell(0));
        val nSends     = new GlobalRef(new Cell(0));
        val nSentBoxes = new GlobalRef(new Cell(0));
        val tWaitComm  = new GlobalRef(new Cell(0.));
        val tBoxSend   = new GlobalRef(new Cell(0.));
        val nIters     = new GlobalRef(new Cell(0));
        val cTEndPP	   = new Cell[String]("  \"time pp (sep)\" : ["); 
        val cTSearch   = new Cell[String]("  \"time search (sep)\" : ["); 
        val cContracts = new Cell[String]("  \"# contracts (sep)\" : ["); 
        val cTContracts = new Cell[String]("  \"time contracts (sep)\" : ["); 
        val cSplits    = new Cell[String]("  \"# splits (sep)\" : ["); 
        val cReqs      = new Cell[String]("  \"# reqs (sep)\" : ["); 
        val cSends     = new Cell[String]("  \"# sends (sep)\" : ["); 
        val cSentBoxes = new Cell[String]("  \"# sent boxes (sep)\" : ["); 
        val cTWaitComm = new Cell[String]("  \"time waiting (sep)\" : ["); 
        val cTBoxSend = new Cell[String]("  \"time sending boxes (sep)\" : ["); 
        val cIters     = new Cell[String]("  \"# iters (sep)\" : ["); 
        val gTEndPP    = GlobalRef[Cell[String]](cTEndPP);
        val gTSearch   = GlobalRef[Cell[String]](cTSearch);
        val gContracts = GlobalRef[Cell[String]](cContracts);
        val gTContracts = GlobalRef[Cell[String]](cTContracts);
        val gSplits    = GlobalRef[Cell[String]](cSplits);
        val gReqs      = GlobalRef[Cell[String]](cReqs);
        val gSends     = GlobalRef[Cell[String]](cSends);
        val gSentBoxes = GlobalRef[Cell[String]](cSentBoxes);
        val gTWaitComm = GlobalRef[Cell[String]](cTWaitComm);
        val gTBoxSend = GlobalRef[Cell[String]](cTBoxSend);
        val gIters     = GlobalRef[Cell[String]](cIters);
        for (p in Place.places()) at (p) {
            val vTEndPP = format(sHandle().tEndPP);
            //val vContacts = sHandle().nContracts.get();
            val vContacts = sHandle().nContracts;
            //val vSplits = sHandle().nSplits.get();
            val vSplits = sHandle().nSplits;
            //val vReqs = sHandle().nReqs.get();
            //val vSends = sHandle().nSends.get();
            val vReqs = sHandle().nReqs;
            val vSends = sHandle().nSends.get();
            val vSentBoxes = sHandle().nSentBoxes.get();
            val vTSearch = format(sHandle().tSearch);
            //val vTContacts = format(sHandle().tContracts.get());
            val vTContacts = format(sHandle().tContracts);
            val vTWaitComm = format(sHandle().tWaitComm);
            val vTBoxSend = format(sHandle().tBoxSend.get());
            val vIters = sHandle().nIters;
            at (tEndPP.home) {
                gTEndPP().set(gTEndPP()() + (p == here ? "" : ", ") + vTEndPP);

                if (tEndPP().value < vTEndPP)
                    tEndPP().value += vTEndPP - tEndPP().value;
                    // TODO: this becomes a contraint error.
                    //tEndPP().value = vTEndPP;

                gTSearch().set(gTSearch()() + (p == here ? "" : ", ") + vTSearch);
                //tSearch().value += vTSearch;

                gContracts().set(gContracts()() + (p == here ? "" : ", ") + vContacts);
                nContracts().value += vContacts;

                gTContracts().set(gTContracts()() + (p == here ? "" : ", ") + vTContacts);
                //tContracts().value += vTContacts;

                gSplits().set(gSplits()() + (p == here ? "\n" : ",\n") + vSplits);
                nSplits().value += vSplits;

                gReqs().set(gReqs()() + (p == here ? "" : ", ") + vReqs);
                nReqs().value += vReqs;

                gSends().set(gSends()() + (p == here ? "" : ", ") + vSends);
                nSends().value += vSends;

                gSentBoxes().set(gSentBoxes()() + (p == here ? "" : ", ") + vSentBoxes);
                nSentBoxes().value += vSentBoxes;

                gTWaitComm().set(gTWaitComm()() + (p == here ? "" : ", ") + vTWaitComm);
                tWaitComm().value += vTWaitComm;

                gIters().set(gIters()() + (p == here ? "" : ", ") + vIters);
                nIters().value += vIters;

                gTBoxSend().set(gTBoxSend()() + (p == here ? "" : ", ") + vTBoxSend);
                tBoxSend().value += vTBoxSend;
            }
        }
        sb.add(cTEndPP() + "],\n");
        //if (tEndPP().value > time0)
        //    sb.add("  \"time pp (s)\" : " + format(tEndPP().value - time0) + ",\n");
        if (tEndPP().value > 0.)
        	sb.add("  \"time pp (s)\" : " + tEndPP().value + ",\n");
        sb.add(cTSearch() + "],\n");
        sb.add(cContracts() + "], \"# contracts\" : " + nContracts().value + ",\n");
        sb.add(cTContracts() + "],\n");
        sb.add(cContracts() + "], \"# contracts\" : " + nContracts().value + ",\n");
        sb.add(cSplits()    + "\n],    \"# splits\" : " + nSplits().value + ",\n");
        sb.add(cTWaitComm() + "],\n");
        sb.add("  \"time waiting\" : " + tWaitComm().value + ",\n");
        sb.add(cTBoxSend() + "],\n");
        sb.add("  \"time sending boxes\" : " + tBoxSend().value + ",\n");
        sb.add(cIters()     + "], \"# iters\" : " + nIters().value + ",\n");
        sb.add(cReqs()      + "], \"# reqs\" : " + nReqs().value + ",\n");
        sb.add(cSends()     + "], \"# sends\" : " + nSends().value + ",\n");
        sb.add(cSentBoxes() + "], \"# sent boxes\" : " + nSentBoxes().value);
        sb.add(" } }");

        Console.OUT.flush();
        Console.OUT.println(sb);
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
