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

#CLIENT SCRIPT -------------------------------------------

    nic=${1}
	main=${2} #If this is set; it'll nullify the netnscmd
	sleep 1
	netnscmd="ip netns exec test_${nic}"
	if [ "${nic}" == `cat /var/lib/etherburn/cburn_interface` ]; then
			

			netnscmd=""
			echo "eth0 netcmd = blank" 
		fi
	#You may need to bring the device up first
	

for speedtype in `ls /var/lib/etherburn/type` ; do

	if [ -e /var/lib/etherburn/type/${speedtype}/${nic} ]; then



	NUMANODE=`$netnscmd cat /sys/class/net/${nic}/device/numa_node`
    
	#Pull off the first ip entry that doesn't match $nic
	#TARGET=`ls /var/lib/etherburn/ipaddrs | grep -v ${nic} | head -n 1 | awk -F"/" '{ print $NF }'`
	
	TARGET=`ls /var/lib/etherburn/type/${speedtype}/ipaddrs | grep -v ${nic} | head -n 1`
	echo ${TARGET} 
	

	TARGETIP=`cat /var/lib/etherburn/type/${speedtype}/ipaddrs/${TARGET}`
	
echo ${TARGETIP} 

	mv /var/lib/etherburn/type/${speedtype}/ipaddrs/${TARGET} /var/lib/etherburn/type/${speedtype}/ipaddrs_used/${TARGET}
	
	sleep 1
	$netnscmd numactl --physcpubind=${NUMANODE} --membind=${NUMANODE} iperf -c ${TARGETIP} -t 60 | tee -a /var/lib/etherburn/logs/${nic}_client.log
	sleep 1

   else 
   	:
   fi
    

done
