/*
 * Copyright (c) 1997, 2011, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  Oracle designates this
 * particular file as subject to the "Classpath" exception as provided
 * by Oracle in the LICENSE file that accompanied this code.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */

/**
 * Doubly-linked list implementation of the {@code List} and {@code Deque}
 * interfaces.  Implements all optional list operations, and permits all
 * elements (including {@code null}).
 *
 * <p>All of the operations perform as could be expected for a doubly-linked
 * list.  Operations that index into the list will traverse the list from
 * the beginning or the end, whichever is closer to the specified index.
 *
 * <p><strong>Note that this implementation is not synchronized.</strong>
 * If multiple threads access a linked list concurrently, and at least
 * one of the threads modifies the list structurally, it <i>must</i> be
 * synchronized externally.  (A structural modification is any operation
 * that adds or deletes one or more elements; merely setting the value of
 * an element is not a structural modification.)  This is typically
 * accomplished by synchronizing on some object that naturally
 * encapsulates the list.
 *
 * If no such object exists, the list should be "wrapped" using the
 * {@link Collections#synchronizedList Collections.synchronizedList}
 * method.  This is best done at creation time, to prevent accidental
 * unsynchronized access to the list:<pre>
 *   List list = Collections.synchronizedList(new LinkedList(...));</pre>
 *
 * <p>The iterators returned by this class's {@code iterator} and
 * {@code listIterator} methods are <i>fail-fast</i>: if the list is
 * structurally modified at any time after the iterator is created, in
 * any way except through the Iterator's own {@code remove} or
 * {@code add} methods, the iterator will throw a {@link
 * ConcurrentModificationException}.  Thus, in the face of concurrent
 * modification, the iterator fails quickly and cleanly, rather than
 * risking arbitrary, non-deterministic behavior at an undetermined
 * time in the future.
 *
 * <p>Note that the fail-fast behavior of an iterator cannot be guaranteed
 * as it is, generally speaking, impossible to make any hard guarantees in the
 * presence of unsynchronized concurrent modification.  Fail-fast iterators
 * throw {@code ConcurrentModificationException} on a best-effort basis.
 * Therefore, it would be wrong to write a program that depended on this
 * exception for its correctness:   <i>the fail-fast behavior of iterators
 * should be used only to detect bugs.</i>
 *
 * <p>This class is a member of the
 * <a href="{@docRoot}/../technotes/guides/collections/index.html">
 * Java Collections Framework</a>.
 *
 * @author  Josh Bloch
 * @see     List
 * @see     ArrayList
 * @since 1.2
 * @param [E] the type of elements held in this collection
 */

import x10.util.*;

public class LinkedList[E] extends AbstractCollection[E] implements List[E] {

    var size:Long = 0;

    protected var modCount:Long = 0;

    /**
     * Pointer to first node.
     * Invariant: (first == null && last == null) ||
     *            (first.prev == null && first.item != null)
     */
    var first:Node[E];

    /**
     * Pointer to last node.
     * Invariant: (first == null && last == null) ||
     *            (last.next == null && last.item != null)
     */
    var last:Node[E];

    /**
     * Constructs an empty list.
     */
    public def this() {
    }

//    /**
//     * Constructs a list containing the elements of the specified
//     * collection, in the order they are returned by the collection's
//     * iterator.
//     *
//     * @param  c the collection whose elements are to be placed into this list
//     * @throws NullPointerException if the specified collection is null
//     */
//    public def this(c:Collection[E]) {
//        addAll(c);
//    }

    public static def make[E](c: Container[E]) {
	    val l = new LinkedList[E]();
   		l.addAll(c);
	    return l;
    }

    /**
     * Returns {@code true} if this list contains the specified element.
     * More formally, returns {@code true} if and only if this list contains
     * at least one element {@code e} such that
     * <tt>(o==null&nbsp;?&nbsp;e==null&nbsp;:&nbsp;o.equals(e))</tt>.
     *
     * @param o element whose presence in this list is to be tested
     * @return {@code true} if this list contains the specified element
     */
    public def contains(o:E): Boolean {
        return indexOf(o) != -1;
    }

    /**
     * Removes all of the elements from this list.
     * The list will be empty after this call returns.
     */
    public def clear() {
        // Clearing all of the links between nodes is "unnecessary", but:
        // - helps a generational GC if the discarded nodes inhabit
        //   more than one generation
        // - is sure to free memory even if there is a reachable Iterator
        for (var x:Node[E] = first; x != null; ) {
            val next:Node[E] = x.next;
            x.item = null;
            x.next = null;
            x.prev = null;
            x = next;
        }
        first = last = null;
        size = 0;
        modCount++;
    }

