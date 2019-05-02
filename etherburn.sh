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
################################################ SUPREME ###############################
echo ""
echo ""
echo -e "           \e[32m███████\e[0m╗\e[32m██\e[0m╗   \e[32m██\e[0m╗\e[32m███████\e[0m╗\e[32m██\e[0m╗      \e[32m█████\e[0m╗ \e[32m██████\e[0m╗ "
echo -e "           \e[32m██\e[0m╔════╝╚\e[32m██\e[0m╗ \e[32m██\e[0m╔╝\e[32m██\e[0m╔════╝\e[32m██\e[0m║     \e[32m██\e[0m╔══\e[32m██\e[0m╗\e[32m██\e[0m╔══\e[32m██\e[0m╗"
echo -e "           \e[32m███████\e[0m╗ ╚\e[32m████\e[0m╔╝ \e[32m███████\e[0m╗\e[32m██\e[0m║     \e[32m███████\e[0m║\e[32m██████\e[0m╔╝"
echo -e "           ╚════\e[32m██\e[0m║  ╚\e[32m██\e[0m╔╝  ╚════\e[32m██\e[0m║\e[32m██\e[0m║     \e[32m██\e[0m╔══\e[32m██\e[0m║\e[32m██\e[0m╔══\e[32m██\e[0m╗"
echo -e "           \e[32m███████\e[0m║   \e[32m██\e[0m║   \e[32m███████\e[0m║\e[32m███████\e[0m╗\e[32m██\e[0m║  \e[32m██\e[0m║\e[32m██████\e[0m╔╝"
echo -e "           ╚══════╝   ╚═╝   ╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ "
echo " "
echo -e " \e[5m                         SYSLAB Supreme AEther Test.\e[25m"
echo -e "\e[32m                report errors to brianchen@supermicro.com \e[0m"
echo " "
echo "--------------------------------------------------------------------------------------------------------------------------------"
sleep 5
#################################################################################################

iperftime=600

#killing tmux and unmounting
pkill tmux
umount /mnt


yum install -y screen
yum install -y iperf3

function ether_create () {
	mkdir -p /var/lib/etherburn/logs
	touch /var/lib/etherburn/interfaces
	touch /var/lib/etherburn/cburn_interface
    touch /var/lib/etherburn/netns_list
    touch /var/lib/etherburn/oglinks
}

ether_create

#-------------------------------------------------------------------------------------------------------------------------

errcount=0

function ethcount () {

  #count number of eth links, if it is zero, exit
  ls /sys/class/net | grep -v "lo" | grep -v "virbr" > /var/lib/etherburn/oglinks
  A=`ls /sys/class/net | grep -v "lo" | grep -v "virbr"| wc -l` 


    if [ $A -eq 0 ]; then
      echo "No links found, check your NIC."
      echo "Exiting."
      exit 1
    fi 
   
    #calculate odd or even, if it is not even, exit
    B=`expr $A % 2`
    
    if [ $B -ne 0 ]; then
      echo "Number of links found : ${A}."
      echo "Number of links must be even."
      echo "Exiting."
        exit 1 
    fi
}

function linkcount () {

for entry in `cat /var/lib/etherburn/oglinks | grep -v "lo"| grep -v "virbr"` ; do

    C=`ethtool ${entry} | grep -i "link detected" | grep -Eo "[^ ]+$"`
    if [ "$C" == "yes" ] ; then
        :
    elif [ "$C" == "no" ]; then
        echo "${entry}: Link not found."
        echo "Exiting."
        exit 1
     else 
        echo "${entry}: Error detecting link status."
        echo "Exiting."
       exit 1
    fi
 
done


}


function speedcheck () {

for entry in `cat /var/lib/etherburn/oglinks | grep -v "lo"| grep -v "virbr"` ; do
#  grep -Eo "[^ ]+$" = get entry after 1st space
    S=`ethtool ${entry} | grep "Speed" | grep -Eo "[^ ]+$"`
    
    if [ "S" == "Unknown!" ]; then
      echo "${entry}: Link speed Unknown"
      ((errcount+=1))
    fi
done

}

