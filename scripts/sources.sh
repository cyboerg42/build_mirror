#!/bin/bash
cp $1 ../src/
cd ../src/

while read -r line; do
	apt-get -y source "$(echo $line | awk '{print $2}')=$(echo $line | awk '{print $3}')"
	sudo apt-get -y build-dep "$(echo $line | awk '{print $2}')=$(echo $line | awk '{print $3}')"
done < $1
