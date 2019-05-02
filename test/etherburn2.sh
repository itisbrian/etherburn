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



#get / set cburn directory
cat /root/stage2.conf | grep "SYS_DIR" > /root/flasher_config.sh
source /root/flasher_config.sh
RDIR="${SYS_DIR}"

yum install -y screen


function ether_create () {
	mkdir -p /var/lib/etherburn/logs
	mkdir -p /var/lib/etherburn/dhclientpids
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
  ls /sys/class/net | grep -v "lo" > /var/lib/etherburn/oglinks
  A=`ls /sys/class/net | grep -v "lo" | wc -l` 


    if [ $A -eq 0 ]; then
      echo "No links found, check your NIC."
      echo "Exiting."
      exit 1
    fi 
   
    #calculate odd or even, if it is not even, exit
    B=`expr $A % 2`
    
    if [ $B -ne 0 ]; then
      echo "Number of links found : ${a}."
      echo "Number of links must be even."
      echo "Exiting."
        exit 1 
    fi
}

function linkcount () {

for entry in `cat /var/lib/etherburn/oglinks | grep -v "lo"` ; do

    C=`ethtool ${entry} | grep -i "link detected" | grep -Eo "[^ ]+$"`
    if [ "$C" == "yes" ] ; then
        :
    elif [ "$C" == "no" ]; then
        echo "${entry}: Link not found."
        ((errcount+=1))
     else 
        echo "${entry}: Error detecting link status."
        ((errcount+=1))
    fi
 
done


}


function speedcheck () {

for entry in `cat /var/lib/etherburn/oglinks | grep -v "lo"` ; do
#  grep -Eo "[^ ]+$" = get entry after 1st space
    S=`ethtool ${entry} | grep "Speed" | grep -Eo "[^ ]+$"`
    
    if [ "S" == "Unknown!" ]; then
      echo "${entry}: Link speed Unknown"
      ((errcount+=1))
    fi
done

}

function linkuniq () {
for entry in `ls /sys/class/net | grep -v "lo"`; do
 ethtool ${entry} | grep 'Speed' | grep -o '[0-9]*' >> /var/lib/etherburn/oglinks.log
  done
touch /var/lib/etherburn/uniqlinks.log
cat /var/lib/etherburn/oglinks.log | sort -u >> /var/lib/etherburn/uniqlinks.log
C=`cat /var/lib/etherburn/uniqlinks.log`
echo "Unique Link Types :"
echo "${C}"
echo ""
for entry in `cat /var/lib/etherburn/uniqlinks.log`; do
  mkdir /var/lib/etherburn/type/type_${entry}
  mkdir -p /var/lib/etherburn/type/type_${entry}/ipaddrs
mkdir -p /var/lib/etherburn/type/type_${entry}/ipaddrs_used
  echo "type_${entry} directory created."
done 

for entry in `cat /var/lib/etherburn/oglinks | grep -v "lo"`; do

  for type in `cat /var/lib/etherburn/uniqlinks.log`; do
       A=`ethtool ${entry} | grep '/Full' | cut -d':' -f2 | awk '{ print $1 }' | sort -u -n -r | head -n 1 | grep -o '[0-9]*'`
       if [ ${A} == ${type} ]; then
        echo "${entry} > type_${A}"
        touch /var/lib/etherburn/type/type_${A}/${entry}
       else
       :
       fi
       done 
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



function errorcheck () {

    if [[ $errcount -gt 0 ]]; then
      echo "Error count: $errorcount"
      echo "Exiting."
      exit 1
    else
      echo "Link check passed."
    fi

}


function linkmatch () {
	
for entry in `ls /sys/class/net | grep -v "lo"`; do

	A=`ethtool ${entry} | grep '/Full' | cut -d':' -f2 | awk '{ print $1 }' | sort -u -n -r | head -n 1 | grep -o '[0-9]*'`
	B=`ethtool ${entry} | grep 'Speed' | grep -o '[0-9]*'`


    if [ $A -gt $B ]; then
       echo "${entry} : Low Link Speed Detected."
       echo "${entry} : Max Link Speed = ${A}, Current link speed = ${B}"
       echo " "
    elif [ $A -eq $B ]; then
       echo "${entry} : Optimal Link Speed Detected."
       echo "${entry} : Running at ${A}."
       echo " "   
    fi

	
done 
 

}




#-----------------------------------------------------------------------------------------------------------------------------------------------

ethcount
linkcount

linkuniq


errorcheck

linkmatch


#------------------------------------------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------------------------------------------
for speedtype in `ls /var/lib/etherburn/type` ; do


	for entry in `ls /var/lib/etherburn/type/${speedtype}; do
        
        if [ "${entry}" == `cat /var/lib/etherburn/cburn_interface` ]; then
			echo "${entry} is same as cburn interface."
			# screen -dm /root/screen/s ${entry} true
			continue
		fi
        
        #netns add each entry
		ip netns add "test_${entry}" 
		echo "test_${entry}" >> /var/lib/etherburn/type/${speedtype}/netns_list 
		if [ $? -ne 0 ]; then
			echo "some error"
			exit 1
		fi
		#netns link set each entry
		ip link set ${entry} netns "test_${entry}"
		if [ $? -ne 0 ]; then
			echo "some error"
			exit 1
		fi
        
        ip netns exec "test_${entry}" dhclient -pf /var/lib/etherburn/type/${speedtype}/dhclientpids/dhclient_${entry}.pid

        if [ $? -ne 0 ]; then
			echo "some error"
			exit 1
		fi
 

		#call screen or tmux with device_staging_server script ala:
		# screen -dm /root/screen/ether_server ${entry}
		 # if [ $? -ne 0 ]; then
			# echo "some error"
			# exit 1
		# fi
		 sleep 1


	done


	
done
echo "set netns stuff done."
#---------------------------------------------------------------------------------------------------------------------------------------
#starting the server
#---------------------------------------------------------------------------------------------------------------------------------------

for speedtype in `ls /var/lib/etherburn/type` ; do


	for entry in `ls /var/lib/etherburn/type/${speedtype}; do

     if [ "${entry}" == `cat /var/lib/etherburn/cburn_interface` ]; then
			screen -dm /root/screen/ether_server.sh ${entry} true
			continue
		fi




    screen -dm /root/screen/ether_server.sh ${entry}

    done

done




echo "server started "
sleep 5


#---------------------------------------------------------------------------------------------------------------------------------------
#starting clients
#---------------------------------------------------------------------------------------------------------------------------------------
for speedtype in `ls /var/lib/etherburn/type` ; do


	for entry in `ls /var/lib/etherburn/type/${speedtype}; do


		 if [ "${entry}" == `cat /var/lib/etherburn/cburn_interface` ]; then
		 screen -dm /root/screen/ether_client.sh ${entry} true
		 echo "doing eth0"
			 continue
		 fi

       
		#call screen or tmux with device_staging_client script ala:
         screen -dm /root/screen/ether_client.sh ${entry}
         echo "doing ${entry}"
 done


done

echo "Starting Clients."
sleep 5

#---------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------



	while [ `ps -ef |grep 'iperf -c' | grep -v grep | wc -l` -ne 0 ]; do
		for logfile in `ls /var/lib/etherburn/logs`; do
			tail -n 1 /var/lib/etherburn/logs/${logfile}
		done
		sleep 0.25
	done