#!/bin/bash

set +x

np=8
pid=4
pname=sp24
prec=0.01
interval=0.01
lint=1.

w=2

for i in `seq 0 2`
do
	sync;
	mpirun -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/usr4/ishii-d-aa/local/lib -hostfile nodefile.txt -np $np -x X10_NTHREADS=6 -x GC_NPROCS=2 ./GlbMain -p $pid -e $prec -v 15 -i $interval -li $lint -w $w > exp1/${pname}-${prec}-${np}-${interval}-${lint}-${w}_$i.log;
	sleep 1;
done

w=4

for i in `seq 0 2`
do
	sync;
	mpirun -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/usr4/ishii-d-aa/local/lib -hostfile nodefile.txt -np $np -x X10_NTHREADS=6 -x GC_NPROCS=2 ./GlbMain -p $pid -e $prec -v 15 -i $interval -li $lint -w $w > exp1/${pname}-${prec}-${np}-${interval}-${lint}-${w}_$i.log;
	sleep 1;
done

w=6

for i in `seq 0 2`
do
	sync;
	mpirun -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/usr4/ishii-d-aa/local/lib -hostfile nodefile.txt -np $np -x X10_NTHREADS=6 -x GC_NPROCS=2 ./GlbMain -p $pid -e $prec -v 15 -i $interval -li $lint -w $w > exp1/${pname}-${prec}-${np}-${interval}-${lint}-${w}_$i.log;
	sleep 1;
done
