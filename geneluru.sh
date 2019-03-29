#!/bin/bash
 
echo -n "enter the args: ip 数据导入时间 邮箱 物种名 mysql库名 mysqlroot密码 redis密码 系统root密码 物种前端仓库分支 物种后端仓库分支->"
read ip import_time mail  specie dbname mysql_password  redis_password root_password  frontbranch endbranch
 
# 防火墙配置
setenforce 0
sed -i 's/enforcing/disabled/g' /etc/selinux/config
sed -i 's/enforcing/disabled/g' /etc/sysconfig/selinux
systemctl stop firewalld
  
# 邮件服务部署
installmail() {
yum install -y sendmail
yum install -y sendmail-cf
yum -y install mailx
yum -y install saslauthd
systemctl start saslauthd
  
# 配置sendmail
cp /dev/null /etc/mail.rc
sed -i '/TRUST_AUTH_MECH/s/dnl //g' /etc/mail/sendmail.mc
sed -i '/confAUTH_MECHANISMS/s/dnl //g' /etc/mail/sendmail.mc
sed -i  /^DAEMON_OPTIONS/s/127.0.0.1/0.0.0.0/g /etc/mail/sendmail.mc
m4 /etc/mail/sendmail.mc > /etc/mail/sendmail.cf
cat <<EOF>> /etc/mail.rc
set from=wt439757183@126.com
set smtp=smtp.126.com
set smtp-auth-user=wt439757183@126.com
set smtp-auth-password=***
set smtp-auth=login
EOF
}
installmail
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
yum -y install lrzsz && yum -y install openssh-clients && yum -y install rsync && yum -y install git && yum -y install unzip
  
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
wget https://archive.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz
# wget http://apache.fayea.com/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz
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
 
mvn
if [ $? -eq 127 ];then
    yum -y install java-1.8.0-openjdk-devel
fi
echo "source /etc/profile" >> /root/.bashrc
###数据导入系统部署###
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
       - /data/gooalgene/dbs/Gooal-${specie}input/html/images:/usr/share/nginx/html/images
  #     - /data/gooalgene/dbs/Gooal-genomeinput/html/images:/usr/share/nginx/html/images/images
  #     - /data/gooalgene/dbs/Gooal-genomeinput/html/download:/usr/share/nginx/html/images/download
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
  
  
# 数据导入系统后端部署
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
spawn git clone  后端仓库
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
sed -i  "s/imageSqlPath: \//imageSqlPath: \/images\//g" application-test.yml
sed -i "s/genomedb/${dbname}/g" application-test.yml
sed -i "s/genome/${specie}/g" application-test.yml
# sed -i "s/WM82_v2.0:Glyma-Williams 82(PI518671),ZH13_v1.0:SoyZH13-Zhonghuang13(ZDD23876),SN14_v1.0:GmSN14-Suinong14(ZDD22648)/${dynamic_name}/g" application-test.yml
sed -i "83s/${specie}/genome/g" application-test.yml
sed -i "10s/Gooal&123/${redis_password}/g" application-test.yml
sed -i "30s/gooalgene@123/${mysql_password}/g" application-test.yml
sed -i "40s/gooalgene/${root_password}/g" application-test.yml
# 数据导入系统前端部署
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
spawn git clone  前端仓库
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
    sed -i "s/172.168.1.210/${ip}/g" $i
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
       MYSQL_ROOT_PASSWORD: ${mysql_password}
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
  
docker exec mysql_gene mysql -uroot -p${mysql_password} -e "create database ${dbname};show databases;"
prob=$(docker ps -a | grep mysql_gene | grep Up | wc -l)
if [ $prob -eq 1 ];then
    echo "mysql_gene is ok."
else
    echo "mysql_gene is unnormal."
    exit  -1
fi
  
  
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
requirepass ${redis_password}
EOF
cd ${redis_dir}
docker-compose up -d
sleep 15
  
# 启动后端
cd ${back_dir}/gooal-genomeinput
/data/gooalgene/java/maven3.5/bin/mvn  clean install -DskipTests=true
cd target
netstat -ntlp|grep 8085 | awk '{print $7}' | awk -F '/' '{print $1}' | xargs kill -9 1>/dev/null 2>&1 | exit 0
nohup java -jar GooalGenomeInput.jar & 1>/dev/null 2>&1 | exit 0
sleep 20
  
proc=$(docker ps -a | grep redis_gene | grep Up | wc -l)
if [ $proc -eq 1 ];then
    echo "redis_gene is ok."
    echo "${ip} 的数据导入系统已经部署完成,可以开始导入数据" | mail -s "数据导入系统" ${mail}
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
sleep ${import_time}
# 数据录入
proe=$(ps -ef | grep LOAD | grep -v grep | wc -l)
if [ ${proe} -eq 0  ];then
    echo "${ip}的mysql数据已经导入完成,部署物种即将开始" | mail -s "数据导入系统" ${mail}
