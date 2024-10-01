#!/bin/bash
mkdir dpdk
cd dpdk
sudo apt --assume-yes install build-essential
sudo apt --assume-yes install libnuma-dev
sudo apt --assume-yes install pkg-config
sudo apt --assume-yes install python3 python3-pip python3-setuptools
sudo apt --assume-yes install python3-wheel python3-pyelftools
sudo apt --assume-yes install ninja-build
sudo pip3 install meson
sudo apt install --assume-yes libpcap-dev
sudo apt install --assume-yes linux-headers-4.15.0-169-generic


XLNX_QDMA_REPO_PATH_20_11=https://github.com/Xilinx/dma_ip_drivers.git
XLNX_QDMA_REPO_CHKPT_20_11=7859957

if [ $1 = "20_11" ]; then
	DPDK_VERSION=20.11
	PKTGEN_VERSION=21.03.1
	DPDK_FOLDER=dpdk-$DPDK_VERSION
else
	DPDK_VERSION=22.11.2
	PKTGEN_VERSION=23.03.0
	DPDK_FOLDER=dpdk-stable-$DPDK_VERSION
fi
DPDK_HTTP_PATH=https://fast.dpdk.org/rel/dpdk-$DPDK_VERSION.tar.xz
PKTGEN_HTTP_PATH=https://git.dpdk.org/apps/pktgen-dpdk/snapshot/pktgen-dpdk-pktgen-$PKTGEN_VERSION.tar.xz


if [ $1 = "20_11" ]; then
	git clone https://github.com/Xilinx/dma_ip_drivers.git
	cd dma_ip_drivers
	git checkout 7859957
	cd ..
	git clone https://github.com/Xilinx/open-nic-dpdk.git
	cp open-nic-dpdk/*.patch dma_ip_drivers
	cd dma_ip_drivers
	git apply *.patch
	cd ..
else
	git clone https://github.com/OCT-FPGA/DPDK-opennic.git dma_ip_drivers
	cd dma_ip_drivers
	git checkout dpdk-22.11.2-qdma-2023.1.2
	cd ..
fi

wget $DPDK_HTTP_PATH
tar xvf dpdk-$DPDK_VERSION.tar.xz 
cd $DPDK_FOLDER
cp -R ../dma_ip_drivers/QDMA/DPDK/drivers/net/qdma ./drivers/net
cp -R ../dma_ip_drivers/QDMA/DPDK/examples/qdma_testapp ./examples
# add qdma to the drivers/net/meson.build
sed -i "47i 'qdma'," drivers/net/meson.build
cd ..
cd $DPDK_FOLDER
meson build
cd build
ninja
sudo ninja install
ls -l /usr/local/lib/x86_64-linux-gnu/librte_net_qdma.so
sudo ldconfig
ls -l ./app/test/dpdk-test
cd ../..

wget https://git.dpdk.org/apps/pktgen-dpdk/snapshot/pktgen-dpdk-pktgen-$PKTGEN_VERSION.tar.xz
tar xvf pktgen-dpdk-pktgen-$PKTGEN_VERSION.tar.xz
cd pktgen-dpdk-pktgen-$PKTGEN_VERSION
make RTE_SDK=../dpdk-$DPDK_VERSION RTE_TARGET=build
cd ../$DPDK_FOLDER/usertools

if [ $1 = "20_11" ]; then
	sed -i '62s/\[network_class, cavium_pkx, avp_vnic, ifpga_class\]/\[network_class, cavium_pkx, avp_vnic, ifpga_class, qdma\]/' dpdk-devbind.py
	sed -i "38i qdma = {'Class': '02', 'Vendor': '10ee', 'Device': '903f,913f'," dpdk-devbind.py
	sed -i "39i                'SVendor': None, 'SDevice': None}" dpdk-devbind.py
else
	sed -i '78s/\[network_class, cavium_pkx, avp_vnic, ifpga_class\]/\[network_class, cavium_pkx, avp_vnic, ifpga_class, qdma\]/' dpdk-devbind.py
	sed -i "39i qdma = {'Class': '02', 'Vendor': '10ee', 'Device': '903f,913f'," dpdk-devbind.py
	sed -i "40i                'SVendor': None, 'SDevice': None}" dpdk-devbind.py
fi
cp dpdk-devbind.py /usr/local/bin/.
