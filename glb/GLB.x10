package glb;

import x10.util.Team;
import x10.compiler.Inline;

/**
 * <p>The top level class of the Global Load Balancing (GLB) framework.
 * </p>
 */
public final class GLB[Queue, R]{Queue<:TaskQueue[Queue, R], R<:Arithmetic[R]} {
	/**
	 * Number of places.
	 */
	private val P = Place.MAX_PLACES;
	/**
	 * Home PlaceLocalHandle of {@link Worker}
	 */
	private val plh:PlaceLocalHandle[Worker[Queue, R]];
	
	/**
	 * Workload initialization time.
	 */
	var setupTime:Long;
	/**
	 * Computation time.
	 */
	var crunchNumberTime:Long;
	/**
	 * Result collection time.
	 */
	var collectResultTime:Long;
	
	/**
	 * {@link GLBResult at root. Used as a vehicle to collect results.}
	 */
	var rootGlbR: GLBResult[R] = null; // root glb result collector 
	
	/**
	 * Min helper method.
	 */
	@Inline static def min(i:Long, j:Long) = i < j ? i : j;
	
	/**
	 * GLB Parameters. {@link GLBParameters}
	 */
	var glbParams:GLBParameters;
	
	/**
	 * Constructor
	 * @param init function closure that can initialize {@link TaskQueue}
	 * @param glbParams GLB parameters
	 * @tree true if workload is dynamically generated, false if workload can be known upfront. 
	 */
	public def this(init:()=>Queue, glbParams:GLBParameters, tree:Boolean) {
		this.glbParams = glbParams;
		setupTime = System.nanoTime();
		plh = PlaceLocalHandle.makeFlat[Worker[Queue, R]](PlaceGroup.WORLD, 
				()=>new Worker[Queue, R](init, glbParams.n, glbParams.i, glbParams.li, glbParams.w, glbParams.l, glbParams.z, glbParams.m, tree));
		Worker.initContexts[Queue, R](plh);
		setupTime = System.nanoTime() - setupTime;
	}
	
	/**
	 * Returns Home {@link TaskQueue}
	 */
	public def taskQueue() = plh().queue;
	
	/**
	 * Run method. This method is called when users does not know the workload upfront.
	 * @param start The method that (Root) initializes the workload that can start computation.
	 * Other places first get their workload by stealing.
	 */
	public def run(start:()=>void):Rail[R] {
		crunchNumberTime = System.nanoTime();
		plh().main(plh, start);
		crunchNumberTime = System.nanoTime() - crunchNumberTime;
		r:Rail[R] = collectResults();
		//Console.OUT.println("Hello there!");
		end(r);
		return r;
	}
	
	/**
	 * Run method. This method is called when users can know the workload upfront and initialize the
	 * workload in {@link TaskQueue}
	 */
	public def runParallel() : Rail[R]{
		crunchNumberTime = System.nanoTime();
		Worker.broadcast[Queue,R](plh);
		crunchNumberTime = System.nanoTime() - crunchNumberTime;
		r:Rail[R] = collectResults();
		end(r);
		return r;
	}
	
	
	/**
	 * Print various GLB-related information, including result; time spent in initialization, computation 
	 * and result collection; any user specified log information (per place); and GLB statistics.
	 * @param r result to print
	 */
	private def end(r:Rail[R]):void{
		if((glbParams.v & GLBParameters.SHOW_RESULT_FLAG) != 0n){ // print result
			rootGlbR.display(r);
		}
		if((glbParams.v & GLBParameters.SHOW_TIMING_FLAG) != 0n ){ // print overall timing information
            Console.OUT.print("\"time (s)\" : {");
			Console.OUT.print("\"setup\":" + ((setupTime) / 1E9));
			Console.OUT.print(", \"process\":" + ((crunchNumberTime) / 1E9));
			Console.OUT.println(", \"result reduction\":" + (collectResultTime / 1E9) + "},");
			Console.OUT.println();
		}
		
		
		
		if((glbParams.v & GLBParameters.SHOW_TASKFRAME_LOG_FLAG) != 0n){ // print log
			printLog(plh);	
		}
		if((glbParams.v & GLBParameters.SHOW_GLB_FLAG) != 0n){ // collect glb statistics and print it out
			collectLifelineStatus(plh);	
		}
	}
	