function linkuniq () {
for entry in `ls /sys/class/net | grep -v "lo" | grep -v "virbr"`; do
 ethtool ${entry} | grep 'Speed' | grep -o '[0-9]*' >> /var/lib/etherburn/oglinks.log
  done
touch /var/lib/etherburn/uniqlinks.log
cat /var/lib/etherburn/oglinks.log | sort -u >> /var/lib/etherburn/uniqlinks.log
C=`cat /var/lib/etherburn/uniqlinks.log`
echo "Unique Link Types :"
echo "${C}"
echo " "
for entry in `cat /var/lib/etherburn/uniqlinks.log`; do
  mkdir -p /var/lib/etherburn/type/type_${entry}

#  mkdir  -p /var/lib/etherburn/type/type_${entry}/ipaddrs
#mkdir -p /var/lib/etherburn/type/type_${entry}/ipaddrs_used
#mkdir -p /var/lib/etherburn/type/type_${entry}/dhclientpids
mkdir  -p /var/lib/etherburn/ips/type_${entry}/ipaddrs
mkdir -p /var/lib/etherburn/ips/type_${entry}/ipaddrs_used
mkdir -p /var/lib/etherburn/ips/type_${entry}/dhclientpids

  echo "type_${entry} directory created."
  echo " "
done 

for entry in `cat /var/lib/etherburn/oglinks | grep -v "lo" | grep -v "virbr"`; do

  for type in `cat /var/lib/etherburn/uniqlinks.log`; do
       A=`ethtool ${entry} | grep '/Full' | cut -d':' -f2 | awk '{ print $1 }' | sort -u -n -r | head -n 1 | sed "s/[base].*//"`
       if [ ${A} == ${type} ]; then
        echo "${entry} > type_${A}"
        touch /var/lib/etherburn/type/type_${A}/${entry}
       else
       :
       fi
       done 
       echo " "
done

for entry in `cat /var/lib/etherburn/uniqlinks.log`; do
    A=`ls /var/lib/etherburn/type/type_${entry} | wc -l`
    B=`expr $A % 2`
    if [ $B -ne 0 ]; then
      echo "Number of links uneven for speed type ${entry}."
      ((errcount+=1))
    fi
done

}




function linkmatch () {
	
for entry in `ls /sys/class/net | grep -v "lo" | grep -v "virbr"`; do

	A=`ethtool ${entry} | grep '/Full' | cut -d':' -f2 | awk '{ print $1 }' | sort -u -n -r | head -n 1 | sed "s/[base].*//"`
	B=`ethtool ${entry} | grep 'Speed' | grep -o '[0-9]*'`


    if [ $A -gt $B ]; then
       echo "${entry} : Low Link Speed Detected."
       echo "${entry} : Max Link Speed = ${A}, Current link speed = ${B}"
       echo " "
       ((errcount+=1))
    elif [ $A -eq $B ]; then
       echo "${entry} : Optimal Link Speed Detected."
       echo "${entry} : Running at ${A}."
       echo " "   
    fi

	
done 
 

}



function errorcheck () {

    if [[ $errcount -gt 0 ]]; then
      echo "Error count: $errorcount"
      echo "Exiting."
      exit 1
    else
      echo "Link check passed."
      echo " "
    fi

}


#-----------------------------------------------------------------------------------------------------------------------------------------------
echo "--------------------------------------------------------------------------------------------------------------------------------"
echo "Starting Link Check:"
echo " "

#-----------------------------------------------------------------------------------------------------------------------------------------------

ethcount
linkcount
linkuniq
linkmatch
errorcheck


echo "--------------------------------------------------------------------------------------------------------------------------------"
echo " "
echo "Dumping lspci to etherburn directory."
lspci | tee -a /var/lib/etherburn/lspci.log 
echo "Dump complete."
echo " "
echo "--------------------------------------------------------------------------------------------------------------------------------"
#------------------------------------------------------------------------------------------------------------------------------------------------
echo "Identifying / setting cburn interface: "
echo " "
ls /sys/class/net | grep -v "lo" | grep -v "virbr" | sort | head -n 1 > /var/lib/etherburn/cburn_interface

echo "Cburn interface : `cat /var/lib/etherburn/cburn_interface`"
echo " "
echo "--------------------------------------------------------------------------------------------------------------------------------"
#------------------------------------------------------------------------------------------------------------------------------------------------
echo "Identifying / setting netns: "
echo " "

for speedtype in `ls /var/lib/etherburn/type` ; do


	for entry in `ls /var/lib/etherburn/type/${speedtype}` ; do
        
        if [ "${entry}" == `cat /var/lib/etherburn/cburn_interface` ]; then
			     # SS=`ethtool ${entry} | grep "Speed" | grep -Eo "[^ ]+$" | grep -o '[0-9]*' `
           #         if [ $SS -gt 10000 ]; then
           #         ifconfig ${entry} mtu 9000 
           #     fi			
           echo "${entry} : Skipping cburn interface."
           ogip=`ip addr show dev ${entry} | grep 172.16 | awk '{ print $2 }' |cut -d'/' -f1 |head -n 1`

