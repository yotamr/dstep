#!/bin/sh

if [ -s "$HOME/.dvm/scripts/dvm" ] ; then
    . "$HOME/.dvm/scripts/dvm" ;
    dvm use 2.063.2
fi

rdmd --build-only -debug -gc -ofbin/dstep \
	-Idstack/mambo -Idstack \
	-L-L. \
	-L-L/usr/lib/llvm-3.2/lib \
	-L-lclang \
	-L-ltango \
	-L-rpath -L. \
	-L-rpath -L/usr/lib/llvm-3.2/lib \
	"$@" dstep/driver/DStep.d
