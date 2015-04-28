/*
 *  This file is part of the X10 project (http://x10-lang.org).
 *
 *  This file is licensed to You under the Eclipse Public License (EPL);
 *  You may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *      http://www.opensource.org/licenses/eclipse-1.0.php
 *
 *  (C) Copyright IBM Corporation 2006-2010.
 */

package x10.util;

import x10.compiler.NonEscaping;
import x10.io.CustomSerialization;
import x10.io.SerialData;

public class MyHashMap[K,V] implements Map[K,V], CustomSerialization {
    public static class HashEntry[Key,Value] implements Map.Entry[Key,Value] {
        public def getKey() = key;
        public def getValue() = value;
        public def setValue(v: Value) { value = v; }
        
        val key: Key;
        var value: Value;
        var removed: Boolean; 
        val hash: Int;
        
        def this(key: Key, value: Value, h: Int) {
            this.key = key;
            this.value = value;
            this.hash = h;
            this.removed = false;
        }
    }
    
    /** The actual table, must be of size 2**n */
    var table: IndexedMemoryChunk[HashEntry[K,V]];
    
    /** Number of non-null, non-removed entries in the table. */
    var size: Int;

    /** Number of non-null entries in the table. */
    var occupation: Int;
    
    /** table.length - 1 */
    var mask: Int;

	var modCount:Int = 0; // to discover concurrent modifications
    
    var shouldRehash: Boolean;

    static MAX_PROBES = 3;
    static MIN_SIZE = 4;
    
    public def this() {
        init(MIN_SIZE);
    }
    
    public def this(var sz: int) {
        var pow2: int = MIN_SIZE;
        while (pow2 < sz)
            pow2 <<= 1;
        init(pow2);
    }
    
    @NonEscaping final def init(sz: int): void {
        // check that sz is a power of 2
        assert (sz & -sz) == sz;
        assert sz >= MIN_SIZE;
    
        table = IndexedMemoryChunk.allocateZeroed[HashEntry[K,V]](sz);
        mask = sz - 1;
        size = 0;
        occupation = 0;
        shouldRehash = false;
    }

    public def clear(): void {
Console.OUT.println(here + ": mc clear");
        modCount++;
        init(MIN_SIZE);
    }
    
    protected def hash(k: K): Int = hashInternal(k);
    @NonEscaping protected final def hashInternal(k: K): Int {
        return k.hashCode() * 17;
    }
    
    public operator this(k: K): Box[V] = get(k);
    
    public def get(k: K): Box[V] {
        val e = getEntry(k);
        if (e == null || e.removed) return null;
        return new Box[V](e.value);
    }
    
    public def getOrElse(k: K, orelse: V): V {
        val e = getEntry(k);
        if (e == null || e.removed) return orelse;
        return e.value;
    }
    
    public def getOrThrow(k: K): V //throws NoSuchElementException
    {
        val e = getEntry(k);
        if (e == null || e.removed) throw new NoSuchElementException("Not found: " + k);
        return e.value;
    }
    
    protected def getEntry(k: K): HashEntry[K,V] {
        if (size == 0)
            return null;
 
// incompatible with iterators            
//        if (shouldRehash)
//            rehash();
            
        val h = hash(k);

        var i: int = h;

        while (true) {        
            val j = i & mask;
            i++;
            
            val e = table(j);
            if (e == null) {
                if (i - h > MAX_PROBES)
                    shouldRehash = true;
                return null;
            }
            if (e != null) {
                if (e.hash == h && k.equals(e.key)) {
                    if (i - h > MAX_PROBES)
                        shouldRehash = true;
                    return e;
                }
                if (i - h > table.length()) {
                    if (i - h > MAX_PROBES)
                        shouldRehash = true;
                    return null;
                }
            }
        }
    }
    