    /**
     * Returns a shallow copy of this {@code LinkedList}. (The elements
     * themselves are not cloned.)
     *
     * @return a shallow copy of this {@code LinkedList} instance
     */
//    public def clone() {
//        val clone:LinkedList[E] = superClone();
//
//        // Put clone into "virgin" state
//        clone.first = clone.last = null;
//        clone.size = 0;
//        clone.modCount = 0;
//
//        // Initialize clone with our elements
//        for (var x:Node[E] = first; x != null; x = x.next)
//            clone.add(x.item);
//
//        return clone;
//    }
    public def clone() {
        val clone = new LinkedList[E]();
        clone.addAll(this);
        return clone;
    }

    /**
     * Appends the specified element to the end of this list.
     *
     * <p>This method is equivalent to {@link #addLast}.
     *
     * @param e element to be appended to this list
     * @return {@code true} (as specified by {@link Collection#add})
     */
    public def add(e:E): Boolean {
if (e == null) Console.ERR.println("adding null!");
        linkLast(e);
        return true;
    }

    /**
     * Inserts the specified element at the beginning of this list.
     *
     * @param e the element to add
     */
    public def addFirst(e:E): void {
if (e == null) Console.ERR.println("adding null!");
        linkFirst(e);
    }

    /**
     * Appends the specified element to the end of this list.
     *
     * <p>This method is equivalent to {@link #add}.
     *
     * @param e the element to add
     */
    public def addLast(e:E): void {
if (e == null) Console.ERR.println("adding null!");
        linkLast(e);
    }

    /**
     * Inserts the specified element at the specified position in this list.
     * Shifts the element currently at that position (if any) and any
     * subsequent elements to the right (adds one to their indices).
     *
     * @param index index at which the specified element is to be inserted
     * @param element element to be inserted
     * @throws IndexOutOfBoundsException {@inheritDoc}
     */
    public def addBefore(index:Long, element:E): void {
        checkPositionIndex(index);
if (element == null) Console.ERR.println("adding null!");

        if (index == size)
            linkLast(element);
        else
            linkBefore(element, node(index));
    }

    public operator this(i:Long)=(v:E): E = set(v, i);

    /**
     * Replaces the element at the specified position in this list with the
     * specified element.
     *
     * @param index index of the element to replace
     * @param element element to be stored at the specified position
     * @return the element previously at the specified position
     * @throws IndexOutOfBoundsException {@inheritDoc}
     */
    public def set(element:E, index:Long): E {
        checkElementIndex(index);
if (element == null) Console.ERR.println("adding null!");
        val x:Node[E] = node(index);
        val oldVal:E = x.item();
        x.item = new Box[E](element);
        return oldVal;
    }

    /**
     * Appends all of the elements in the specified collection to the end of
     * this list, in the order that they are returned by the specified
     * collection's iterator.  The behavior of this operation is undefined if
     * the specified collection is modified while the operation is in
     * progress.  (Note that this will occur if the specified collection is
     * this list, and it's nonempty.)
     *
     * @param c collection containing elements to be added to this list
     * @return {@code true} if this list changed as a result of the call
     * @throws NullPointerException if the specified collection is null
     */
    public def addAll(c:Collection[E]): Boolean {
        return addAll(size, c);
    }

