#!/bin/bash

# prepare build
export NGLDIR=$HOME/ngl-build
mkdir -p $NGLDIR/env
alias make="make -j8"

# retrieve source code from git
git clone https://github.com/stupeflix/sxplayer $NGLDIR/sxplayer
git clone https://github.com/gopro/gopro-lib-node.gl $NGLDIR/node.gl

# build sxplayer
echo "start make sxplayer"
cd $NGLDIR/sxplayer
make install PREFIX=$NGLDIR/env

# build libnodegl
echo "start make libnodegl"
cd $NGLDIR/node.gl/libnodegl
PKG_CONFIG_PATH=$NGLDIR/env/lib/pkgconfig make install PREFIX=$NGLDIR/env

# build ngl-tools
echo "start make ngl-tools"
cd $NGLDIR/node.gl/ngl-tools
PKG_CONFIG_PATH=$NGLDIR/env/lib/pkgconfig make install PREFIX=$NGLDIR/env

# test libnodegl
echo "start test nodegl"
mkdir /home/root/build-script/tests-results # create directory in docker volume 'build-script' to store tests results
cd $NGLDIR/node.gl/libnodegl
make testprogs
echo "test hmap"
./test_hmap >> /home/root/build-script/tests-results/test_hmap_res.txt
echo "test asm"
./test_asm >> /home/root/build-script/tests-results/test_asm_res.txt
echo "test utils"
./test_utils >> /home/root/build-script/tests-results/test_utils_res.txt
chmod -R 777 /home/root/build-script

# clean libnodegl for coverity run
echo "clean libnodegl"
cd $NGLDIR/node.gl/libnodegl
make clean

# start coverity data collection run
echo "start coverity wrapped make for libnodegl"
export PATH=$PATH:/home/root/coverity/cov-analysis-linux64-2017.07/bin
cd $NGLDIR/node.gl
PKG_CONFIG_PATH=$NGLDIR/env/lib/pkgconfig cov-build --dir cov-int make -C libnodegl PREFIX=$NGLDIR/env
# copy coverity results into docker volume 'coverity'
cp -R /root/ngl-build/node.gl/cov-int /home/root/coverity/cov-int
chmod -R 777 /home/root/coverity/cov-int