    public def put(k: K, v: V): Box[V] = putInternal(k,v);
    @NonEscaping protected final def putInternal(k: K, v: V): Box[V] {
        if (occupation == table.length() || (shouldRehash && occupation >= table.length() / 2))
            rehashInternal();

        val h = hashInternal(k);
        var i: int = h;

        while (true) {
            val j = i & mask;
            i++;
            
            val e = table(j);
            if (e == null) {
                if (i - h > MAX_PROBES)
                    shouldRehash = true;
Console.OUT.println(here + ": mc put");
                modCount++;
                table(j) = new HashEntry[K,V](k, v, h);
                size++;
                occupation++;
                return null;
            } else if (e.hash == h && k.equals(e.key)) {
//                if (i - h > MAX_PROBES)
//                    shouldRehash = true;
                val old = e.value;
                e.value = v;
                if (e.removed) {
                    e.removed = false;
                    size++;
                    return null;
                }
                return new Box[V](old);
            }
        }
    }
    
    public def rehash():void { rehashInternal(); }
    @NonEscaping protected final def rehashInternal(): void {
Console.OUT.println(here + ": mc rehash");
        modCount++;
        val t = table;
        val oldSize = size;
        table = IndexedMemoryChunk.allocateZeroed[HashEntry[K,V]](t.length()*2);
        mask = table.length() - 1;
        size = 0;
        occupation = 0;
        shouldRehash = false;

        for (var i: int = 0; i < t.length(); i++) {
            if (t(i) != null && ! t(i).removed) {
                putInternal(t(i).key, t(i).value);
                shouldRehash = false;
            }
        }
        assert size == oldSize;
        size = oldSize;
    }
    
    public def containsKey(k: K): boolean {
        val e = getEntry(k);
        return e != null && ! e.removed;
    }
    
    public def remove(k: K): Box[V] {
Console.OUT.println(here + ": mc remove");
        modCount++;
        val e = getEntry(k);
        if (e != null && ! e.removed) {
            size--;
            e.removed = true;
            return new Box[V](e.value);
        }
        return null;
    }
    
    public def keySet(): Set[K] = new KeySet[K,V](this);
    public def entries(): Set[Map.Entry[K,V]] = new EntrySet[K,V](this);
    
    protected def entriesIterator(): Iterator[HashEntry[K,V]] {
        val iterator = new EntriesIterator[K,V](this);
        iterator.advance();
        return iterator;
    }

    protected static class EntriesIterator[Key,Value] implements Iterator[HashEntry[Key,Value]] {
        val map: MyHashMap[Key,Value];
        var i: Int;
		var originalModCount:Int;
        
        public def this(map: MyHashMap[Key,Value]) { 
            this.map = map; 
            this.i = 0; 
Console.OUT.println(here + ": i0: " + i);
            originalModCount = map.modCount; 
        } // you call advance() after the ctor

        public def this(lhs: EntriesIterator[Key,Value], map: MyHashMap[Key,Value]) { 
            this.map = map; 
            this.i = lhs.i; 
Console.OUT.println(here + ": i0: " + i);
            originalModCount = map.modCount; 
            //originalModCount = lhs.originalModCount; 
        }

        public def advance(): void {
            while (i < map.table.length()) {
               if (map.table(i) != null && ! map.table(i).removed)
                   return;
               i++;
            }
Console.OUT.println(here + ": ia: " + i);
        }
        
        public def hasNext(): Boolean {
            if (i < map.table.length()) {
//              assert map.table(i) != null && ! map.table(i).removed : "map entry " + i + " is null or removed";
                return true;
            }
            return false;
        }
        
        public def next(): HashEntry[Key,Value] {
			if (originalModCount!=map.modCount) throw new Exception("Your code has a concurrency bug! You updated the hashmap "+(map.modCount-originalModCount)+" times since you created the iterator.");
            val j = i;
//            assert map.table(j) != null && ! map.table(j).removed : "map entry " + j + " is null or removed";
            i++;
            advance();
            return map.table(j) ;
        }

        public def pi() {
Console.OUT.println(here + ": i: " + i);
        }
    }
    
    public def size() = size;
    
