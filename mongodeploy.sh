#!/bin/bash

image_dir="/data/images"  
if [ -d ${image_dir} ];then  
        mv /data/images /data/images.bak
        mkdir -p /data/images
else  
        mkdir -p /data/images
fi  
touch ${image_dir}/Dockerfile_mongo  
echo "FROM centos:centos7" >> ${image_dir}/Dockerfile_mongo  
echo "MAINTAINER core <tengwanginit@gmail.com>" >> ${image_dir}/Dockerfile_mongo  
echo " " >> ${image_dir}/Dockerfile_mongo  
echo "RUN yum -y update" >> ${image_dir}/Dockerfile_mongo  
echo " " >> ${image_dir}/Dockerfile_mongo  
echo "RUN  echo '[mongodb-org-3.4]' > /etc/yum.repos.d/mongodb-org-3.4.repo" >> ${image_dir}/Dockerfile_mongo  
echo "RUN  echo 'name=MongoDB Repository' >> /etc/yum.repos.d/mongodb-org-3.4.repo" >> ${image_dir}/Dockerfile_mongo  
echo "RUN  echo 'baseurl=http://repo.mongodb.org/yum/redhat/7/mongodb-org/3.4/x86_64/' >> /etc/yum.repos.d/mongodb-org-3.4.repo" >> ${image_dir}/Dockerfile_mongo  
echo "RUN  echo 'enabled=1' >> /etc/yum.repos.d/mongodb-org-3.4.repo" >> ${image_dir}/Dockerfile_mongo  
echo "RUN  echo 'gpgcheck=0' >> /etc/yum.repos.d/mongodb-org-3.4.repo" >> ${image_dir}/Dockerfile_mongo  
echo " " >> ${image_dir}/Dockerfile_mongo  
echo "RUN yum -y install make" >> ${image_dir}/Dockerfile_mongo  
echo "RUN yum -y install mongodb-org" >> ${image_dir}/Dockerfile_mongo  
echo "RUN mkdir -p /data/db" >> ${image_dir}/Dockerfile_mongo  
echo " " >> ${image_dir}/Dockerfile_mongo  
echo "EXPOSE 27017" >> ${image_dir}/Dockerfile_mongo  
echo "ENTRYPOINT [\"/usr/bin/mongod\"]" >> ${image_dir}/Dockerfile_mongo  
docker build -t centos7/mongo:3.4 -<${image_dir}/Dockerfile_mongo  
# 运行非认证的mongo容器
# 编写docker-compose.yml文件并
mongo_dir="/data/gooalgene/mongo"  
if [ ! -d ${mongo_dir}/mongo ];then  
        mkdir -p ${mongo_dir}/mongo
fi  
touch ${mongo_dir}/docker-compose.yml  
echo "always madvise [never]" > ${mongo_dir}/enabled  
echo "always madvise [never]" > ${mongo_dir}/defrag  
if [ ! -f "/etc/localtime" ];then  
        cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
fi  
if [ ! -f "/etc/timezone" ];then  
        echo "Asia/Shanghai" > /etc/timezone
fi  
echo "mongo_linuxwt:" > ${mongo_dir}/docker-compose.yml  
echo "  restart: always" >> ${mongo_dir}/docker-compose.yml  
echo "  image: centos7/mongo:3.4" >> ${mongo_dir}/docker-compose.yml  
echo "  container_name: mongo_linuxwt" >> ${mongo_dir}/docker-compose.yml  
echo "  volumes:" >> ${mongo_dir}/docker-compose.yml  
echo "    - /etc/localtime:/etc/localtime" >> ${mongo_dir}/docker-compose.yml  
echo "    - /etc/timezone:/etc/timezone" >> ${mongo_dir}/docker-compose.yml  
echo "    - \$PWD/mongo:/data/db" >> ${mongo_dir}/docker-compose.yml  
echo "    - \$PWD/enabled:/sys/kernel/mm/transparent_hugepage/enabled" >> ${mongo_dir}/docker-compose.yml  
echo "    - \$PWD/defrag:/sys/kernel/mm/transparent_hugepage/defrag" >> ${mongo_dir}/docker-compose.yml  
echo "  ulimits:" >> ${mongo_dir}/docker-compose.yml  
echo "    nofile:" >> ${mongo_dir}/docker-compose.yml  
echo "      soft: 300000" >> ${mongo_dir}/docker-compose.yml  
echo "      hard: 300000" >> ${mongo_dir}/docker-compose.yml  
echo "  ports:" >> ${mongo_dir}/docker-compose.yml  
echo "      - \"27117:27017\"" >> ${mongo_dir}/docker-compose.yml  
echo "  command: --port 27017 --oplogSize 204800 --profile=1 --slowms=500" >> ${mongo_dir}/docker-compose.yml  
# 启动非认证mongo容器
cd ${mongo_dir} && docker-compose up -d  


