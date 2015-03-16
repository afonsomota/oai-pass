################################################################################
#   OpenAirInterface
#   Copyright(c) 1999 - 2014 Eurecom
#
#    OpenAirInterface is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#
#    OpenAirInterface is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with OpenAirInterface.The full GNU General Public License is
#    included in this distribution in the file called "COPYING". If not,
#    see <http://www.gnu.org/licenses/>.
#
#  Contact Information
#  OpenAirInterface Admin: openair_admin@eurecom.fr
#  OpenAirInterface Tech : openair_tech@eurecom.fr
#  OpenAirInterface Dev  : openair4g-devel@eurecom.fr
#
#  Address      : Eurecom, Campus SophiaTech, 450 Route des Chappes, CS 50193 - 06904 Biot Sophia Antipolis cedex, FRANCE
#
################################################################################
# file build_cmake.bash
# brief
# author Laurent Thomas
#
#######################################
SUDO=sudo

###############################
## echo and  family
###############################
black='\E[30m'
red='\E[31m'
green='\E[32m'
yellow='\E[33m'
blue='\E[34m'
magenta='\E[35m'
cyan='\E[36m'
white='\E[37m'
reset_color='\E[00m'
COLORIZE=1

cecho()  {  
    # Color-echo
    # arg1 = message
    # arg2 = color
    local default_msg="No Message."
    message=${1:-$default_msg}
    color=${2:-$green}
    [ "$COLORIZE" = "1" ] && message="$color$message$reset_color"
    echo -e "$message"
    return
}

echo_error()   { cecho "$*" $red          ;}
echo_fatal()   { cecho "$*" $red; exit -1 ;}
echo_warning() { cecho "$*" $yellow       ;}
echo_success() { cecho "$*" $green        ;}
echo_info()    { cecho "$*" $blue         ;}

print_help() {
echo_info '
This program installs OpenAirInterface Software
You should have ubuntu 14.xx, updated, and the Linux kernel >= 3.14
Options
-h
   This help
-c | --clean
   Erase all files made by previous compilation, installation" 
--clean-kernel
   Erase previously installed features in kernel: iptables, drivers, ...
-C | --config-file
   The configuration file to install
-I | --install-external-packages 
   Installs required packages such as LibXML, asn1.1 compiler, freediameter, ...
-g | --run-with-gdb
   Add debugging symbols to compilation directives
-eNB
   Makes the eNB LTE softmodem
-UE
   Makes the UE softmodem
-oaisim
   Makes the oaisim simulator
-unit_simulators
   Makes the unitary tests Layer 1 simulators
-EPC
   Makes the EPC
-r | --3gpp-release
   default is Rel10, 
   Rel8 limits the implementation to 3GPP Release 8 version
-w | --hardware
   EXMIMO (Default), USRP, None
   Adds this RF board support (in external packages installation and in compilation)
-s | --check
   runs a set of auto-tests based on simulators and several compilation tests
-V | --vcd
   Adds a debgging facility to the binary files: GUI with major internal synchronization events
-x | --xforms
   Adds a software oscilloscope feature to the produced binaries
Typical Options for a quick startup with a COTS UE and Eurecom RF board: build_oai.bash -I -g -eNB -EPC -x'
}

###########################
# Cleaners
###########################

clean_kernel() {
    $SUDO modprobe ip_tables
    $SUDO modprobe x_tables
    $SUDO iptables -P INPUT ACCEPT
    $SUDO iptables -F INPUT
    $SUDO iptables -P OUTPUT ACCEPT
    $SUDO iptables -F OUTPUT
    $SUDO iptables -P FORWARD ACCEPT
    $SUDO iptables -F FORWARD
    $SUDO iptables -t nat -F
    $SUDO iptables -t mangle -F
    $SUDO iptables -t filter -F
    $SUDO iptables -t raw -F
    echo_info "Flushed iptables"
    $SUDO rmmod nasmesh > /dev/null 2>&1
    $SUDO rmmod oai_nw_drv  > /dev/null 2>&1
    $SUDO rmmod openair_rf > /dev/null 2>&1
    $SUDO rmmod ue_ip > /dev/null 2>&1
    echo_info "removed drivers from kernel"
}

