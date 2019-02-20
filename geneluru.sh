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
mv apache-maven-3.5.4 maven3.5
cat <<EOF>> /etc/profile
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.191.b12-1.el7_6.x86_64/jre MAVEN_HOME=/data/gooalgene/java/maven3.5
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
    yum -y install expect
fi

/usr/bin/expect << EOF
set timeout 100
spawn git clone  http://git.soyomics.com:9000/xiangzz/gooal-genomeinput.git
expect "Username"
send "username\r"
expect "Password"
send "password\r"
set timeout 100
expect eof
exit
EOF

cd gooal-genomeinput
git checkout ${branch1}
mvn  clean install -DskipTests=true
cd target
netstat -ntlp|grep 8085 | awk '{print $7}' | awk -F '/' '{print $1}' | xargs kill -9 1>/dev/null 2>&1 | exit 0
nohup java -jar GooalGenomeInput.jar & 1>/dev/null 2>&1 | exit 0
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
spawn git clone  http://git.soyomics.com:9000/chengj/gooal-genomeinput.git
expect "Username"
send "username\r"
expect "Password"
send "password\r"
set timeout 100
expect eof
exit
EOF

cd gooal-genomeinput
git checkout ${branch2}
cd Web
unzip index.zip -d ${nginx_dir}/html
cd ${nginx_dir}
docker-compose up -d
sleep 15
prog=$(docker ps -a | grep nginx_gooalinput | grep Up)
if [ $prog -eq 1 ];then
    echo "nginx_gooalinput is ok."
else
    echo "nginx_gooalinput is unnormal."
    exit -1
fi  

:<<!
# 安装mysql
mysql_dir="${project_dir}/gooalgene/mysql"
if [ ! -d ${mysql_dir} ];then
    mkdir -p ${mysql_dir}
else
    mv ${mysql_dir} ${project_dir}/gooalgene/mysql.bak
    mkdir -p ${mysql_dir}
fi
cat <<EOF>> ${mysql_dir}/docker-compose.yml
mysql_${species_name}:
  restart: always
  image: mysql:5.7
  container_name: mysql_${species_name}
  volumes:
      - /etc/localtime:/etc/localtime
      - /etc/timezone:/etc/timezone
      - \$PWD/mysql:/var/lib/mysql
      - \$PWD/mysqld.cnf:/etc/mysql/mysql.conf.d/mysqld.cnf
  privileged: true
  ports:
    - 33066:3306
  environment:
       MYSQL_ROOT_PASSWORD: ${mysqlroot_password}
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
docker exec mysql_${species_name} mysql -uroot -p${mysqlroot_password} -e "create database ${mysql_db};show databases;"
# 安装mongodb
mongo_dir="${project_dir}/gooalgene/mongodb"
if [ -d ${mongo_dir} ];then
    mv ${project_dir}/gooalgene/mongodb ${project_dir}/gooalgene/mongodb.bak
    mkdir -p ${project_dir}/gooalgene/mongodb
else
    mkdir -p ${project_dir}/gooalgene/mongodb
fi
cat <<EOF>> ${mongo_dir}/Dockerfile
FROM centos:centos7
MAINTAINER linuxwt <tengwanginit@gmail.com>
 
RUN yum -y update
 
RUN  echo '[mongodb-org-3.6]' > /etc/yum.repos.d/mongodb-org-3.6.repo
RUN  echo 'name=MongoDB Repository' >> /etc/yum.repos.d/mongodb-org-3.6.repo
RUN  echo 'baseurl=http://repo.mongodb.org/yum/redhat/7/mongodb-org/3.6/x86_64/' >> /etc/yum.repos.d/mongodb-org-3.6.repo
RUN  echo 'enabled=1' >> /etc/yum.repos.d/mongodb-org-3.6.repo
RUN  echo 'gpgcheck=0' >> /etc/yum.repos.d/mongodb-org-3.6.repo
 
RUN yum -y install make
RUN yum -y install mongodb-org
RUN mkdir -p /data/db
 
EXPOSE 27017
ENTRYPOINT ["/usr/bin/mongod"]
EOF
cd ${mongo_dir}
docker build -t centos7/mongo:3.6 .
cat <<EOF>> ${mongo_dir}/docker-compose.yml
mongo_${species_name}:
  restart: always
  image: centos7/mongo:3.6
  container_name: mongo_${species_name}
  volumes:
    - /etc/localtime:/etc/localtime
    - /etc/timezone:/etc/timezone
    - \$PWD/mongo:/data/db
    - \$PWD/enabled:/sys/kernel/mm/transparent_hugepage/enabled
    - \$PWD/defrag:/sys/kernel/mm/transparent_hugepage/defrag
  ulimits:
    nofile:
      soft: 300000
      hard: 300000
  ports:
      - "27117:27017"
  command: --bind_ip_all --port 27017 --oplogSize 204800 --profile=1 --slowms=500
EOF
echo "always madvise [never]" > ${mongo_dir}/defrag
echo "always madvise [never]" > ${mongo_dir}/enabled
docker-compose up -d
sleep 10
docker exec mongo_${species_name} mongo admin --eval "db.createUser({user:\"${mongoadmin_user}\", pwd:\"${mongoadmin_password}\", roles:[{role:\"root\", db:\"admin\"},{role:\"clusterAdmin\",db:\"admin\"}]})"
docker-compose down
sed -i '/command.*/s//& --auth/g' /home/data/gooalgene/mongodb/docker-compose.yml
docker-compose up -d
sleep 10
# 安装redis
redis_dir="${project_dir}/gooalgene/redis"
if [ -d ${redis_dir} ];then
    mv ${project_dir}/gooalgene/redis ${project_dir}/gooalgene/redis.bak
    mkdir -p ${project_dir}/gooalgene/redis
else
    mkdir -p ${project_dir}/gooalgene/redis
fi
cat <<EOF>> ${redis_dir}/docker-compose.yml
redis_${species_name}:
  restart: always
  image: redis:4.0
  container_name: redis_${species_name}
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
bind 127.0.0.1 
#daemonize yes //禁止redis后台运行
port 6379
pidfile /var/run/redis.pid 
appendonly yes
protected-mode no
requirepass ${redis_password}
EOF
cd ${redis_dir}
docker-compose up -d
!