    /**
     * Inserts all of the elements in the specified collection into this
     * list, starting at the specified position.  Shifts the element
     * currently at that position (if any) and any subsequent elements to
     * the right (increases their indices).  The new elements will appear
     * in the list in the order that they are returned by the
     * specified collection's iterator.
     *
     * @param index index at which to insert the first element
     *              from the specified collection
     * @param c collection containing elements to be added to this list
     * @return {@code true} if this list changed as a result of the call
     * @throws IndexOutOfBoundsException {@inheritDoc}
     * @throws NullPointerException if the specified collection is null
     */
    public def addAll(index:Long, c:Collection[E]): Boolean {
//        checkPositionIndex(index);
//
//        Object[] a = c.toArray();
//        int numNew = a.length;
//        if (numNew == 0)
//            return false;
//
//        Node[E] pred, succ;
//        if (index == size) {
//            succ = null;
//            pred = last;
//        } else {
//            succ = node(index);
//            pred = succ.prev;
//        }
//
//        for (Object o : a) {
//            @SuppressWarnings("unchecked") E e = (E) o;
//            Node[E] newNode = new Node<>(pred, e, null);
//            if (pred == null)
//                first = newNode;
//            else
//                pred.next = newNode;
//            pred = newNode;
//        }
//
//        if (succ == null) {
//            last = pred;
//        } else {
//            pred.next = succ;
//            succ.prev = pred;
//        }
//
//        size += numNew;
//        modCount++;
//        return true;

        checkPositionIndex(index);

		var pred:Node[E], succ:Node[E];
        if (index == size) {
            succ = null;
            pred = last;
        } else {
            succ = node(index);
            pred = succ.prev;
        }

        //val a = c.toArray();
        //val numNew = a.length;

		var numNew:Long = 0;
        for (e in c) {
            //@SuppressWarnings("unchecked") E e = (E) o;
            val newNode = new Node[E](pred, e, null);
            if (pred == null)
                first = newNode;
            else
                pred.next = newNode;
            pred = newNode;

			numNew++;
        }

        if (numNew == 0)
            return false;

        if (succ == null) {
            last = pred;
        } else {
            pred.next = succ;
            succ.prev = pred;
        }

        size += numNew;
        modCount++;
        return true;
    }

