#!/bin/bash

# install java
sudo apt-get update -y && sudo apt-get install wget -y
sudo apt update -y && sudo apt install -y openjdk-18-jre-headless
sudo apt install unzip -y

# download besu binary
wget https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/23.4.4/besu-23.4.4.tar.gz -P /tmp
sudo tar -xzf /tmp/besu-*.gz -C /opt/
sudo mv /opt/besu-* /opt/besu
sudo chown -R ubuntu:ubuntu /opt/besu

mkdir besu-data
mkdir -p bootnode/keys
mkdir -p node1/keys
mkdir -p node2/keys
#mkdir -p node3/keys
