#!/bin/bash

# jdk maven部署
# 安装配置maven和openjdk
java -version
if [ $? -eq 127 ];then
  yum -y install java-1.8.0-openjdk
fi

project_dir="/data/gooalgene"

if [ ! -d ${project_dir} ];then
     mkdir -p ${project_dir}
else
     mv ${project_dir} ${project_dir}.bal`date "+%Y%m%d"`
     mkdir -p ${project_dir}
fi

java_dir="${project_dir}/java"

if [ ! -d ${java_dir} ];then
    mkdir -p ${java_dir}
else
    mv ${java_dir} ${java_dir}.bak
    mkdir -p ${java_dir}
fi

mvn 
 
if [ $? -eq 127 ];then
cd ${java_dir}
wget  http://apache.fayea.com/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz
tar zvxf apache-maven-3.5.4-bin.tar.gz
mv apache-maven-3.5.4 maven3.5
cat <<EOF>> /etc/profile
export JAVA_HOME=/usr/lib/jvm/java-openjdk MAVEN_HOME=\${java_dir}/maven3.5
export CLASSPATH=.:\$JAVA_HOME/jre/lib/rt.jar:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar
export PATH=\$JAVA_HOME/bin:\$MAVEN_HOME/bin:$PATH
EOF
fi

# 安装nginx
# project_dir="/data/gooalgene"
nginx_dir="${project_dir}/dbs/nginx"
if [ ! -d ${nginx_dir} ];then
    mkdir -p ${nginx_dir}
else
    mv ${nginx_dir} ${nginx_dir}.bak
    mkdir -p ${nginx_dir}
fi

mkdir -p ${nginx_dir}/conf
cd ${nginx_dir}

cat <<EOF>> ${project_dir}/dbs/nginx/docker-compose.yml
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
cat <<EOF>> ${project_dir}/dbs/nginx/conf/nginx.conf
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
cat <<EOF>>  ${project_dir}/dbs/nginx/conf/nginx_reverse.conf
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
                  proxy_pass http://172.168.1.111:8085/;
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
back_dir="${project_dir}/end"
branch1="master"
if [ ! -d ${back_dir} ];then
     mkdir -p ${back_dir}
else
     mv ${back_dir} ${back_dir}.bak
     mkdir -p ${back_dir}
fi
cd ${back_dir}
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
front_dir="${project_dir}/front"
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