	/**
	 * Collect GLB statistics
	 * @param st PlaceLocalHandle for {@link Worker}
	 */
	private def collectLifelineStatus(st:PlaceLocalHandle[Worker[Queue, R]]):void{
		val logs:Rail[Logger];
		//val groupSize:Long = 128;
		if (P >= 1024) {
			logs = new Rail[Logger](P/32, (i:Long)=>at (Place(i*32)) {
				val h = Runtime.hereLong();
				val n = min(32, P-h);
				val logs = new Rail[Logger](n, (i:Long)=>at (Place(h+i)) st().logger.get((this.glbParams.v & GLBParameters.SHOW_GLB_FLAG)!=0n));
				val log = new Logger(false);
				log.collect(logs);
				return log;
			});
		} else {
            Console.OUT.println("\"generic log\" : [");

			//logs = new Rail[Logger](P, (i:Long)=>at (Place(i)) st().logger.get((this.glbParams.v & GLBParameters.SHOW_GLB_FLAG)!=0n));
            logs = new Rail[Logger](P, (i:Long)=>at (Place(i)) { if (i>0) Console.OUT.print(", "); st().logger.get(true) });

            Console.OUT.println("],");
            Console.OUT.println();
		}
		val log = new Logger(false);
		log.collect(logs);
		log.stats();
	}
	
	/**
	 * Collect results from all places and reduce them to the final result.
	 * @return Final result.
	 */
	protected def collectResults():Rail[R]{
		collectResultTime = System.nanoTime();
      
		
		this.rootGlbR = plh().queue.getResult();
		val resultGlobal = GlobalRef[GLBResult[R]](rootGlbR);
		val tmpRail:Rail[R] = rootGlbR.submitResult();
        val tmpPlh = plh; // trick taught by Dave, caputure this.plh (as a pointer) instead
                          // of calling plh() directly inside the closure, which will encapsulate
                          // this (i.e. the whole rail of 
		/*PlaceGroup.WORLD.broadcastFlat(()=>{
			if(here == resultGlobal.home){
			    val tmpresultGlobal = resultGlobal as GlobalRef[GLBResult[R]]{self.home == here};
				Team.WORLD.allreduce(tmpresultGlobal().submitResult(), // Source buffer.
						0, // Offset into the source buffer.
						tmpresultGlobal().submitResult(), // Destination buffer.
						0, // Offset into the destination buffer.
						tmpresultGlobal().submitResult().size, // Number of elements.
						tmpresultGlobal().getReduceOperator()); // Operation to be performed.
			}else{
				glbR: GLBResult[R] = tmpPlh().queue.getResult();
				Team.WORLD.allreduce(glbR.submitResult(), // Source buffer.
						0, // Offset into the source buffer.
						glbR.submitResult(), // Destination buffer.
						0, // Offset into the destination buffer.
						glbR.submitResult().size, // Number of elements.
						glbR.getReduceOperator()); // Operation to be performed.
			}
		});
        */

        val it = PlaceGroup.WORLD.iterator();
        finish while (it.hasNext()) {
            val p:Place = it.next();
            if (p != here) at (p) async {
				glbR: GLBResult[R] = tmpPlh().queue.getResult();
                val r = glbR.submitResult();            
                at (resultGlobal.home)
                    resultGlobal().result(0) += r(0);
            }
        }

		collectResultTime = System.nanoTime() - collectResultTime;
		
		return tmpRail;
	}
	
	
	/**
	 * Print logging information on each place if user is interested in collecting per place
	 * information, i.e., statistics instrumented.
	 * @param st PLH for {@link Worker}
	 */
	private def printLog(st:PlaceLocalHandle[Worker[Queue, R]]):void{
        Console.OUT.println("\"user log\" : [");
		val P = Place.MAX_PLACES;
		for(var i:Long =0; i < P; ++i){
            val b = i>0;
			at(Place(i)){
                if (b) Console.OUT.print(", ");
				st().queue.printLog();
			}
		}
        Console.OUT.println("],");
        Console.OUT.println();
	}
}