if [[ "$ogip" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
  echo "${entry} : IP valid, ${ogip}"
else
  echo "${entry} : IP not valid."
  exit 1
fi
          


     continue
		fi
        
        #netns add each entry
		ip netns add "test_${entry}" 
		echo "test_${entry}" >> /var/lib/etherburn/ips/${speedtype}/netns_list 
		if [ $? -ne 0 ]; then
			echo "${entry} : Error adding netns entry."
			exit 1
		fi
		#netns link set each entry
		ip link set ${entry} netns "test_${entry}"
		if [ $? -ne 0 ]; then
			echo "${entry} : Error setting netns entry."
			exit 1
		fi
        
    ip netns exec "test_${entry}" dhclient -pf /var/lib/etherburn/ips/${speedtype}/dhclientpids/dhclient_${entry}.pid

        if [ $? -ne 0 ]; then
			echo "${entry} : Error getting dhcp."
			exit 1
		fi
    # ip netns exec "test_${entry}" ip addr show dev ${entry} |grep 172.16 | awk '{ print $2 }' | cut -d'/' -f1 |
sleep 3
ip=`ip netns exec "test_${entry}" ip addr show dev ${entry} | grep 172.16 | awk '{ print $2 }' |cut -d'/' -f1 |head -n 1`

if [[ "$ip" =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
  echo "${entry} : IP valid, ${ip}"
else
  echo "${entry} : IP not valid."
  exit 1
fi
   # S=`ip netns exec "test_${entry}" ethtool ${entry} | grep "Speed" | grep -Eo "[^ ]+$" | grep -o '[0-9]*' `
   #  if [ $S -gt 10000 ]; then
   #     ip netns exec  "test_${entry}" ifconfig ${entry} mtu 9000 
   #     echo "${entry} : Setting mtu to 9000."
   #  fi


        echo "${entry} : Complete."
		#call screen or tmux with device_staging_server script ala:
		# screen -dm /root/screen/ether_server ${entry}
		 # if [ $? -ne 0 ]; then
			# echo "some error"
			# exit 1
		# fi
		 sleep 1


	done


	
done
echo " "
echo "Setting netns complete."
echo " "
echo "--------------------------------------------------------------------------------------------------------------------------------"
sleep 5


#---------------------------------------------------------------------------------------------------------------------------------------
#starting the server
#---------------------------------------------------------------------------------------------------------------------------------------
echo "Starting Servers: "
echo " "
for speedtype in `ls /var/lib/etherburn/type` ; do


  for entry in `ls /var/lib/etherburn/type/${speedtype}` ; do

     if [ "${entry}" == `cat /var/lib/etherburn/cburn_interface` ]; then
      screen -dm /root/screen/ether_server.sh ${entry} true
      echo "${entry} : Server started. "
      continue
    fi




    screen -dm /root/screen/ether_server.sh ${entry}
    echo "${entry} : Server started. "
    done

done



echo " "
echo "All servers started."
echo " "
echo "--------------------------------------------------------------------------------------------------------------------------------"
sleep 5


#---------------------------------------------------------------------------------------------------------------------------------------
#starting clients
#---------------------------------------------------------------------------------------------------------------------------------------
echo "Starting Clients: "
echo " "
for speedtype in `ls /var/lib/etherburn/type` ; do


  for entry in `ls /var/lib/etherburn/type/${speedtype}` ; do

    netnscmd="ip netns exec test_${entry}"
    if [ "${entry}" == `cat /var/lib/etherburn/cburn_interface` ]; then
      

      netnscmd=""
      
    fi
      NUMANODE=`$netnscmd cat /sys/class/net/${entry}/device/numa_node`
    
  #Pull off the first ip entry that doesn't match $nic
  #TARGET=`ls /var/lib/etherburn/ipaddrs | grep -v ${nic} | head -n 1 | awk -F"/" '{ print $NF }'`
  
  TARGET=`ls /var/lib/etherburn/ips/${speedtype}/ipaddrs | grep -v ${entry} | head -n 1`
  
  

  TARGETIP=`cat /var/lib/etherburn/ips/${speedtype}/ipaddrs/${TARGET}`
 echo " " 
echo "${entry} : Target IP -> ${TARGETIP}" 

  mv /var/lib/etherburn/ips/${speedtype}/ipaddrs/${TARGET} /var/lib/etherburn/ips/${speedtype}/ipaddrs_used/${TARGET}
  
  sleep 1
  #$netnscmd numactl --physcpubind=${NUMANODE} --membind=${NUMANODE} iperf -c ${TARGETIP} -t 60 -i 1 | tee -a /var/lib/etherburn/logs/${entry}_client.log
 
    SSS=`$netnscmd ethtool ${entry} | grep 'Speed' | grep -o '[0-9]*'`


    if [ $SSS -lt 30000 ]; then
    $netnscmd iperf -c ${TARGETIP} -t ${iperftime} -i 1 | tee -a /var/lib/etherburn/logs/${entry}_client.log
 
    fi




    if [ $SSS -gt 30000 ] && [ $SSS -lt 60000 ]; then
    $netnscmd iperf -c ${TARGETIP} -t ${iperftime} -P 4 -i 1 | tee -a /var/lib/etherburn/logs/${entry}_client.log
 
    fi


    if [ $SSS -gt 60000 ] ; then
    $netnscmd iperf -c ${TARGETIP} -t ${iperftime} -P 12 -i 1 | tee -a /var/lib/etherburn/logs/${entry}_client.log
 
    fi




 done


done
echo "--------------------------------------------------------------------------------------------------------------------------------"
echo "Test Complete."
mount -a
cat /root/stage2.conf | grep "SYS_DIR" > /root/flasher_config.sh
source /root/flasher_config.sh
RDIR="${SYS_DIR}"
cp -r /var/lib/etherburn ${RDIR}/
echo "Logs pushed to cburn directory."
echo "To reset network namespaces back to original, please reboot the server."
echo " "
echo "End of test."
echo "--------------------------------------------------------------------------------------------------------------------------------"