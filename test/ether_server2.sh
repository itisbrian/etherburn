#!/bin/bash
#############################################################
#   _______     _______ _               ____
#  / ____\ \   / / ____| |        /\   |  _ \
# | (___  \ \_/ / (___ | |       /  \  | |_) |
#  \___ \  \   / \___ \| |      / /\ \ |  _ <
#  ____) |  | |  ____) | |____ / ____ \| |_) |
# |_____/   |_| |_____/|______/_/    \_\____/

#EtherBurn Tester
#by:
#Patrick Geary : patrickg@supermicro.com
#Brian Chen : brianchen@supermicro.com

#version 1.0

#####################################################################


# SERVER SCRIPT -------------------------------------------

nic=${1}
main=${2} #If this is set; it'll nullify the netnscmd
netnscmd="ip netns exec test_${nic}"
	if [ "${nic}" == `cat /var/lib/etherburn/cburn_interface` ]; then
			netnscmd=""
		fi

echo "${netnscmd} | ${nic}" | tee -a "iperf_server_out_${nic}"

for speedtype in `ls /var/lib/etherburn/type` ; do
if [ -e /var/lib/etherburn/type/${speedtype}/${nic} ]; then

NUMANODE=`$netnscmd cat /sys/class/net/${nic}/device/numa_node`
$netnscmd ip addr show dev ${nic} |grep 172.16 | awk '{ print $2 }' | cut -d'/' -f1 | tee -a /var/lib/etherburn/type/${speedtype}/ipaddrs/${nic} iperf_server_out_${nic}
$netnscmd numactl --physcpubind=${NUMANODE} --membind=${NUMANODE} iperf -s | tee -a /var/lib/etherburn/logs/${nic}_server.log iperf_server_out_${nic}

else
	:
fi
done

