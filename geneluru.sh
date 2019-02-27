#!/bin/bash

# 防火墙配置
setenforce 0
sed -i 's/enforcing/disabled/g' /etc/selinux/config
sed -i 's/enforcing/disabled/g' /etc/sysconfig/selinux
systemctl stop firewalld

# 时区同步
if [ ! -f "/etc/localtime" ];then
        cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
fi
if [ ! -f "/etc/timezone" ];then
        echo "Asia/Shanghai" > /etc/timezone
fi

# 更换yum源及常用工具安装
yum -y install wget
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
wget http://mirrors.163.com/.help/CentOS7-Base-163.repo
mv CentOS7-Base-163.repo /etc/yum.repos.d/CentOS-Base.repo
yum clean all && yum makecache && yum -y update 
yum -y install lrzsz && yum -y install openssh-clients && yum -y install rsync

# 项目目录配置
project_dir="/data/gooalgene"
if [ ! -d ${project_dir} ];then
     mkdir -p ${project_dir}
else
     mv ${project_dir} ${project_dir}.bak`date "+%Y%m%d"`
     mkdir -p ${project_dir}
fi

# 安装docker18.03
installdocker()
{
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager  --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum makecache fast
yum -y install docker-ce-18.03*
}
docker version
if [ $? -eq 127 ];then
    installdocker
    docker version
    if [ $? -lt 127 ];then
        echo "docker install successful."
    else
        echo "docker install failed"
        exit -1
    fi
elif [ $? -eq 1 ];then
    echo "docker exist,next uninstall old docker."
    rpm -qa | grep docker | xargs rpm -e --nodeps
    docker version
    if [ $? -eq 127 ];then
        echo "old docker have uninstalled."
        installdocker
        docker version
        if [ $? -lt 127 ];then
            echo "docker install successful."
        else
            echo "docker install failed"
            exit -1
        fi
    else
        echo "docker uninstall failed."
        exit -1
    fi
else 
    exit 0
fi
docker_version=$(docker version | grep "Version" | awk '{print $2}' | head -n 2 | sed -n '2p')
systemctl start docker
if [ $? -eq 0 ];then
    echo "docker start successfully."
    echo "docker version is ${docker_version}"
else
    echo "docker start failed."
    exit -1
fi

