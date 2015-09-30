#!/bin/bash

if [ -s $OPENAIR_DIR/cmake_targets/tools/build_helper ] ; then
   source $OPENAIR_DIR/cmake_targets/tools/build_helper
else
   echo "Error: no file in the file tree: is OPENAIR_DIR variable set?"
   exit 1
fi

results_file=$tdir/log/compilation_autotests.xml

# include the jUnit-like logging functions
source $OPENAIR_DIR/cmake_targets/tools/test_helper

test_compile() {
    xUnit_start
    test_name=$1
    compile_prog=$2
    exec_prog=$3
    build_dir=$tdir/$1/build
    log_file=$tdir/log/$1.txt
    target=$5
    echo "Compiling test case $test_name. Log file = $log_file"
    rm -fr $build_dir
    mkdir -p $tdir/$1/build
    cd $build_dir
    {
        cmake ..
        rm -f $exec_prog
        make -j`nproc` $compile_prog
    } > $log_file 2>&1
    if [ -s $exec_prog ] ; then
        cp $exec_prog $tdir/bin/`basename $exec_prog`.$target.$test_name
        echo_success "$test_name $exec_prog $target compiled"
        xUnit_success "compilation" $test_name "PASS" 1
    else
        echo_error "$test_name $exec_prog $target compilation failed"
        xUnit_fail "compilation" $test_name "FAIL" 1
    fi
}

tdir=$OPENAIR_DIR/cmake_targets/autotests
mkdir -p $tdir/bin $tdir/log

updated=$(svn st -q $OPENAIR_DIR)
if [ "$updated" != "" ] ; then
	echo_warning "some files are not in svn:\n $updated"
fi

cd $tdir 

test_compile \
    test.0101 oaisim_nos1 \
    oaisim_nos1  $tdir/bin/oaisim.r8 rel8.nos1

test_compile \
    test.0102 oaisim_nos1 \
    oaisim_nos1  $tdir/bin/oaisim.r8.nas rel8.nos1.nas

cp $tdir/test.0103/CMakeLists.txt.Rel8  $tdir/test.0103/CMakeLists.txt 
test_compile \
    test.0103 lte-softmodem \
    lte-softmodem  $tdir/bin/lte-softmodem.r8.rf Rel8.EXMIMO

cp $tdir/test.0103/CMakeLists.txt.Rel10  $tdir/test.0103/CMakeLists.txt   
test_compile \
    test.0103 lte-softmodem \
    lte-softmodem  $tdir/bin/lte-softmodem.r10.rf Rel10.EXMIMO

cp $tdir/test.0103/CMakeLists.txt.USRP  $tdir/test.0103/CMakeLists.txt   
test_compile \
    test.0103 lte-softmodem \
    lte-softmodem  $tdir/bin/lte-softmodem.r10.rf Rel10.USRP

test_compile \
    test.0104 dlsim \
    dlsim  $tdir/bin/dlsim dlsim.Rel8

test_compile \
    test.0104 ulsim \
    ulsim  $tdir/bin/ulsim ulsim.Rel8

test_compile \
    test.0106 oaisim \
    oaisim  $tdir/bin/oaisim.r8.itti Rel8.itti

test_compile \
    test.0107 oaisim_nos1 \
    oaisim_nos1  $tdir/bin/oaisim.r10 Rel10.nos1

test_compile \
    test.0108 oaisim \
    oaisim  $tdir/bin/oaisim.r10.itti rel10.itti

#test_compile \  LG: RAL REMOVED
#    test.0114 oaisim \
#    oaisim  $tdir/bin/oaisim.r8.itti.ral rel8.itti.ral

#test_compile \  LG: RAL REMOVED
#    test.0115 oaisim \
#    oaisim  $tdir/bin/oaisim.r10.itti.ral rel10.itti.ral 

test_compile \
    test.0120 nasmesh \
    CMakeFiles/nasmesh/nasmesh.ko $tdir/bin/nasmesh.ko 

test_compile \
    test.0130 rrh_gw \
    rrh_gw $tdir/bin/rrh_gw

# write the test results into a file
xUnit_write "$results_file"

echo "Test Results are written to $results_file"