clean_all_files() {
 dir=$OPENAIR_DIR/cmake
 rm -rf $dir/log $dir/bin $dir/autotests/bin $dir/autotests/log $dir/autotests/*/buid $dir/build_*/build
}

###################################
# Compilers
###################################

compilations() {
  cd $OPENAIR_DIR/cmake_targets/$1
  {
    [ "$CLEAN" = "1" ] && rm -rf build
    mkdir -p build
    cd build
    rm -f $3
    cmake ..
    make -j4 $2
  } > $5 2>&1
  if [ -s $3 ] ; then
     cp $3 $4
     echo_success "$6"
  else
     echo_error "$7"
  fi
}

run_tests() {
   $1 > $2 2>&1
   grep 
}

run_compilation_autotests() {
    tdir=$OPENAIR_DIR/cmake_targets/autotests
    mkdir -p $tdir/bin $tdir/log
    updated=$(svn st -q $OPENAIR_DIR)
    if [ "$updated" != "" ] ; then
	echo_warning "some files are not in svn: $updated"
    fi
    compilations \
        test.0101 oaisim \
        oaisim  $tdir/bin/oaisim.r8 \
        $tdir/log/test0101.txt \
	"test 0101:oaisim Rel8 passed" \
        "test 0101:oaisim Rel8 failed"

    compilations \
        test.0102 oaisim \
        oaisim  $tdir/bin/oaisim.r8.nas \
        $tdir/log/test0102.oaisim.txt \
	"test 0102:oaisim Rel8 nas passed" \
        "test 0102:oaisim Rel8 nas failed"
    compilations \
        test.0103 oaisim \
        oaisim  $tdir/bin/oaisim.r8.rf \
        $tdir/log/test0103.txt \
	"test 0103:oaisim rel8 rf passed" \
        "test 0103:oaisim rel8 rf failed"
    compilations \
        test.0104 dlsim \
        dlsim  $tdir/bin/dlsim \
        $tdir/log/test0104.txt \
	"test 0104:dlsim passed" \
        "test 0104:dlsim failed"    
    compilations \
        test.0104 ulsim \
        ulsim  $tdir/bin/ulsim \
        $tdir/log/test0105.txt \
	"test 0105: ulsim passed" \
        "test 0105: ulsim failed"
    compilations \
        test.0106 oaisim \
        oaisim  $tdir/bin/oaisim.r8.itti \
        $tdir/log/test0106.txt \
	"test 0103:oaisim rel8 itti passed" \
        "test 0103:oaisim rel8 itti failed"
    compilations \
        test.0107 oaisim \
        oaisim  $tdir/bin/oaisim.r10 \
        $tdir/log/test0107.txt \
	"test 0103:oaisim rel10 passed" \
        "test 0103:oaisim rel10 failed"
    compilations \
        test.0108 oaisim \
        oaisim  $tdir/bin/oaisim.r10.itti \
        $tdir/log/test0108.txt \
	"test 0108:oaisim rel10 itti passed" \
        "test 0108:oaisim rel10 itti failed"
    compilations \
        test.0114 oaisim \
        oaisim  $tdir/bin/oaisim.r8.itti.ral \
        $tdir/log/test0114.txt \
	"test 0114:oaisim rel8 itti ral passed" \
        "test 0114:oaisim rel8 itti ral failed"
    compilations \
        test.0115 oaisim \
        oaisim  $tdir/bin/oaisim.r10.itti.ral \
        $tdir/log/test0115.txt \
	"test 0114:oaisim rel10 itti ral passed" \
        "test 0114:oaisim rel10 itti ral failed" 
    compilations \
        test.0102 nasmesh \
        CMakeFiles/nasmesh/nasmesh.ko $tdir/bin/nasmesh.ko \
        $tdir/log/test0120.txt \
	"test 0120: nasmesh.ko passed" \
        "test 0120: nasmesk.ko failed"
}

##########################################
# X.509 certificates
##########################################