else
    echo "is importing data..."
    sleep 300
    if [ ${proe} -eq 0  ];then
        echo "${ip}的mysql数据已经导入完成,部署物种即将开始" | mail -s "数据导入系统" ${mail}
    else
        echo "you need more time for importing data."
        exit -1
    fi
fi
            
# 物种系统部署
# 配置物种目录
#project_dir="/data/gooalgene"
#ip=$(ip addr  | grep inet | grep brd | grep en | awk '{print $2}' | awk -F '/' '{print $1}')
mkdir -p ${project_dir}/download
specie_dir="${project_dir}/dbs/${specie}"
if [ -d ${specie_dir} ];then
    mv ${project_dir}/dbs/${specie} ${project_dir}/dbs/${specie}.bak`date "+%Y%m%d"`
    mkdir -p ${project_dir}/dbs/${specie}
else
    mkdir -p ${project_dir}/dbs/${specie}
fi
cd ${specie_dir}
mkdir -p nginx/conf
mkdir -p tomcat
# 部署物种nginx
cat <<EOF>> nginx/docker-compose.yml
${specie}_nginx:
   restart: always
   image: nginx
   container_name: ${specie}_nginx
   volumes:
       - \$PWD/conf/nginx.conf:/etc/nginx/nginx.conf
       - \$PWD/conf/nginx_reverse.conf:/etc/nginx/conf.d/default.conf
       - /etc/localtime:/etc/timezone
       - /etc/timezone:/etc/timezone
       - ./html:/usr/share/nginx/html
       - ${project_dir}/download:/usr/share/nginx/html/download
       - /data/gooalgene/dbs/Gooal-${specie}input/html/images:/usr/share/nginx/html/images
   privileged: true
   ports:
       - 94:80
EOF
  
mkdir -p ${project_dir}/download/${specie}
  
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
${specie}_tomcat:
   restart: always
   image: tomcat
   container_name: ${specie}_tomcat
   volumes:
        - /etc/localtime:/etc/timezone
        - /etc/timezone:/etc/timezone
        - ./end:/usr/local/tomcat/webapps/
        - ${project_dir}/download/zip:/data/www/html/files/${specie}/zip/
   privileged: true
   ports:
       - 8082:8080
EOF
  
# 物种后端部署
specieback_dir="${project_dir}/specieback_end"
# branch3="dev"
if [ ! -d ${specieback_dir} ];then
     mkdir -p ${specieback_dir}
else
     mv ${specieback_dir} ${specieback_dir}.bak
     mkdir -p ${specieback_dir}
fi
cd ${specieback_dir}
/usr/bin/expect << EOF
set timeout 100
spawn git clone 后端仓库2
expect "Username"
send "***\r"
expect "Password"
send "***\r"
set timeout 100
expect eof
exit
EOF
  
cd Genome-Backstage
git checkout ${endbranch}
# cd src/main/resources/test
yum -y install mlocate
locate qtldb.properties
if [ $? -ne 0 ];then
    updatedb
fi
colum=$(locate qtldb.properties | grep Genome-Backstage | grep test | wc -l)
if [ $colum -eq 0 ];then
updatedb
fi
pos=$(locate qtldb.properties | grep Genome-Backstage | grep test)
dir=$(dirname $pos)
cd ${dir}
 
sed -i "s/172.168.1.210/${ip}/g" qtldb.properties
sed -i "s/172.168.1.209/${ip}/g" qtldb.properties
#sed -i "s/genomedb/${dbname}/g"  qtldb.properties
#sed  -i "s/genome/${specie}/g"  qtldb.properties
sed -i "12s/gooalgene@123/${mysql_password}/g" qtldb.properties
sed -i "s/33065/33066/g" qtldb.properties
sed -i "s/33068/33066/g" qtldb.properties
 
cd -
/data/gooalgene/java/maven3.5/bin/mvn clean install -P test  -DskipTests=true
mkdir -p ${project_dir}/dbs/${specie}/tomcat/end
mv target/${specie}.war ${project_dir}/dbs/${specie}/tomcat/end
cd ${project_dir}/dbs/${specie}/tomcat
docker-compose up -d
  
  
# 物种前端部署
speciefront_dir="${project_dir}/specie_front"
#branch4="letterDataEntry_test"
if [ ! -d ${speciefront_dir} ];then
    mkdir -p ${speciefront_dir}
else
    mv ${speciefront_dir} ${speciefront_dir}.bak
    mkdir -p ${speciefront_dir}
fi
cd ${speciefront_dir}
/usr/bin/expect << EOF
set timeout 100
spawn git clone  前端2
expect "Username"
send "***\r"
expect "Password"
send "***\r"
set timeout 200
expect eof
exit
EOF
  
cd genome_database
git checkout ${frontbranch}
cd Web
unzip index.zip -d ${specie_dir}/nginx/html
cd  ${specie_dir}/nginx/html
for p in $(grep -lr '210' static/*)
do
    sed -i "s/172.168.1.210/${ip}/g" $p
done
#for m in $(grep -lr 'genome' static/*)
#do
#sed -i "s/genome/${specie}/g" $m
#done
 
cd ${specie_dir}/nginx
docker-compose up -d