    public static class KeyIterator[Key,Value] implements Iterator[Key] {
        val i : EntriesIterator[Key,Value];
        val f : (HashEntry[Key,Value]) => Key;

        public def this(i:EntriesIterator[Key,Value], f:(HashEntry[Key,Value])=>Key) {
            this.i = i;
            this.f = f;
        }
        def this(lhs:KeyIterator[Key,Value], map:MyHashMap[Key,Value]) {
            this(new EntriesIterator[Key,Value](lhs.i, map), lhs.f);
        }

        public def hasNext() : Boolean = i.hasNext();
        public def next() : Key = f(i.next());

        public def pi() { i.pi(); }

        public def clone(map: MyHashMap[Key,Value]) : KeyIterator[Key,Value] { return new KeyIterator[Key,Value](this, map); }
    }

    public def keyIterator(): KeyIterator[K,V] {
        val iterator = new EntriesIterator[K,V](this);
        iterator.advance();
        return new KeyIterator[K,V](iterator, (e: HashEntry[K,V]) => e.key);
    }

    protected static class KeySet[Key,Value] extends AbstractCollection[Key] implements Set[Key] {
        val map: MyHashMap[Key,Value];
        
        def this(map: MyHashMap[Key,Value]) { this.map = map; }
        
        public def iterator(): Iterator[Key] {
        //public def keyIterator(): KeyIterator[Key,Value] {
            //return new MapIterator[HashEntry[Key,Value],Key](map.entriesIterator(), (e: HashEntry[Key,Value]) => e.key);
            val iterator = new EntriesIterator[Key,Value](map);
            iterator.advance();
            return new KeyIterator[Key,Value](iterator, (e: HashEntry[Key,Value]) => e.key);
        }
        
        public def contains(k: Key) {
            return map.containsKey(k);
        }
        
        public def add(k: Key): Boolean { throw new UnsupportedOperationException(); }
        public def remove(k: Key): Boolean { throw new UnsupportedOperationException(); }
        public def clone(): KeySet[Key,Value] { throw new UnsupportedOperationException(); }
        public def size(): Int = map.size();
    }

    protected static class EntrySet[Key,Value] 
           extends AbstractCollection[Map.Entry[Key,Value]] 
           implements Set[Map.Entry[Key,Value]] {
        val map: MyHashMap[Key,Value];
        
        def this(map: MyHashMap[Key,Value]) { this.map = map; }
        
        public def iterator(): Iterator[Map.Entry[Key,Value]] {
            return new MapIterator[HashEntry[Key,Value],Map.Entry[Key,Value]](map.entriesIterator(), 
            		(e: HashEntry[Key,Value]):Map.Entry[Key,Value] => e);
        }
        
        public def contains(k: Map.Entry[Key,Value]): Boolean { throw new UnsupportedOperationException(); }
        public def add(k: Map.Entry[Key,Value]): Boolean { throw new UnsupportedOperationException(); }
        public def remove(k: Map.Entry[Key,Value]): Boolean { throw new UnsupportedOperationException(); }
        public def clone(): EntrySet[Key,Value] { throw new UnsupportedOperationException(); }
        public def size(): Int = map.size();
    }


    protected static class State[Key,Value] {
        val content:Array[Pair[Key,Value]](1);

        def this(map:MyHashMap[Key,Value]) {
            val size = map.size();
            val it = map.entriesIterator();
            content = new Array[Pair[Key,Value]](size,
              (p:Int) => {
                   val entry = it.next();
                   return Pair[Key,Value](entry.getKey(),entry.getValue());
              }
            );
        }
    }

    /*
     * Custom deserialization
     */
    public def this(x:SerialData) {
        this();
        val state = x.data as State[K,V]; // Warning: This is an unsound cast because the object or the target type might have constraints and X10 currently does not perform constraint solving at runtime on generic parameters.
	    for (p in state.content) {
	        val pair = state.content(p);
            putInternal(pair.first, pair.second);
        }
    }

    /*
     * Custom serialization
     */
    public def serialize():SerialData = new SerialData(new State(this), null);
}
