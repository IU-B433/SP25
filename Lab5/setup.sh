#!/bin/bash

# Install gcc and build-essential
sudo apt update
sudo apt install gcc -y
sudo apt install libc6-dev-i386 -y
sudo apt-get install build-essential -y

# Install redare2
mkdir ~/bin
cd ~/bin
git clone https://github.com/radareorg/radare2.git
cd radare2
sudo sys/install.sh

# Check if radare2 is installed
r2 -v