    /**
     * Removes the first occurrence of the specified element from this list,
     * if it is present.  If this list does not contain the element, it is
     * unchanged.  More formally, removes the element with the lowest index
     * {@code i} such that
     * <tt>(o==null&nbsp;?&nbsp;get(i)==null&nbsp;:&nbsp;o.equals(get(i)))</tt>
     * (if such an element exists).  Returns {@code true} if this list
     * contained the specified element (or equivalently, if this list
     * changed as a result of the call).
     *
     * @param o element to be removed from this list, if present
     * @return {@code true} if this list contained the specified element
     */
    public def remove(o:E): Boolean {
        if (o == null) {
            for (var x:Node[E] = first; x != null; x = x.next) {
                if (x.item == null) {
                    unlink(x);
                    return true;
                }
            }
        } else {
            for (var x:Node[E] = first; x != null; x = x.next) {
                if (o.equals(x.item())) {
                    unlink(x);
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Removes the element at the specified position in this list.  Shifts any
     * subsequent elements to the left (subtracts one from their indices).
     * Returns the element that was removed from the list.
     *
     * @param index the index of the element to be removed
     * @return the element previously at the specified position
     * @throws IndexOutOfBoundsException {@inheritDoc}
     */
    public def removeAt(index:Long): E {
        checkElementIndex(index);
        return unlink(node(index));
    }

    public operator this(i: Long) = get(i);

    /**
     * Returns the element at the specified position in this list.
     *
     * @param index index of the element to return
     * @return the element at the specified position in this list
     * @throws IndexOutOfBoundsException {@inheritDoc}
     */
    public def get(index:Long): E {
        checkElementIndex(index);
        return node(index).item();
    }

    /**
     * Returns the number of elements in this list.
     *
     * @return the number of elements in this list
     */
    public def size(): Long {
        return size;
    }

    public def isEmpty(): Boolean = size() == 0;

    /**
     * Returns an array containing all of the elements in this list
     * in proper sequence (from first to last element).
     *
     * <p>The returned array will be "safe" in that no references to it are
     * maintained by this list.  (In other words, this method must allocate
     * a new array).  The caller is thus free to modify the returned array.
     *
     * <p>This method acts as bridge between array-based and collection-based
     * APIs.
     *
     * @return an array containing all of the elements in this list
     *         in proper sequence
     */
    public def toRail(): Rail[Box[E]] {
        val result = new Rail[Box[E]](size);
        var i:Long = 0;
        for (var x:Node[E] = first; x != null; x = x.next)
            result(i++) = x.item;
        return result;
    }

    /**
     * Returns the first element in this list.
     *
     * @return the first element in this list
     * @throws NoSuchElementException if this list is empty
     */
    public def getFirst(): E {
        val f:Node[E] = first;
        if (f == null)
            throw new NoSuchElementException();
        return f.item();
    }

    /**
     * Returns the last element in this list.
     *
     * @return the last element in this list
     * @throws NoSuchElementException if this list is empty
     */
    public def getLast(): E {
        val l:Node[E] = last;
        if (l == null)
            throw new NoSuchElementException();
        return l.item();
    }

    /**
     * Removes and returns the first element from this list.
     *
     * @return the first element from this list
     * @throws NoSuchElementException if this list is empty
     */
    public def removeFirst(): E {
        val f:Node[E] = first;
        if (f == null)
            throw new NoSuchElementException();
        return unlinkFirst(f);
    }

    /**
     * Removes and returns the last element from this list.
     *
     * @return the last element from this list
     * @throws NoSuchElementException if this list is empty
     */
    public def removeLast(): E {
        val l:Node[E] = last;
        if (l == null)
            throw new NoSuchElementException();
        return unlinkLast(l);
    }

    public def indices(): List[Long] {
        val l = new ArrayList[Long]();
        for (var i: Long = 0; i < size(); i++) {
            l.add(i);
        }
        return l;
    }

    public def subList(begin:Long, end:Long): List[E] {
        val l = new LinkedList[E]();
    	var n:Node[E] = node(begin);
        for (var i: Long = begin; i < size() && i < end; i++) {
			if (n == null)
            	throw new NoSuchElementException();
           	l.add(n.item());
			n = n.next;
        }
        return l;
    }

    /**
     * Returns the index of the first occurrence of the specified element
     * in this list, or -1 if this list does not contain the element.
     * More formally, returns the lowest index {@code i} such that
     * <tt>(o==null&nbsp;?&nbsp;get(i)==null&nbsp;:&nbsp;o.equals(get(i)))</tt>,
     * or -1 if there is no such index.
     *
     * @param o element to search for
     * @return the index of the first occurrence of the specified element in
     *         this list, or -1 if this list does not contain the element
     */
    public def indexOf(o:E): Long {
		return indexOf(0, o);
	}

    public def indexOf(i0:Long, o:E): Long {
        var index:Long = i0;
        if (o == null) {
            for (var x:Node[E] = first; x != null; x = x.next) {
                if (x.item == null)
                    return index;
                index++;
            }
        } else {
            for (var x:Node[E] = first; x != null; x = x.next) {
                if (o.equals(x.item()))
                    return index;
                index++;
            }
        }
        return -1;
    }

    /**
     * Returns the index of the last occurrence of the specified element
     * in this list, or -1 if this list does not contain the element.
     * More formally, returns the highest index {@code i} such that
     * <tt>(o==null&nbsp;?&nbsp;get(i)==null&nbsp;:&nbsp;o.equals(get(i)))</tt>,
     * or -1 if there is no such index.
     *
     * @param o element to search for
     * @return the index of the last occurrence of the specified element in
     *         this list, or -1 if this list does not contain the element
     */
    public def lastIndexOf(o:E): Long {
		return lastIndexOf(size, o);
	}

    public def lastIndexOf(i0:Long, o:E): Long {
        var index:Long = i0;
        if (o == null) {
            for (var x:Node[E] = last; x != null; x = x.prev) {
                index--;
                if (x.item == null)
                    return index;
            }
        } else {
            for (var x:Node[E] = last; x != null; x = x.prev) {
                index--;
                if (o.equals(x.item()))
                    return index;
            }
        }
        return -1;
    }


	/**
     * Links e as first element.
     */
    private def linkFirst(e:E) {
        val f:Node[E] = first;
        val newNode:Node[E] = new Node[E](null, e, f);
        first = newNode;
        if (f == null)
            last = newNode;
        else
            f.prev = newNode;
        size++;
        modCount++;
    }

    /**
     * Links e as last element.
     */
    def linkLast(e:E) {
        val l:Node[E] = last;
        val newNode:Node[E] = new Node[E](l, e, null);
        last = newNode;
        if (l == null)
            first = newNode;
        else
            l.next = newNode;
        size++;
        modCount++;
    }

    /**
     * Inserts element e before non-null Node succ.
     */
    def linkBefore(e:E, succ:Node[E]) {
        // assert succ != null;
        val pred:Node[E] = succ.prev;
        val newNode:Node[E] = new Node[E](pred, e, succ);
        succ.prev = newNode;
        if (pred == null)
            first = newNode;
        else
            pred.next = newNode;
        size++;
        modCount++;
    }

    /**
     * Unlinks non-null first node f.
     */
    private def unlinkFirst(f:Node[E]): E {
        // assert f == first && f != null;
        val element:E = f.item();
        val next:Node[E] = f.next;
        f.item = null;
        f.next = null; // help GC
        first = next;
        if (next == null)
            last = null;
        else
            next.prev = null;
        size--;
        modCount++;
        return element;
    }

    /**
     * Unlinks non-null last node l.
     */
    private def unlinkLast(l:Node[E]): E {
        // assert l == last && l != null;
        val element:E = l.item();
        val prev:Node[E] = l.prev;
        l.item = null;
        l.prev = null; // help GC
        last = prev;
        if (prev == null)
            first = null;
        else
            prev.next = null;
        size--;
        modCount++;
        return element;
    }

    /**
     * Unlinks non-null node x.
     */
    def unlink(x:Node[E]): E {
        // assert x != null;
        val element:E = x.item();
        val next:Node[E] = x.next;
        val prev:Node[E] = x.prev;

        if (prev == null) {
            first = next;
        } else {
            prev.next = next;
            x.prev = null;
        }

        if (next == null) {
            last = prev;
        } else {
            next.prev = prev;
            x.next = null;
        }

        x.item = null;
        size--;
        modCount++;
        return element;
    }



    // Positional Access Operations

    /**
     * Tells if the argument is the index of an existing element.
     */
    private def isElementIndex(index:Long): Boolean {
        return index >= 0 && index < size;
    }

    /**
     * Tells if the argument is the index of a valid position for an
     * iterator or an add operation.
     */
    private def isPositionIndex(index:Long): Boolean {
        return index >= 0 && index <= size;
    }

    /**
     * Constructs an IndexOutOfBoundsException detail message.
     * Of the many possible refactorings of the error handling code,
     * this "outlining" performs best with both server and client VMs.
     */
    private def outOfBoundsMsg(index:Long): String {
        return "Index: "+index+", Size: "+size;
    }

    private def checkElementIndex(index:Long): void {
        if (!isElementIndex(index))
            throw new IndexOutOfBoundsException(outOfBoundsMsg(index));
    }

    private def checkPositionIndex(index:Long): void {
        if (!isPositionIndex(index))
            throw new IndexOutOfBoundsException(outOfBoundsMsg(index));
    }

    /**
     * Returns the (non-null) Node at the specified element index.
     */
    def node(index:Long): Node[E] {
        // assert isElementIndex(index);

        if (index < (size >> 1)) {
            var x:Node[E] = first;
            for (var i:Long = 0; i < index; i++)
                x = x.next;
            return x;
        } else {
            var x:Node[E] = last;
            for (var i:Long = size - 1; i > index; i--)
                x = x.prev;
            return x;
        }
    }


    // Search Operations

    // Queue operations.

    /**
     * Retrieves, but does not remove, the head (first element) of this list.
     *
     * @return the head of this list, or {@code null} if this list is empty
     * @since 1.5
     */
    public def peek(): Box[E] {
        val f:Node[E] = first;
        return (f == null) ? null : f.item;
    }

    /**
     * Retrieves, but does not remove, the head (first element) of this list.
     *
     * @return the head of this list
     * @throws NoSuchElementException if this list is empty
     * @since 1.5
     */
    public def element(): E {
        return getFirst();
    }

    /**
     * Retrieves and removes the head (first element) of this list.
     *
     * @return the head of this list, or {@code null} if this list is empty
     * @since 1.5
     */
    public def poll(): Box[E] {
        val f:Node[E] = first;
        return (f == null) ? null : new Box[E](unlinkFirst(f));
    }

    /**
     * Retrieves and removes the head (first element) of this list.
     *
     * @return the head of this list
     * @throws NoSuchElementException if this list is empty
     * @since 1.5
     */
    public def remove(): E {
        return removeFirst();
    }

//    /**
//     * Adds the specified element as the tail (last element) of this list.
//     *
//     * @param e the element to add
//     * @return {@code true} (as specified by {@link Queue#offer})
//     * @since 1.5
//     */
//    public def offer(e:E): Boolean {
//        return add(e);
//    }

//    // Deque operations
//    /**
//     * Inserts the specified element at the front of this list.
//     *
//     * @param e the element to insert
//     * @return {@code true} (as specified by {@link Deque#offerFirst})
//     * @since 1.6
//     */
//    public boolean offerFirst(E e) {
//        addFirst(e);
//        return true;
//    }
//
//    /**
//     * Inserts the specified element at the end of this list.
//     *
//     * @param e the element to insert
//     * @return {@code true} (as specified by {@link Deque#offerLast})
//     * @since 1.6
//     */
//    public boolean offerLast(E e) {
//        addLast(e);
//        return true;
//    }
//
//    /**
//     * Retrieves, but does not remove, the first element of this list,
//     * or returns {@code null} if this list is empty.
//     *
//     * @return the first element of this list, or {@code null}
//     *         if this list is empty
//     * @since 1.6
//     */
//    public E peekFirst() {
//        final Node[E] f = first;
//        return (f == null) ? null : f.item;
//     }
//
//    /**
//     * Retrieves, but does not remove, the last element of this list,
//     * or returns {@code null} if this list is empty.
//     *
//     * @return the last element of this list, or {@code null}
//     *         if this list is empty
//     * @since 1.6
//     */
//    public E peekLast() {
//        final Node[E] l = last;
//        return (l == null) ? null : l.item;
//    }
//
//    /**
//     * Retrieves and removes the first element of this list,
//     * or returns {@code null} if this list is empty.
//     *
//     * @return the first element of this list, or {@code null} if
//     *     this list is empty
//     * @since 1.6
//     */
//    public E pollFirst() {
//        final Node[E] f = first;
//        return (f == null) ? null : unlinkFirst(f);
//    }
//
//    /**
//     * Retrieves and removes the last element of this list,
//     * or returns {@code null} if this list is empty.
//     *
//     * @return the last element of this list, or {@code null} if
//     *     this list is empty
//     * @since 1.6
//     */
//    public E pollLast() {
//        final Node[E] l = last;
//        return (l == null) ? null : unlinkLast(l);
//    }
//
//    /**
//     * Pushes an element onto the stack represented by this list.  In other
//     * words, inserts the element at the front of this list.
//     *
//     * <p>This method is equivalent to {@link #addFirst}.
//     *
//     * @param e the element to push
//     * @since 1.6
//     */
//    public void push(E e) {
//        addFirst(e);
//    }
//
//    /**
//     * Pops an element from the stack represented by this list.  In other
//     * words, removes and returns the first element of this list.
//     *
//     * <p>This method is equivalent to {@link #removeFirst()}.
//     *
//     * @return the element at the front of this list (which is the top
//     *         of the stack represented by this list)
//     * @throws NoSuchElementException if this list is empty
//     * @since 1.6
//     */
//    public E pop() {
//        return removeFirst();
//    }
//
//    /**
//     * Removes the first occurrence of the specified element in this
//     * list (when traversing the list from head to tail).  If the list
//     * does not contain the element, it is unchanged.
//     *
//     * @param o element to be removed from this list, if present
//     * @return {@code true} if the list contained the specified element
//     * @since 1.6
//     */
//    public boolean removeFirstOccurrence(Object o) {
//        return remove(o);
//    }
//
//    /**
//     * Removes the last occurrence of the specified element in this
//     * list (when traversing the list from head to tail).  If the list
//     * does not contain the element, it is unchanged.
//     *
//     * @param o element to be removed from this list, if present
//     * @return {@code true} if the list contained the specified element
//     * @since 1.6
//     */
//    public boolean removeLastOccurrence(Object o) {
//        if (o == null) {
//            for (Node[E] x = last; x != null; x = x.prev) {
//                if (x.item == null) {
//                    unlink(x);
//                    return true;
//                }
//            }
//        } else {
//            for (Node[E] x = last; x != null; x = x.prev) {
//                if (o.equals(x.item)) {
//                    unlink(x);
//                    return true;
//                }
//            }
//        }
//        return false;
//    }

    /**
     * Returns a list-iterator of the elements in this list (in proper
     * sequence), starting at the specified position in the list.
     * Obeys the general contract of {@code List.listIterator(int)}.<p>
     *
     * The list-iterator is <i>fail-fast</i>: if the list is structurally
     * modified at any time after the Iterator is created, in any way except
     * through the list-iterator's own {@code remove} or {@code add}
     * methods, the list-iterator will throw a
     * {@code ConcurrentModificationException}.  Thus, in the face of
     * concurrent modification, the iterator fails quickly and cleanly, rather
     * than risking arbitrary, non-deterministic behavior at an undetermined
     * time in the future.
     *
     * @param index index of the first element to be returned from the
     *              list-iterator (by a call to {@code next})
     * @return a ListIterator of the elements in this list (in proper
     *         sequence), starting at the specified position in the list
     * @throws IndexOutOfBoundsException {@inheritDoc}
     * @see List#listIterator(int)
     */
    //public ListIterator[E] listIterator(int index) {
    //    checkPositionIndex(index);
    //    return new ListItr(index);
    //}
    public def iterator(): ListIterator[E] {
        return new ListItr(0);
    }

    public def iteratorFrom(i:Long): ListIterator[E] {
        return new ListItr(i);
    }

    private class ListItr implements ListIterator[E] {
        private var lastReturned:Node[E] = null;
        private var next:Node[E];
        private var nextIndex:Long;
        private var expectedModCount:Long = modCount;

        def this(index:Long) {
            // assert isPositionIndex(index);
            next = (index == size) ? null : node(index);
if (index >= size && next == null) Console.ERR.println("next is null but should not be0");
            nextIndex = index;
        }

        public def hasNext(): Boolean {
            return nextIndex < size;
        }

        public def nextIndex(): Long {
            return nextIndex;
        }

        public def next(): E {
            checkForComodification();
            if (!hasNext())
                throw new NoSuchElementException();

assert(next != null);
//Console.ERR.println("next is null!");

            lastReturned = next;
            next = next.next;
            nextIndex++;
if (hasNext() && next == null) Console.ERR.println("next is null but should not be!");
            return lastReturned.item();
        }

        public def hasPrevious(): Boolean {
            return nextIndex > 0;
        }

        public def previousIndex(): Long {
            return nextIndex - 1;
        }

        public def previous(): E {
            checkForComodification();
            if (!hasPrevious())
                throw new NoSuchElementException();

            lastReturned = next = (next == null) ? last : next.prev;
            nextIndex--;
            return lastReturned.item();
        }

        public def remove(): void {
            checkForComodification();
            if (lastReturned == null)
                throw new IllegalStateException();

            val lastNext:Node[E] = lastReturned.next;
            unlink(lastReturned);
            if (next == lastReturned)
                next = lastNext;
            else
                nextIndex--;
            lastReturned = null;
            expectedModCount++;
        }

        public def set(e:E): void {
            if (lastReturned == null)
                throw new IllegalStateException();
            checkForComodification();
            lastReturned.item = new Box[E](e);
        }

        public def add(e:E): void {
            checkForComodification();
            lastReturned = null;
            if (next == null)
                linkLast(e);
            else
                linkBefore(e, next);
            nextIndex++;
            expectedModCount++;
        }

        def checkForComodification(): void {
            if (modCount != expectedModCount)
                //throw new ConcurrentModificationException();
                throw new IllegalOperationException();
        }
    }

    private static class Node[E] {
        var item:Box[E];
        var next:Node[E];
        var prev:Node[E];

        def this(prev:Node[E], element:E, next:Node[E]) {
            this.item = new Box[E](element);
            this.next = next;
            this.prev = prev;
        }
    }

//    /**
//     * @since 1.6
//     */
//    public Iterator[E] descendingIterator() {
//        return new DescendingIterator();
//    }
//
//    /**
//     * Adapter to provide descending iterators via ListItr.previous
//     */
//    private class DescendingIterator implements Iterator[E] {
//        private final ListItr itr = new ListItr(size());
//        public boolean hasNext() {
//            return itr.hasPrevious();
//        }
//        public E next() {
//            return itr.previous();
//        }
//        public void remove() {
//            itr.remove();
//        }
//    }
//
//    @SuppressWarnings("unchecked")
//    private def superClone(): LinkedList[E] {
//        try {
//            return super.clone() as LinkedList[E];
//        } catch (e:CloneNotSupportedException) {
//            throw new InternalError();
//        }
//    }
//
//    /**
//     * Returns an array containing all of the elements in this list in
//     * proper sequence (from first to last element); the runtime type of
//     * the returned array is that of the specified array.  If the list fits
//     * in the specified array, it is returned therein.  Otherwise, a new
//     * array is allocated with the runtime type of the specified array and
//     * the size of this list.
//     *
//     * <p>If the list fits in the specified array with room to spare (i.e.,
//     * the array has more elements than the list), the element in the array
//     * immediately following the end of the list is set to {@code null}.
//     * (This is useful in determining the length of the list <i>only</i> if
//     * the caller knows that the list does not contain any null elements.)
//     *
//     * <p>Like the {@link #toArray()} method, this method acts as bridge between
//     * array-based and collection-based APIs.  Further, this method allows
//     * precise control over the runtime type of the output array, and may,
//     * under certain circumstances, be used to save allocation costs.
//     *
//     * <p>Suppose {@code x} is a list known to contain only strings.
//     * The following code can be used to dump the list into a newly
//     * allocated array of {@code String}:
//     *
//     * <pre>
//     *     String[] y = x.toArray(new String[0]);</pre>
//     *
//     * Note that {@code toArray(new Object[0])} is identical in function to
//     * {@code toArray()}.
//     *
//     * @param a the array into which the elements of the list are to
//     *          be stored, if it is big enough; otherwise, a new array of the
//     *          same runtime type is allocated for this purpose.
//     * @return an array containing the elements of the list
//     * @throws ArrayStoreException if the runtime type of the specified array
//     *         is not a supertype of the runtime type of every element in
//     *         this list
//     * @throws NullPointerException if the specified array is null
//     */
//    @SuppressWarnings("unchecked")
//    public <T> T[] toArray(T[] a) {
//        if (a.length < size)
//            a = (T[])java.lang.reflect.Array.newInstance(
//                                a.getClass().getComponentType(), size);
//        int i = 0;
//        Object[] result = a;
//        for (Node[E] x = first; x != null; x = x.next)
//            result[i++] = x.item;
//
//        if (a.length > size)
//            a[size] = null;
//
//        return a;
//    }
//
//    private static final long serialVersionUID = 876323262645176354L;
//
//    /**
//     * Saves the state of this {@code LinkedList} instance to a stream
//     * (that is, serializes it).
//     *
//     * @serialData The size of the list (the number of elements it
//     *             contains) is emitted (int), followed by all of its
//     *             elements (each an Object) in the proper order.
//     */
//    private void writeObject(java.io.ObjectOutputStream s)
//        throws java.io.IOException {
//        // Write out any hidden serialization magic
//        s.defaultWriteObject();
//
//        // Write out size
//        s.writeInt(size);
//
//        // Write out all elements in the proper order.
//        for (Node[E] x = first; x != null; x = x.next)
//            s.writeObject(x.item);
//    }
//
//    /**
//     * Reconstitutes this {@code LinkedList} instance from a stream
//     * (that is, deserializes it).
//     */
//    @SuppressWarnings("unchecked")
//    private void readObject(java.io.ObjectInputStream s)
//        throws java.io.IOException, ClassNotFoundException {
//        // Read in any hidden serialization magic
//        s.defaultReadObject();
//
//        // Read in size
//        int size = s.readInt();
//
//        // Read in all elements in the proper order.
//        for (int i = 0; i < size; i++)
//            linkLast((E)s.readObject());
//    }

    public def reverse(): void {
		val temp = first;
		first = last;
		last = temp;
		for (var x:Node[E] = first; x != last; x = x.next) {
			val t = x.next;
			x.next = x.prev;
			x.prev = t;
		}
    }

    // [NN]: should not need to cast x to Comparable[E]
    public def sort() {E <: Comparable[E]} {
		sort((x:E, y:E) => (x as Comparable[E]).compareTo(y)); 
	}
    public def sort(cmp:(E,E)=>Int) {
		val a:Rail[Node[E]] = toNodeArray();
		val cmpN = (xn:Node[E], yn:Node[E]) => cmp(xn.item(), yn.item());
		RailUtils.sort[Node[E]](a, cmpN); 
		reflectArrayOrder(a);
	}

    /**
     * Searches this ArrayList for the key using the binary search
     * algorithm.  This ArrayList must be sorted (e.g. by the sort method).
     * If the key is found, return its index in the list.
     * Otherwise, return (-(insertion point) -1), where insertion point is the
     * index at which the key would be inserted into the sorted list.
     * @param key the value to find
     * @param cmp the comparison function to use
     */
    public def binarySearch(key:E) {E <: Comparable[E]}: Long {
		 return binarySearch(key, (x:E, y:E) => (x as Comparable[E]).compareTo(y)); 
	}
    public def binarySearch(key:E, cmp:(E,E)=>Int) {E <: Comparable[E]}: Long {
		val a:Rail[Node[E]] = toNodeArray();		
		val keyN:Node[E] = node(indexOf(key));
		val cmpN = (xn:Node[E], yn:Node[E]) => cmp(xn.item(), yn.item());
        val res = RailUtils.binarySearch[Node[E]](a, keyN, cmpN);
		reflectArrayOrder(a);
		return res;
    }

	private def toNodeArray(): Rail[Node[E]] {
        val a = new Rail[Node[E]](size);
        var i:Long = 0;
        for (var x:Node[E] = first; x != null; x = x.next)
            a(i++) = x;
		return a;
	}
	private def reflectArrayOrder(a:Rail[Node[E]]) {
		if (size == 0) return;
		first = a(0);
		last = a(a.size-1);
		for (i in 0..(a.size-1)) {
			a(i).next = i <= (a.size-2) ? a(i+1) : null;
			a(i).prev = i >= 1 ? a(i-1) : null;
		}
	}
}