make_one_cert() {
    openssl genrsa -out $1.key.pem 1024
    openssl req -new -batch -out $1.csr.pem -key $1.key.pem -subj /CN=$1.eur/C=FR/ST=PACA/L=Aix/O=Eurecom/OU=CM
    openssl ca -cert cacert.pem -keyfile cakey.pem -in $1.csr.pem -out $1.cert.pem -outdir . -batch
}

make_certs(){

    # certificates are stored in diameter config directory
    if [ ! -d /usr/local/etc/freeDiameter ];  then
        echo "Creating non existing directory: /usr/local/etc/freeDiameter/"
        $SUDO mkdir -p /usr/local/etc/freeDiameter/ || echo_error "can't create: /usr/local/etc/freeDiameter/"
    fi

    cd /usr/local/etc/freeDiameter
    echo "creating the CA certificate"
    echo_warning "erase all existing certificates as long as the CA is regenerated"
    $SUDO rm -f /usr/local/etc/freeDiameter/

    # CA self certificate
    $SUDO openssl req  -new -batch -x509 -days 3650 -nodes -newkey rsa:1024 -out cacert.pem -keyout cakey.pem -subj /CN=eur/C=FR/ST=PACA/L=Aix/O=Eurecom/OU=CM
    
    # generate hss certificate and sign it
    $SUDO make_one_cert hss
    $SUDO make_one_cert mme

    # legacy config is using a certificate named 'user'
    $SUDO make_one_cert user

}

############################################
# External packages installers
############################################

install_nettle_from_source() {
    cd /tmp
    echo "Downloading nettle archive"
    wget ftp://ftp.lysator.liu.se/pub/security/lsh/nettle-2.5.tar.gz 
    tar -xzf nettle-2.5.tar.gz
    cd nettle-2.5/
    ./configure --disable-openssl --enable-shared --prefix=/usr 
    echo "Compiling nettle"
    make -j4
    make check 
    $SUDO make install 
    rm -rf /tmp/nettle-2.5.tar.gz /tmp/nettle-2.5
}

install_gnutls_from_source(){
    cd /tmp 
    echo "Downloading gnutls archive"
    wget ftp://ftp.gnutls.org/gcrypt/gnutls/v3.1/gnutls-3.1.23.tar.xz 
    tar -xzf gnutls-3.1.23.tar.xz
    cd gnutls-3.1.23/
    ./configure --prefix=/usr
    echo "Compiling gnutls"
    make -j4
    $SUDO make install 
    rm -rf /tmp/gnutls-3.1.23.tar.xz /tmp/gnutls-3.1.23
}

install_freediameter_from_source() {
    cd /tmp
    echo "Downloading freeDiameter archive"
    wget http://www.freediameter.net/hg/freeDiameter/archive/1.1.5.tar.gz 
    tar xf 1.1.5.tar.gz
    cd freeDiameter-1.1.5
    patch -p1 < $OPENAIRCN_DIR/S6A/freediameter/freediameter-1.1.5.patch 
    mkdir build
    cd build
    cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr ../ 
    echo "Compiling freeDiameter"
    make -j4
    make test 
    $SUDO make install 
    rm -rf /tmp/1.1.5.tar.gz /tmp/freeDiameter-1.1.5
}

check_install_usrp_uhd_driver(){
    if [ ! -f /etc/apt/sources.list.d/ettus.list ] ; then 
        $SUDO bash -c 'echo "deb http://files.ettus.com/binaries/uhd/repo/uhd/ubuntu/`lsb_release -cs` `lsb_release -cs` main" >> /etc/apt/sources.list.d/ettus.list'
        $SUDO apt-get update
     fi
        $SUDO apt-get -y install  python libboost-all-dev libusb-1.0-0-dev
        $SUDO apt-get -y install -t `lsb_release -cs` uhd
}

