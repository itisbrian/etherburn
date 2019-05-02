EtherBurn v1.0

1/11/18

*Currently only works on cburn
*For any NICs larger than 25G , it is recommended you update the drivers first before executing the script manually.

------------------------------------------------------------------------------------------
Conditions: 
------------------------------------------------------------------------------------------
1. plug in all ports, all links must be up.
2. total ports must be even number
3. link speed must be the same as max advertised (10G ports must be on 10G switch )
5. each link speed type ( 10G, 25G, etc..) must have even number of ports. if you have 1 single 100G card, you need to insert another 100G, so the ports can talk to each other properly.

if any of these conditions are not met, the test will exit

-----------------------------------------------------------------------------------------
Usage
-----------------------------------------------------------------------------------------
1. PXE RC Command

Usage example: cburn-r74 DIR=/sysv/brian/test/ RC=http://westworld.bnet/ethburn/ethburn.sh​

view progress on Alt + F9
logs located under the "etherburn" folder in the cburn directory after everything is complete.

2. Execute in cburn manually.

change the cburn root password using "passwd" 
look for eth0 ip address, and SSH into it.
create folder under root called "screen", /root/screen
put the 2 files below into /root/screen

http://westworld.bnet/ethburn/etherburn.sh
http://westworld.bnet/ethburn/ether_server.sh

chmod +x both files
run ./etherburn.sh

