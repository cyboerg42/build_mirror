#!/bin/bash
cp $1 ../src/
cd ../src/

while read -r line; do
	apt-get -y source $(echo $line | awk '{print $1}')
	sudo su -c "apt-get -y build-dep $(echo $line | awk '{print $1}')"
done < $1
