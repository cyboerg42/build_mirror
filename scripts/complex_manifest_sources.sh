#!/bin/bash
cp $1 ../src/
cd ../src/
apt-get -y source $(awk '{print $1}' $1)
sudo apt-get -y build-dep $(awk '{print $1}' $1)