check_install_oai_software() {
    
    $SUDO apt-get update
    $SUDO apt-get install -y 
        autoconf  \
	automake  \
	bison  \
	build-essential \
	check \
	cmake \
	cmake-curses-gui  \
	dialog \
	dkms \
	doxygen \
	ethtool \
	flex  \
	g++ \
	gawk \
	gcc \
	gccxml \
	gdb  \
	graphviz \
	gtkwave \
	guile-2.0-dev  \
	iperf \
	iproute \
	iptables \
	iptables-dev \
	libatlas-base-dev \
	libatlas-dev \
	libblas \
	libblas3gf \
	libblas-dev \
	libboost-all-dev \
	libconfig8-dev \
	libforms-bin \
	libforms-dev \
	libgcrypt11-dev \
	libgmp-dev \
	libgtk-3-dev \
	libidn11-dev  \
	libidn2-0-dev  \
	libmysqlclient-dev  \
	libpgm-5.1 \
	libpgm-dev \
	libpthread-stubs0-dev \
	libsctp1  \
	libsctp-dev  \
	libssl-dev  \
	libtasn1-3-dev  \
	libtool  \
	libusb-1.0-0-dev \
	libxml2 \
	libxml2-dev  \
	linux-headers-`uname -r` \
	make \
	mysql-client  \
	mysql-server \
	openssh-client \
	openssh-server \
	openssl \
	openvpn \
	phpmyadmin \
	pkg-config \
	python  \
	python-dev  \
	python-pexpect \
	sshfs \
	subversion \
	swig  \
	tshark \
	uml-utilities \
	unzip  \
	valgrind  \
	vlan
    if [ `lsb_release -rs` = '12.04' ] ; then
        install_nettle_from_source
	install_gnutls_from_source
    else
        $SUDO apt-get install -y libgnutls-dev nettle-dev nettle-bin 
    fi
    install_freediameter_from_source
    check_install_asn1c
}

check_install_asn1c(){    
    $SUDO $OPENAIR_TARGETS/SCRIPTS/install_asn1c_0.9.24.modified.bash
}

#################################################
# 2. compile 
################################################
compile_hss() {
    cd $OPENAIRCN_DIR/OPENAIRHSS
    
    if [ "$CLEAN" = "1" ]; then
        echo_info "build a clean HSS"
        rm -rfv obj* m4 .autom4* configure
    fi

    echo_success "Invoking autogen"
    ./autogen.sh || return 1
    mkdir -p objs ; cd objs
    echo_success "Invoking configure"
    ./configure || return 1
    if [ -f Makefile ];  then
        echo_success "Compiling..."
        make -j4
        if [ $? -ne 0 ]; then
            echo_error "Build failed, exiting"
            return 1
        else 
            return 0
        fi
    else
        echo_error "Configure failed, aborting"
    fi
    return 1
}

compile_nas_tools() {

    export NVRAM_DIR=$OPENAIR_TARGETS/bin
    
    cd $NVRAM_DIR
    
    if [ ! -f /tmp/nas_cleaned ]; then
        echo_success "make --directory=$OPENAIRCN_DIR/NAS/EURECOM-NAS/tools veryveryclean"
        make --directory=$OPENAIRCN_DIR/NAS/EURECOM-NAS/tools veryveryclean
    fi
    echo_success "make --directory=$OPENAIRCN_DIR/NAS/EURECOM-NAS/tools all"
    make --directory=$OPENAIRCN_DIR/NAS/EURECOM-NAS/tools all
    rm .ue.nvram
    rm .usim.nvram
    touch /tmp/nas_cleaned
}

TDB() {
    
    if [ $2 = "USRP" ]; then
	echo_info "  8.2 [USRP] "
    fi
    
    # ENB_S1
    if [ $3 = 0 ]; then 
        cd $OPENAIR2_DIR && make clean && make nasmesh_netlink.ko  #|| exit 1
        cd $OPENAIR2_DIR/NAS/DRIVER/MESH/RB_TOOL && make clean && make  # || exit 1
    fi
    
}

# arg1 is ENB_S1 'boolean'
install_oaisim() {
    if [ $1 = 0 ]; then 
	cd $OPENAIR2_DIR && make clean && make nasmesh_netlink.ko  #|| exit 1
	cd $OPENAIR2_DIR/NAS/DRIVER/MESH/RB_TOOL && make clean && make  # || exit 1
    else
	compile_ue_ip_nw_driver
	install_nas_tools
    fi 
}