# 配置docker加速拉取
echo {\"registry-mirrors\":[\"https://nr630v1c.mirror.aliyuncs.com\"]} > /etc/docker/daemon.json

# 更改docker默认存储位置
sed -i 's/\/usr\/bin\/dockerd/\/usr\/bin\/dockerd --graph \/data\/gooalgene\/docker/g' /usr/lib/systemd/system/docker.service
systemctl daemon-reload && systemctl restart docker
docker info | grep data/gooalgene/docker
if [ $? -eq 0 ];then
    echo "docker default storage space configure successfully."
else
    echo "docker default storage space configure failed."
    exit -1
fi
systemctl enable docker
systemctl daemon-reload

# 安装docker-compose
yum -y install epel-release  && yum -y install python-pip  && pip install docker-compose  && pip install --upgrade pip 
docker-compose_version=$(docker-compose version | grep 'docker-compose' | awk '{print $3}')
docker-compose version
if [ $? -eq 0 ];then
    echo "docker-compose install successfully."
    echo "the docker-compose version is ${docker-compose_version}"
else
    echo "docker-compose install failed."
    exit -1
fi

# jdk maven部署
java -version
if [ $? -eq 127 ];then
  echo "you should install jdk"
  echo "start to install jdk..."
  sleep 5
  yum -y install java-1.8.0-openjdk
  yum -y install java-1.8.0-openjdk-devel
fi

java_dir="${project_dir}/java"

if [ ! -d ${java_dir} ];then
    mkdir -p ${java_dir}
else
    mv ${java_dir} ${java_dir}.bak`date "+%Y%m%d"`
    mkdir -p ${java_dir}
fi

mvn 
 
if [ $? -eq 127 ];then
cd ${java_dir}
wget  http://apache.fayea.com/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz
tar zvxf apache-maven-3.5.4-bin.tar.gz
    if [ $? -ne 0 ];then
        echo "maven install failed."
        wget http://apache.fayea.com/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.zip
        unzip apache-maven-3.5.4-bin.zip
    fi 
mv apache-maven-3.5.4 maven3.5
cat <<EOF>> /etc/profile
export JAVA_HOME=/usr/lib/jvm/java-openjdk MAVEN_HOME=/data/gooalgene/java/maven3.5
export CLASSPATH=.:\$JAVA_HOME/lib/rt.jar:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar
export PATH=\$JAVA_HOME/bin:\$MAVEN_HOME/bin:\$PATH
EOF
fi

# 安装nginx
nginx_dir="${project_dir}/dbs/nginx"
if [ ! -d ${nginx_dir} ];then
    mkdir -p ${nginx_dir}
else
    mv ${nginx_dir} ${nginx_dir}.bak`date "+%Y%m%d"`
    mkdir -p ${nginx_dir}
fi

mkdir -p ${nginx_dir}/conf
cd ${nginx_dir}

cat <<EOF>> ${nginx_dir}/docker-compose.yml
nginx_gooalinput:
   restart: always
   image: nginx
   container_name: nginx_gooalinput
   volumes:
       - $PWD/conf/nginx.conf:/etc/nginx/nginx.conf
       - $PWD/conf/nginx_reverse.conf:/etc/nginx/conf.d/default.conf
       - /etc/localtime:/etc/timezone
       - /etc/timezone:/etc/timezone
       - ./html:/usr/share/nginx/html
   privileged: true
   ports:
       - 74:80
EOF
cat <<EOF>> ${nginx_dir}/conf/nginx.conf
user  nginx;  
worker_processes  1;
error_log  /var/log/nginx/error.log warn;  
pid        /var/run/nginx.pid;
events {  
    worker_connections  1024;
}
http {  
    include       /etc/nginx/mime.types;
        server_tokens off;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  3000;
    gzip  on;
    gzip_min_length  1k;
    gzip_buffers     4 16k;
    gzip_http_version 1.1;
    gzip_comp_level 2;
    #  下面是一整段
    gzip_types text/plain image/png  application/javascript application/x-javascript  text/javascript text/css application/xml image/x-icon application/xml+rss 
    application/json; 
    gzip_vary on;
    gzip_proxied   expired no-cache no-store private auth;
    gzip_disable   "MSIE [1-6]\.";
    include /etc/nginx/conf.d/*.conf;
}
EOF
ip=$(ip addr  | grep inet | grep brd | grep en | awk '{print $2}' | awk -F '/' '{print $1}')
cat <<EOF>>  ${nginx_dir}/conf/nginx_reverse.conf
server {
    listen  80;
    location / {
              root /usr/share/nginx/html;
              index index.html;
              try_files \$uri \$uri/ @router;
} 
    location /images {
              root /usr/share/nginx/html;
              index index.html;
              autoindex on;
              autoindex_exact_size off;
              autoindex_localtime on;
              try_files \$uri \$uri/ @router1;
    }  
    location /api  {
                  proxy_pass http://${ip}:8085/;
}
location @router {
               rewrite ^.*\$ /index.html last;
}
location @router1 {
               rewrite ^.*\$ /index.html last;
}
}
EOF

# 代码部署
# 后端部署
back_dir="${project_dir}/geneluru_end"
branch1="master"
if [ ! -d ${back_dir} ];then
     mkdir -p ${back_dir}
else
     mv ${back_dir} ${back_dir}.bak
     mkdir -p ${back_dir}
fi
cd ${back_dir}
if [ ! -f "/usr/bin/expect" ];then
    echo "you need install expect."
    yum -y install expect
else
    echo "you have installed expect."
fi
cd ${back_dir}
/usr/bin/expect << EOF
set timeout 100
spawn git clone  仓库地址
expect "Username"
send "***\r"
expect "Password"
send "***\r"
set timeout 100
expect eof
exit
EOF

cd gooal-genomeinput
git checkout ${branch1}
cd src/main/resources
sed -i "s/172.168.1.210/${ip}/g" application-test.yml
sed -i "s/172.168.1.209/${ip}/g" application-test.yml
sed -i 's/9e5ac27b174a/mysql_gene/g' application-test.yml
#cd ../../../
#mvn  clean install -DskipTests=true
#cd target
#netstat -ntlp|grep 8085 | awk '{print $7}' | awk -F '/' '{print $1}' | xargs kill -9 1>/dev/null 2>&1 | exit 0
#nohup java -jar GooalGenomeInput.jar & 1>/dev/null 2>&1 | exit 0
# 前端部署
front_dir="${project_dir}/geneluru_front"
branch2="master"
if [ ! -d ${front_dir} ];then
    mkdir -p ${front_dir}
else
    mv ${front_dir} ${front_dir}.bak
    mkdir -p ${front_dir}
fi
cd ${front_dir}
/usr/bin/expect << EOF
set timeout 100
spawn git clone  仓库地址
expect "Username"
send "***\r"
expect "Password"
send "***\r"
set timeout 100
expect eof
exit
EOF

cd gooal-genomeinput
git checkout ${branch2}
cd Web
unzip index.zip -d ${nginx_dir}/html
cd ${nginx_dir}/html
for i in $(grep -lr '210' static/*)
do
    sed -i 's/210/27/g' $i
done
cd ${nginx_dir}
docker-compose up -d
sleep 15
prog=$(docker ps -a | grep nginx_gooalinput | grep Up | wc -l)
if [ $prog -eq 1 ];then
    echo "nginx_gooalinput is ok."
else
    echo "nginx_gooalinput is unnormal."
    exit -1
fi  

project_dir="/data/gooalgene"
# 安装mysql
mysql_dir="${project_dir}/mysql"
safe_dir="/var/lib/mysql-files"
if [ ! -d ${mysql_dir} ];then
    mkdir -p ${mysql_dir}
else
    mv ${mysql_dir} ${project_dir}/mysql.ba`date "+%Y%m%d"`
    mkdir -p ${mysql_dir}
fi
if [ ! -d ${safe_dir} ];then
    mkdir -p ${safe_dir}
else
    mv ${safe_dir} ${project_dir}/mysql-files.bak`date "+%Y%m%d"`
    mkdir -p ${safe_dir}
fi
cat <<EOF>> ${mysql_dir}/docker-compose.yml
mysql_gene:
  restart: always
  image: mysql:5.7
  container_name: mysql_gene
  volumes:
      - /etc/localtime:/etc/localtime
      - /etc/timezone:/etc/timezone
      - \$PWD/mysql:/var/lib/mysql
      - \$PWD/mysqld.cnf:/etc/mysql/mysql.conf.d/mysqld.cnf
      - ${safe_dir}:/var/lib/mysql-files
  privileged: true
  ports:
    - 33066:3306
  environment:
       MYSQL_ROOT_PASSWORD: ***
EOF
cat <<EOF>> ${mysql_dir}/mysqld.cnf
[mysqld]
pid-file    = /var/run/mysqld/mysqld.pid
socket      = /var/run/mysqld/mysqld.sock
datadir     = /var/lib/mysql
#log-error  = /var/log/mysql/error.log
# By default we only accept connections from localhost
#bind-address   = 127.0.0.1
# Disabling symbolic-links is recommended to prevent assorted security risks
#支持符号链接，就是可以通过软连接的方式，管理其他目录的数据库，最好不要开启，当一个磁盘或分区空间不够时，可以开启该参数将数据存储到其他的磁盘或分区。
#http://blog.csdn.net/moxiaomomo/article/details/17092871
symbolic-links=0
EOF
cd ${mysql_dir}
docker-compose up -d
# 保证mysql初始化完成,要不然下面无法进行数据库的创建
sleep 15

docker exec mysql_gene mysql -uroot -pgooalgene@123 -e "create database genomedb;show databases;"
prob=$(docker ps -a | grep mysql_gene | grep Up | wc -l)
if [ $prob -eq 1 ];then
    echo "mysql_gene is ok."
else
    echo "mysql_gene is unnormal."
    exit  -1
fi
# 启动后端
cd ${back_dir}/gooal-genomeinput
mvn  clean install -DskipTests=true
cd target
netstat -ntlp|grep 8085 | awk '{print $7}' | awk -F '/' '{print $1}' | xargs kill -9 1>/dev/null 2>&1 | exit 0
nohup java -jar GooalGenomeInput.jar & 1>/dev/null 2>&1 | exit 0

# 安装redis
redis_dir="${project_dir}/redis"
if [ -d ${redis_dir} ];then
    mv ${project_dir}/redis ${project_dir}/redis.bak`date "+%Y%m%d"`
    mkdir -p ${project_dir}/redis
else
    mkdir -p ${project_dir}/redis
fi
cat <<EOF>> ${redis_dir}/docker-compose.yml
redis_gene:
  restart: always
  image: redis:4.0
  container_name: redis_gene
  volumes:
      - /etc/localtime:/etc/localtime
      - /etc/timezone:/etc/timezone
      - \$PWD/redis:/data
      - \$PWD/redis.conf:/usr/local/etc/redis/redis.conf
  privileged: true
  ports:
      - 6389:6379
  command: redis-server /usr/local/etc/redis/redis.conf
EOF
cat <<EOF>> ${redis_dir}/redis.conf
# bind 127.0.0.1 
#daemonize yes //禁止redis后台运行
port 6379
pidfile /var/run/redis.pid 
appendonly yes
protected-mode no
requirepass ***
EOF
cd ${redis_dir}
docker-compose up -d
sleep 15
proc=$(docker ps -a | grep redis_gene | grep Up | wc -l)
if [ $prob -eq 1 ];then
    echo "redis_gene is ok."
    echo "${ip} 的数据导入系统已经部署完成,可以开始导入数据" | mail -s "数据导入系统" wangteng@gooalgene.com
else
    echo "redis_gene is unnormal."
    exit  -1
fi
prot=$(grep -h '初始化成功' ${back_dir}/gooal-genomeinput/target/nohup.out | wc -l)
if [ ${prot} -eq 1 ];then
    echo "初始化成功，清空nohup.out"
    cp /dev/null ${back_dir}/gooal-genomeinput/target/nohup.out
else
    exit -1
fi
sleep 900
# 数据录入
#proa=$(cat  ${back_dir}/gooal-genomeinput/target/nohup.out  | grep error | wc -l)
proe=$(ps -ef | grep LOAD | grep -v grep | wc -l)
#case ${proa} in
#0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9)
#while :
#do
#    echo "正在导入数据" >/dev/null
#done
#;;
#10)
if [ ${proe} -eq 0  ];then
    echo "mysql数据已经导入完成,部署物种即将开始" | mail -s "数据导入系统" wangteng@gooalgene.com
else 
    echo "is importing data..."
    sleep 300
    if [ ${proe} -eq 0  ];then
        echo "mysql数据已经导入完成,部署物种即将开始" | mail -s "数据导入系统" wangteng@gooalgene.com
    else
        echo "you need more time for importing data."
        exit -1
    fi
fi
#;;
#*)
#;;
#esac

          
# 部署物种genome
# 配置物种目录
#project_dir="/data/gooalgene"
#ip=$(ip addr  | grep inet | grep brd | grep en | awk '{print $2}' | awk -F '/' '{print $1}')
mkdir -p ${project_dir}/download
specie_dir="${project_dir}/dbs/genome"
if [ -d ${specie_dir} ];then
    mv ${project_dir}/dbs/genome ${project_dir}/dbs/genome.bak`date "+%Y%m%d"`
    mkdir -p ${project_dir}/dbs/genome
else
    mkdir -p ${project_dir}/dbs/genome
fi
cd ${specie_dir}
mkdir -p nginx/conf
mkdir -p tomcat
# 部署物种nginx
cat <<EOF>> nginx/docker-compose.yml
genome_nginx:
   restart: always
   image: nginx
   container_name: genome_nginx
   volumes:
       - \$PWD/conf/nginx.conf:/etc/nginx/nginx.conf
       - \$PWD/conf/nginx_reverse.conf:/etc/nginx/conf.d/default.conf
       - /etc/localtime:/etc/timezone
       - /etc/timezone:/etc/timezone
       - ./html:/usr/share/nginx/html
       - ${project_dir}/download:/usr/share/nginx/html/download
   privileged: true
   ports:
       - 94:80
EOF
cat <<EOF>> nginx/conf/nginx.conf
user  root;  
worker_processes  1;
error_log  /var/log/nginx/error.log warn;  
pid        /var/run/nginx.pid;
events {  
    worker_connections  1024;
}
http {  
    include       /etc/nginx/mime.types;
        server_tokens off;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  3000;
    gzip  on;
    gzip_min_length  1k;
    gzip_buffers     4 16k;
    gzip_http_version 1.1;
    gzip_comp_level 2;
    #  下面是一整段
    gzip_types text/plain image/png  application/javascript application/x-javascript  text/javascript text/css application/xml image/x-icon application/xml+rss 
    application/json; 
    gzip_vary on;
    gzip_proxied   expired no-cache no-store private auth;
    gzip_disable   "MSIE [1-6]\.";
    include /etc/nginx/conf.d/*.conf;
}
EOF
cat <<EOF>> nginx/conf/nginx_reverse.conf
server {
    listen  80;
    location / {
              root /usr/share/nginx/html;
              index index.html;
              try_files \$uri \$uri/ @router;
} 
    location /images {
              root /usr/share/nginx/html;
              index index.html;
              autoindex on;
              autoindex_exact_size off;
              autoindex_localtime on;
              try_files \$uri \$uri/ @router1;
    } 
    location /download {
              root /usr/share/nginx/html;
              index index.html;
              autoindex on;
              autoindex_exact_size off;
              autoindex_localtime on;
              try_files \$uri \$uri/ @router2;
    }  
    location /api  {
                  proxy_pass http://${ip}:8082/;
}
location @router {
               rewrite ^.*\$ /index.html last;
}
location @router1 {
               rewrite ^.*\$ /index.html last;
}
location @router2 {
               rewrite ^.*\$ /index.html last;
}
}
EOF
# 部署物种tomcat
cat <<EOF>> tomcat/docker-compose.yml
genome_tomcat:
   restart: always
   image: tomcat
   container_name: genome_tomcat
   volumes:
        - /etc/localtime:/etc/timezone
        - /etc/timezone:/etc/timezone
        - ./end:/usr/local/tomcat/webapps/
        - ${project_dir}/download/zip:/data/www/html/files/genome/zip/
   privileged: true
   ports:
       - 8082:8080
EOF

# 物种后端部署
specieback_dir="${project_dir}/specieback_end"
branch3="dev"
if [ ! -d ${specieback_dir} ];then
     mkdir -p ${specieback_dir}
else
     mv ${specieback_dir} ${specieback_dir}.bak
     mkdir -p ${specieback_dir}
fi
cd ${specieback_dir}
/usr/bin/expect << EOF
set timeout 100
spawn git clone 仓库地址
expect "Username"
send "***\r"
expect "Password"
send "***\r"
set timeout 100
expect eof
exit
EOF

cd Genome-Backstage
git checkout ${branch3}
cd src/main/resources/test
sed -i "s/172.168.1.210/${ip}/g" qtldb.properties 
cd ../../../../
mvn clean install -P test -DskipTests=true
mkdir -p ${project_dir}/dbs/genome/tomcat/end
mv target/genome.war ${project_dir}/dbs/genome/tomcat/end
cd ${project_dir}/dbs/genome/tomcat
docker-compose up -d


# 物种前端部署
speciefront_dir="${project_dir}/specie_front"
branch4="letterDataEntry_test"
if [ ! -d ${speciefront_dir} ];then
    mkdir -p ${speciefront_dir}
else
    mv ${speciefront_dir} ${speciefront_dir}.bak
    mkdir -p ${speciefront_dir}
fi
cd ${speciefront_dir}
/usr/bin/expect << EOF
set timeout 100
spawn git clone  仓库地址
expect "Username"
send "***\r"
expect "Password"
send "***\r"
set timeout 100
expect eof
exit
EOF

cd genome_database
git checkout ${branch4}
cd Web
unzip index.zip -d ${specie_dir}/nginx/html
cd  ${specie_dir}/nginx/html
for p in $(grep -lr '210' static/*)
do
    sed -i 's/210/27/g' $p
done
cd ${specie_dir}/nginx
docker-compose up -d

