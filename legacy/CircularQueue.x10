/*
 *
 *  This file is licensed to You under the Eclipse Public License (EPL);
 *  You may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *      http://www.opensource.org/licenses/eclipse-1.0.php
 *
 *  (C) Copyright IBM Corporation 2006-2010.
 */
import x10.util.concurrent.*;

/**
 * A thread-safe implementation of a queue using a modest circular buffer
 * (instead of a giant linear one as in NaiveQueueue.x10 or CleverQueue.x10).  
 */
public class CircularQueue[T]{T haszero} {
	/** the maximum queue length we'll allow */
	public val maximumSize: Long;
	/** if read mod maximumSize, the index of the first entry, if any */
	private var first: Long = 0;
	/** if read mod maximumSize, the index of the next slot to store into */
	private var  next:  Long = 0;
	/** bounded buffer to hold entries */
	public val buffer: Rail[T];

	/**
	 * create a queue with the argument as its maximum size and the
	 * default zero for T used to populate the buffer.
	 * @param sizeLimit a bound on the number of entries permitted
	 */
	public def this(sizeLimit:Long) { this(sizeLimit, Zero.get[T]()); }
	/**
	 * create a queue with the argument as its maximum size and the
	 * buffer populated with the initial value.
	 * @param sizeLimit a bound on the number of entries permitted
	 */
	public def this(sizeLimit:Long, initialValue:T) { 
	   this.maximumSize = sizeLimit;
	   this.buffer = new Rail[T](sizeLimit, initialValue);
	}
    public def clear() {
       first = 0; next = 0;
    }
   /**
    * Addition of an element at the end of the queue.
    * @param t the item to be added
    * @return this
    */
	public def addLast(t: T): CircularQueue[T] {
//Console.OUT.println(here + ": capa: " + (next - first));
	   when(next - first < maximumSize) {
	      this.buffer(next++ % this.maximumSize) = t;
	   }
	   return this;
	}
   /**
    * removes and returns the element at the beginning of the queue
	 * @return the element removed
    */
	public def removeFirst(): T {
	   when(first < next) {
	      return this.buffer(first++ % this.maximumSize);
	   }
	}
	public def removeFirstUnsafe(): T {
       return this.buffer(first++ % this.maximumSize);
	}
	public def getFirstUnsafe(): T {
       return this.buffer(first % this.maximumSize);
	}
	/** returns the number of elements in the queue */
	public def getSize(): Long { atomic { return next -first; }}
}