install_nas_tools() {
    cd $OPENAIR_TARGETS/bin
    if [ ! -f .ue.nvram ]; then
        echo_success "generate .ue_emm.nvram .ue.nvram"
        $OPENAIRCN_DIR/NAS/EURECOM-NAS/bin/ue_data --gen
    fi

    if [ ! -f .usim.nvram ]; then
        echo_success "generate .usim.nvram"
        $OPENAIRCN_DIR/NAS/EURECOM-NAS/bin/usim_data --gen
    fi
    $OPENAIRCN_DIR/NAS/EURECOM-NAS/bin/ue_data --print
    $OPENAIRCN_DIR/NAS/EURECOM-NAS/bin/usim_data --print
}

install_nasmesh(){
    echo_success "LOAD NASMESH IP DRIVER FOR UE AND eNB" 
    (cd $OPENAIR2_DIR/NAS/DRIVER/MESH/RB_TOOL && make clean && make)
    (cd $OPENAIR2_DIR && make clean && make nasmesh_netlink_address_fix.ko)
    $SUDO rmmod nasmesh
    $SUDO insmod $OPENAIR2_DIR/NAS/DRIVER/MESH/nasmesh.ko
}

##################################
# create HSS DB
################################

# arg 1 is mysql user      (root)
# arg 2 is mysql password  (linux)
# arg 3 is hss username    (hssadmin)
# arg 4 is hss password    (admin)
# arg 5 is database name   (oai_db)
create_hss_database(){
    EXPECTED_ARGS=5
    E_BADARGS=65
    MYSQL=`which mysql`
    rv=0
    if [ $# -ne $EXPECTED_ARGS ]
    then
        echo_fatal "Usage: $0 dbuser dbpass hssuser hsspass databasename"
        rv=1
    fi

    set_openair_env
    
    # removed %
    #Q1="GRANT ALL PRIVILEGES ON *.* TO '$3'@'%' IDENTIFIED BY '$4' WITH GRANT OPTION;"
    Q1="GRANT ALL PRIVILEGES ON *.* TO '$3'@'localhost' IDENTIFIED BY '$4' WITH GRANT OPTION;"
    Q2="FLUSH PRIVILEGES;"
    SQL="${Q1}${Q2}"
    $MYSQL -u $1 --password=$2 -e "$SQL"
    if [ $? -ne 0 ]; then
	echo_error "$3 permissions failed"
	return 1
    else
	echo_success "$3 permissions succeeded"
    fi
    
    
    Q1="CREATE DATABASE IF NOT EXISTS ${BTICK}$5${BTICK};"
    SQL="${Q1}"
    $MYSQL -u $3 --password=$4 -e "$SQL"
    if [ $? -ne 0 ]; then
	echo_error "$5 creation failed"
	return 1
    else
	echo_success "$5 creation succeeded"
    fi
    
    
    # test if tables have been created
    mysql -u $3 --password=$4  -e "desc $5.users" > /dev/null 2>&1
    
    if [ $? -eq 1 ]; then 
        $MYSQL -u $3 --password=$4 $5 < $OPENAIRCN_DIR/OPENAIRHSS/db/oai_db.sql
        if [ $? -ne 0 ]; then
            echo_error "$5 tables creation failed"
            return 1
        else
            echo_success "$5 tables creation succeeded"
        fi
    fi
    
    return 0
}

################################
# set_openair_env
###############################
set_openair_env(){

    fullpath=`readlink -f $BASH_SOURCE`
    [ -f "/.$fullpath" ] || fullpath=`readlink -f $PWD/$fullpath`
    openair_path=${fullpath%/cmake_targets/*}
    openair_path=${openair_path%/targets/*}
    openair_path=${openair_path%/openair-cn/*}
    openair_path=${openair_path%/openair[123]/*}

    export OPENAIR_DIR=$openair_path
    export OPENAIR_HOME=$openair_path
    export OPENAIR1_DIR=$openair_path/openair1
    export OPENAIR2_DIR=$openair_path/openair2
    export OPENAIR3_DIR=$openair_path/openair3
    export OPENAIRCN_DIR=$openair_path/openair-cn
    export OPENAIR_TARGETS=$openair_path/targets

}