# 创建库用户并验证
# 先在宿主机安装mongo客户端
wget http://downloads.mongodb.org/linux/mongodb-linux-x86_64-rhel70-3.6.6.tgz  
tar vxf mongodb-linux-x86_64-rhel70-3.6.6.tgz  
mv mongodb-linux-x86_64-rhel70-3.6.6 /usr/local/mongodb  
echo "PATH=/usr/local/mongodb/bin:\$PATH" >> /etc/profile  
echo "export PATH" >> /etc/profile  
source /etc/profile  
# 创建admin库用户授予读写权限并验证、创建项目库core的用户授予读写权限并验证
docker exec -it mongo_linuxwt mongo admin --eval "db.createUser({user:\"$1\", pwd:\"$2\", roles:[{role:\"root\", db:\"admin\"},{role:\"clusterAdmin\",db:\"admin\"}]})"  
docker exec -it mongo_linuxwt mongo $3 --eval "db.createUser({user:\"$7\", pwd:\"$8\", roles:[{role:\"root\", db:\"admin\"},{role:\"clusterAdmin\",db:\"admin\"}]})"  
docker exec -it mongo_linuxwt mongo $4 --eval "db.createUser({user:\"$7\", pwd:\"$9\", roles:[{role:\"root\", db:\"admin\"},{role:\"clusterAdmin\",db:\"admin\"}]})"  
docker exec -it mongo_linuxwt mongo $5 --eval "db.createUser({user:\"$7\", pwd:\"${10}\", roles:[{role:\"root\", db:\"admin\"},{role:\"clusterAdmin\",db:\"admin\"}]})"  
docker exec -it mongo_linuxwt mongo $6 --eval "db.createUser({user:\"$7\", pwd:\"${11}\", roles:[{role:\"root\", db:\"admin\"},{role:\"clusterAdmin\",db:\"admin\"}]})"

# 进行验证需要获得服务器的网络地址
ip_netmask=$(ip addr | grep 'ens32' | grep 'inet' | awk '{print $2}')  
ip=${ip_netmask:0:9}  
mongo_port=$(docker port mongo_linuxwt | awk '{print $3}')  
mongo_port1=${mongo_port:7:6}  
# 验证mongo库用户
docker exec -it mongo_linuxwt mongo admin --eval "db.auth(\"$1\",\"$2\")"  
if [ $? -eq 0 ];then  
        remote_check_mongo="mongo ${ip}${mongo_port1}/admin -u "$1" -p "$2" -authenticationDatabase 'admin'"
        echo "local check login of admin database is ok and please use the command - ${remote_check_mongo} - check the remote login."
        sleep 5
        mongo ${ip}${mongo_port1}/admin -u "$1" -p "$2" -authenticationDatabase 'admin'
        mongo ${ip}${mongo_port1}/$3 -u "$7" -p "$8" -authenticationDatabase "$3"
        mongo ${ip}${mongo_port1}/$4 -u "$7" -p "$9" -authenticationDatabase "$4"
        mongo ${ip}${mongo_port1}/$5 -u "$7" -p "${10}" -authenticationDatabase "$5"
        mongo ${ip}${mongo_port1}/$6 -u "$7" -p "${11}" -authenticationDatabase "$6"
        if [ $? -eq 0 ];then
                echo "mongo remote login is ok"
        else
                echo "mongo remote login is unavaiable"
                exit -1
        fi
fi  
# 运行认证的mongo容器
cp docker-compose.yml docker-compose.yml.noauth  
docker-compose down  
# 判断是否正确down掉
mongo_linuxwt_down=$(docker-compose down | grep "mongo_linuxwt" | wc -l)  
if [ ${mongo_linuxwt_down} == 0 ];then  
        echo "mongo_linuxwt down normally"
else  
        echo "docker-compose down failed and please check the container which is running.."
        exit -1
fi  
sed -i 's/command.*/& --auth/g' docker-compose.yml && docker-compose up -d  
if [ $? -eq 0 ];then  
        echo "mongo container with authentication is running" 
else  
        exit -1
fi
