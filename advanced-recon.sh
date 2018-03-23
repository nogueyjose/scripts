#!/bin/bash
subnet=$1/24
interface=$2

nmap -sn -oG ping-sweep-nmap.txt $subnet
grep -v "#" ping-sweep-nmap.txt | cut -d " " -f2 > ips.txt
while read ip
do
    num=`echo $ip | cut -d " " -f2 | cut -d "." -f4`
    mkdir $num
    if [ $? -ne 0 ]
    then
        continue
    fi
    cd $num
    tshark -i $interface -w cap-$num.pcapng > /dev/null 2>&1 &
    nmap -sV --packet-trace $ip | tee nmap-$num.txt
    killall tshark
    remove_zeros() {
	for original_name in `ls`; do
   	  # determine new file name from original:
    	# remove zeroes 
    	new_name=$(echo "$original_name" | sed -e 's/\.0*/\./g' -e s'/^0*//g' -e s'/-0*/-/g' )
    	mv "$original_name" "$new_name"
	done
    }
	tcpflow -o $num-streams -r cap-$num.pcapng
	cd $num-streams
	remove_zeros
	myip=`ifconfig | grep -A1 $interface | grep inet | awk '{print $2}'`
	ls | grep -E -v "^$ip.*$myip" | xargs rm
	for file in $(ls); do
        	HEX=`xxd -p $file | tr -d '\n' | sed -e 's/.\{2\}/\\\\x&/g' -e s'/^/"/g' -e s'/$/"/g'`
        	PORT=`echo $file | awk -F. '{print $5}' | cut -d- -f1`
        	#echo $PORT $HEX >> portspoof-$ip.conf
        	echo $PORT $HEX >> tmp.conf
	done
sort -u < tmp.conf > portspoof-$ip.conf
rm tmp.conf
cd ..
    lines=`grep -i "service scan match" nmap-$num.txt | grep -o 'line [0-9]*' | cut -d " " -f2`
    for line in $lines
    do
        echo $line >> service-probes-$num.txt
        head -$line /usr/share/nmap/nmap-service-probes | tail -1 >> service-probes-$num.txt
        sed -i 'N;s/\n/ /' service-probes-$num.txt
    done
    cd ..
done < ips.txt
