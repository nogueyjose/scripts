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
    nmap -Pn -sV -vv --packet-trace $ip | tee nmap-$num.txt
    killall tshark
    lines=`grep -i "service scan match" nmap-$num.txt | grep -o 'line [0-9]*' | cut -d " " -f2`
    for line in $lines
    do
        echo $line >> service-probes-$num.txt
        head -$line /usr/share/nmap/nmap-service-probes | tail -1 >> service-probes-$num.txt
        sed -i 'N;s/\n/ /' service-probes-$num.txt
    done
    cd ..
done < ips.txt
