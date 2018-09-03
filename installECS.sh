#!/bin/bash

#Date: 2018-08-14

## fdisk and mount
echo "d  
n  
p  
1


w  
" | fdisk $1
mkfs.xfs -f ${1}1  
mkdir /data/  
mount ${1}1 /data  
mkdir -p /data/gooalgene

##  enable firewalld.
function_firewalld () {  
firewall-cmd --zone=public --add-port=43222/tcp --permanent  
firewall-cmd --zone=public --add-port=80-90/tcp --permanent  
firewall-cmd --zone=public --add-port=150/tcp --permanent  
firewall-cmd --zone=public --add-port=27117-27120/tcp --permanent  
firewall-cmd --zone=public --add-port=33066-33070/tcp --permanent  
}
firewalld_status=$(systemctl status firewalld)  
if [ ${firewalld_status} == "success" ];then  
    function_firewalld
else  
    systemctl start firewalld
    function_firewalld
fi  
firewall-cmd --reload  
systemctl restart firewalld  
systemctl enable firewalld  
systemctl daemon-reload

##  modify sshd_config

cp -ap /etc/fstab /etc/fstab.bak

echo "/dev/vdb1 /data xfs defaults 0 0"  >> /etc/fstab

cp -ap /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

sed -i '/#Port 22/a\Port 43222' /etc/ssh/sshd_config

sed -i 's!#PermitEmptyPasswords!PermitEmptyPasswords!g' /etc/ssh/sshd_config

systemctl restart sshd  
systemctl enable sshd  
systemctl daemon-reload

## 4. install packages and start docker service.

yum -y install epel-release && yum -y install docker && yum install -y python-pip  
yum -y install rsync lrzsz mlocate git openssh-clients wget

pip install docker-compose

echo "{\"registry-mirrors\": [\"https://nr630v1c.mirror.aliyuncs.com\"]}" > /etc/docker/daemon.json

systemctl start docker

systemctl enable docker

systemctl daemon-reload  
## 5. create user.

groupadd docker

useradd -G docker tengwang

passwd tengwang

systemctl restart docker  

chown -R tengwang.tengwang /data/gooalgene  
usermod -g dockerroot tengwang  
systemctl restart docker  
# close selinux
sed -i 's/enforcing/disabled/g' /etc/selinux/config  
sed -i 's/enforcing/disabled/g' /etc/sysconfig/selinux  
reboot  
