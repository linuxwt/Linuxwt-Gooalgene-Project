#!/bin/bash

# 更换yum源
yum -y install wget
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
wget http://mirrors.163.com/.help/CentOS7-Base-163.repo
mv CentOS7-Base-163.repo /etc/yum.repos.d/CentOS-Base.repo
yum clean all && yum makecache && yum -y update

# 安装docker18.03
installdocker1()
{
        yum -y install yum-utils device-mapper-persistent-data lvm2
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum-config-manager --enable docker-ce-edge
        yum-config-manager --enable docker-ce-test
        yum -y install docker-ce
}
installdocker2()
{
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager  --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum makecache fast
yum -y install docker-ce
}
docker version
if [ $? -eq 127 -o $? -eq 1 ];then
        echo "we can install docker-ce"
        sleep 5
        installdocker1
        if [ $? -ne 0 ];then
            echo "you should use aliyun image."
            installdocker2
        fi
        docker version
        if [ $? -lt 127 ];then
                echo "the installation of docker-ce is ok."
                rpm -qa | grep docker | xargs rpm -e --nodeps 
                yum -y install docker-ce-18.03*
        else
                echo "the installation of docker-ce failed ,please reinstall"
                exit -1
        fi
else
        echo "docker have installed，pleae uninstall old version"
        sleep 5
        rpm -qa | grep docker | xargs rpm -e --nodeps
        docker version
        if [ $? -eq 127 ];then
                echo "old docker have been uninstalled and you can install docker-ce"
                sleep 5
                installdocker1
                if [ $? -ne 0 ];then
                    echo "you should use aliyun image."
                    installdocker2
                fi
                docker version
                if [ $? -lt 127 ];then
                        echo "the installation of docker-ce is ok."
                        rpm -qa | grep docker | xargs rpm -e --nodeps
                        yum -y install docker-ce-18.03*
                else
                        echo "the installation of docker-ce failed anad please reinstall."
                        exit -1
                fi
        else
                echo "the old docker uninstalled conpletely and please uninstall again."
                exit -1
        fi
fi

systemctl start docker
sleep 10
docker_version=$(docker version | grep "Version" | awk '{print $2}' | head -n 2 | sed -n '2p')
if [ $? -eq 0 ];then
        echo "docker start successfully and the version is ${docker_version}"
        sleep 10
fi

# 安装docker-compose
yum -y install epel-release  && yum -y install python-pip  && pip install docker-compose  && pip install --upgrade pip 
docker-compose_version=$(docker-compose version | grep 'docker-compose' | awk '{print $3}')
if [ $? -eq 0 ];then
        echo "the docker-compose version is ${docker-compose_version}"
        sleep 10
fi

# 配置docker加速拉取
echo {\"registry-mirrors\":[\"https://nr630v1c.mirror.aliyuncs.com\"]} > /etc/docker/daemon.json

# 安装常用工具
yum -y install lrzsz && yum -y install openssh-clients && yum -y install telnet && yum -y install rsync

# # 防火墙配置
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

project_dir="/data/gooalgene"
if [ ! -d ${project_dir} ];then
     mkdir -p ${project_dir}
else
     mv ${project_dir} ${project_dir}.bak`date "+%Y%m%d"`
     mkdir -p ${project_dir}
fi

# 更改docker存储位置
systemctl stop docker
sleep 10
cp -r /var/lib/docker ${project_dir}
rm -Rf /var/lib/docker
ln -s ${project_dir}/docker /var/lib/docker
systemctl start docker 
sleep 10
systemctl enable docker
systemctl daemon-reload

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
send "wangteng\r"
expect "Password"
send "wangteng456\r"
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
send "wangteng\r"
expect "Password"
send "wangteng456\r"
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
