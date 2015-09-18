#!/bin/bash

# Update the client and install java
echo "Installing java..."
sudo yum -y update > /dev/null 2>&1
sudo yum -y install java-1.8.0-openjdk-devel.x86_64 java-1.8.0-openjdk-javadoc.noarch > /dev/null 2>&1

# High I/O node?
if ! ethtool -i eth0 | grep -q ixgbevf ; then
  echo "Node configuration does not support high speed I/O on ethernet"
fi

# Installing maven on Amzon AMI is yucky
echo "wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo" > /tmp/install_maven.sh
echo "sed -i \"s/\\\$releasever/6/g\" /etc/yum.repos.d/epel-apache-maven.repo" >> /tmp/install_maven.sh
echo "yum -y install apache-maven > /dev/null 2>&1" >> /tmp/install_maven.sh

sudo bash /tmp/install_maven.sh

# Download and build aerospike benchmark tool
echo "Installing aerospike benchmark tool"
wget --output-document aerospike-client-java.tgz http://www.aerospike.com/download/client/java/3.0.31/artifact/tgz
tar -zxvf aerospike-client-java.tgz
cd aerospike-client-java-*
export JAVA_HOME=$(readlink -f `which javac` | sed "s:bin/javac::")
./build_all
echo $1 > server_ip.txt
