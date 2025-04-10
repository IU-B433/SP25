#!/bin/bash
# update the apt package index
sudo apt update
# install pip
sudo apt install python3-pip -y
# install tensorflow
pip3 install tensorflow-cpu
# install matplotlib
pip3 install matplotlib

