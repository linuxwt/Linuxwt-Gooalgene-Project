#!/bin/bash

project_dir="$1"
species_name="$2"
# 更换yum源并安装docker、docker-compose
yum -y install wget
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
wget http://mirrors.163.com/.help/CentOS7-Base-163.repo
mv CentOS7-Base-163.repo /etc/yum.repos.d/CentOS-Base.repo
yum clean all && yum makecache && yum -y update
# 安装docker18.03与docker-compose  
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
if [ $? -eq 127 ];then
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
systemctl start docker && systemctl enable docker && systemctl daemon-reload 
docker_version=$(docker version | grep "Version" | awk '{print $2}' | head -n 2 | sed -n '2p')
if [ $? -eq 0 ];then
        echo "docker start successfully and the version is ${docker_version}"
fi
# 安装docker-compose并检查版本
yum -y install epel-release  && yum -y install python-pip  && pip install docker-compose  && pip install --upgrade pip 
docker-compose_version=$(docker-compose version | grep 'docker-compose' | awk '{print $3}')
if [ $? -eq 0 ];then
        echo "the docker-compose version is ${docker-compose_version}"
fi
# 配置docker加速拉取
echo {\"registry-mirrors\":[\"https://nr630v1c.mirror.aliyuncs.com\"]} > /etc/docker/daemon.json

# 安装常用工具
yum -y install lrzsz && yum -y install openssh-clients && yum -y install telnet && yum -y install rsync 

# 防火墙配置
setenforce 0
sed -i 's/enforcing/disabled/g' /etc/selinux/config
sed -i 's/enforcing/disabled/g' /etc/sysconfig/selinux
systemctl stop firewalld
systemctl disable firewalld
systemctl daemon-reload

# 更改docker存储位置
cp -r /var/lib/docker ${project_dir}
rm -Rf /var/lib/docker
ln -s ${project_dir}/docker /var/lib/docker
systemctl restart docker

sleep 5
echo "yum and docker are ok!!!"
sleep 5

# 安装jdk、maven
tomcat_dir="${project_dir}/gooalgene/java"
if [ ! -d ${tomcat_dir} ];then
    mkdir -p ${tomcat_dir}
else
    mv ${tomcat_dir} ${tomcat_dir}.bak
    mkdir -p ${tomcat_dir}
fi

prog=$(rpm -qa|grep java | wc -l)
if [ ${prog} -gt 0 ];then
    echo "the system have java,next we uninstall it and install new."
    sleep 5
    rpm -qa|grep java | xargs rpm -e --nodeps 
else
    echo "you need installed java"
fi
cd ${tomcat_dir}

wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u192-b12/750e1c8617c5452694857ad95c3ee230/jdk-8u192-linux-x64.tar.gz
tar zvxf jdk-8u192-linux-x64.tar.gz
mv jdk1.8.0_192 jdk1.8
wget  http://apache.fayea.com/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz
tar zvxf apache-maven-3.5.4-bin.tar.gz
mv apache-maven-3.5.4 maven3.5
# 加入环境变量
cp /etc/profile /etc/profile.bak
cat <<EOF>> /etc/profile
export JAVA_HOME=${project_dir}/gooalgene/java/jdk1.8 MAVEN_HOME=${project_dir}/gooalgene/java/maven3.5
export CLASSPATH=.:\$JAVA_HOME/jre/lib/rt.jar:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar
export PATH=\$JAVA_HOME/bin:\$MAVEN_HOME/bin:\$PATH 
EOF
sleep 3
echo "jdk and maven are ok!!!"
sleep 3
# 安装mysql、mongodb客户端
wget https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-community-common-5.7.24-1.el7.x86_64.rpm 
wget https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-community-libs-5.7.24-1.el7.x86_64.rpm
wget https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-community-libs-compat-5.7.24-1.el7.x86_64.rpm
wget https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-community-client-5.7.24-1.el7.x86_64.rpm
mariadb_num=$(rpm -qa|grep mariadb | wc -l)
if [ ${mariadb_num} -eq 0 ];then
    echo "you can install mysql."
else
    rpm -qa | grep mariadb | xargs rpm -e --nodeps
fi
rpm -ivh  mysql-community-common-5.7.24-1.el7.x86_64.rpm
rpm -ivh  mysql-community-libs-5.7.24-1.el7.x86_64.rpm
rpm -ivh  mysql-community-libs-compat-5.7.24-1.el7.x86_64.rpm
rpm -ivh  mysql-community-client-5.7.24-1.el7.x86_64.rpm
wget http://downloads.mongodb.org/linux/mongodb-linux-x86_64-rhel70-3.6.6.tgz  
tar vxf mongodb-linux-x86_64-rhel70-3.6.6.tgz  
mv mongodb-linux-x86_64-rhel70-3.6.6 /usr/local/mongodb
cat <<EOF>> /etc/profile
export MONGODB_HOME=/usr/local/mongodb 
export PATH=\$MONGODB_HOME/bin:\$PATH 
EOF
sleep 3
echo "mysql and mongodb client are ok!!!"
sleep 3

# 安装nginx和tomcat
species_dir="${project_dir}/gooalgene/${species_name}"
if [ ! -d ${species_dir} ];then
    mkdir -p ${species_dir}
else
    mv ${species_dir} ${species_dir}.bak
    mkdir -p ${species_dir}
fi
mkdir -p ${project_dir}/gooalgene/${species_name}/conf

cat <<EOF>> ${species_dir}/docker-compose.yml
nginx_${species_name}:
   restart: always
   image: nginx
   container_name: nginx_${species_name}
   volumes:
       - \$PWD/conf/nginx.conf:/etc/nginx/nginx.conf
       - \$PWD/conf/nginx_reverse.conf:/etc/nginx/conf.d/default.conf
       - /etc/localtime:/etc/timezone
       - /etc/timezone:/etc/timezone
       - ${project_dir}/download:/www/html
   links:
       - tomcat_${species_name}
   privileged: true
   ports:
       - 180:80
       - 80:90
tomcat_${species_name}:
   restart: always
   image: tomcat
   container_name: tomcat_${species_name}
   volumes:
       - \$PWD/conf/server.xml:/usr/local/tomcat/conf/server.xml
  #    - ./conf/web.xml:/usr/local/tomcat/conf/web.xml
  #    - ./conf/catalina.sh:/usr/local/tomcat/bin/catalina.sh
  #    - ./soybean/soybean-dna:/usr/local/tomcat/webapps/soybean-dna
       - /etc/localtime:/etc/localtime
       - /etc/timezone:/etc/timezone
   expose:
       - 8080
EOF

cat <<EOF>> ${species_dir}/conf/nginx.conf
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

cat <<EOF>> ${species_dir}/conf/nginx_reverse.conf
upstream tomcat_${species_name} {
    server tomcat_${species_name}:8080;
    }

server {
    listen  80;
    location / {
        root /www/html;
        index index.html;
        try_files $uri \$uri/ /index.html;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
}

map \$http_upgrade \$connection_upgrade {
        default upgrade;
        ''      close;
    }

server {
    listen  90;
    location / {
        proxy_set_header Access-Control-Allow-Origin *;
        proxy_pass_header Server;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Scheme \$scheme;
        proxy_pass http://tomcat_${species_name};
        client_max_body_size 0;
        proxy_connect_timeout 420;
        proxy_send_timeout 420;
        proxy_read_timeout 420;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
}
EOF

cat <<EOF>> ${species_dir}/conf/server.xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  Licensed to the Apache Software Foundation (ASF) under one or more
  contributor license agreements.  See the NOTICE file distributed with
  this work for additional information regarding copyright ownership.
  The ASF licenses this file to You under the Apache License, Version 2.0
  (the "License"); you may not use this file except in compliance with
  the License.  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-->
<!-- Note:  A "Server" is not itself a "Container", so you may not
     define subcomponents such as "Valves" at this level.
     Documentation at /docs/config/server.html
 -->
<Server port="8005" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <!-- Security listener. Documentation at /docs/config/listeners.html
  <Listener className="org.apache.catalina.security.SecurityListener" />
  -->
  <!--APR library loader. Documentation at /docs/apr.html -->
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <!-- Prevent memory leaks due to use of particular java/javax APIs-->
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

  <!-- Global JNDI resources
       Documentation at /docs/jndi-resources-howto.html
  -->
  <GlobalNamingResources>
    <!-- Editable user database that can also be used by
         UserDatabaseRealm to authenticate users
    -->
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>

  <!-- A "Service" is a collection of one or more "Connectors" that share
       a single "Container" Note:  A "Service" is not itself a "Container",
       so you may not define subcomponents such as "Valves" at this level.
       Documentation at /docs/config/service.html
   -->
  <Service name="Catalina">

    <!--The connectors can use a shared executor, you can define one or more named thread pools-->
    <!--
    <Executor name="tomcatThreadPool" namePrefix="catalina-exec-"
        maxThreads="150" minSpareThreads="4"/>
    -->


    <!-- A "Connector" represents an endpoint by which requests are received
         and responses are returned. Documentation at :
         Java HTTP Connector: /docs/config/http.html
         Java AJP  Connector: /docs/config/ajp.html
         APR (HTTP/AJP) Connector: /docs/apr.html
         Define a non-SSL/TLS HTTP/1.1 Connector on port 8080
    -->
    <Connector port="8080" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />
    <!-- A "Connector" using the shared thread pool-->
    <!--
    <Connector executor="tomcatThreadPool"
               port="8080" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />
    -->
    <!-- Define a SSL/TLS HTTP/1.1 Connector on port 8443
         This connector uses the NIO implementation. The default
         SSLImplementation will depend on the presence of the APR/native
         library and the useOpenSSL attribute of the
         AprLifecycleListener.
         Either JSSE or OpenSSL style configuration may be used regardless of
         the SSLImplementation selected. JSSE style configuration is used below.
    -->
    <!--
    <Connector port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol"
               maxThreads="150" SSLEnabled="true">
        <SSLHostConfig>
            <Certificate certificateKeystoreFile="conf/localhost-rsa.jks"
                         type="RSA" />
        </SSLHostConfig>
    </Connector>
    -->
    <!-- Define a SSL/TLS HTTP/1.1 Connector on port 8443 with HTTP/2
         This connector uses the APR/native implementation which always uses
         OpenSSL for TLS.
         Either JSSE or OpenSSL style configuration may be used. OpenSSL style
         configuration is used below.
    -->
    <!--
    <Connector port="8443" protocol="org.apache.coyote.http11.Http11AprProtocol"
               maxThreads="150" SSLEnabled="true" >
        <UpgradeProtocol className="org.apache.coyote.http2.Http2Protocol" />
        <SSLHostConfig>
            <Certificate certificateKeyFile="conf/localhost-rsa-key.pem"
                         certificateFile="conf/localhost-rsa-cert.pem"
                         certificateChainFile="conf/localhost-rsa-chain.pem"
                         type="RSA" />
        </SSLHostConfig>
    </Connector>
    -->

    <!-- Define an AJP 1.3 Connector on port 8009 -->
    <Connector port="8009" protocol="AJP/1.3" redirectPort="8443" />


    <!-- An Engine represents the entry point (within Catalina) that processes
         every request.  The Engine implementation for Tomcat stand alone
         analyzes the HTTP headers included with the request, and passes them
         on to the appropriate Host (virtual host).
         Documentation at /docs/config/engine.html -->

    <!-- You should set jvmRoute to support load-balancing via AJP ie :
    <Engine name="Catalina" defaultHost="localhost" jvmRoute="jvm1">
    -->
    <Engine name="Catalina" defaultHost="localhost">

      <!--For clustering, please take a look at documentation at:
          /docs/cluster-howto.html  (simple how to)
          /docs/config/cluster.html (reference documentation) -->
      <!--
      <Cluster className="org.apache.catalina.ha.tcp.SimpleTcpCluster"/>
      -->

      <!-- Use the LockOutRealm to prevent attempts to guess user passwords
           via a brute-force attack -->
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <!-- This Realm uses the UserDatabase configured in the global JNDI
             resources under the key "UserDatabase".  Any edits
             that are performed against this UserDatabase are immediately
             available for use by the Realm.  -->
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <Host name="localhost"  appBase="webapps"
            unpackWARs="true" autoDeploy="true">

        <!-- SingleSignOn valve, share authentication between web applications
             Documentation at: /docs/config/valve.html -->
        <!--
        <Valve className="org.apache.catalina.authenticator.SingleSignOn" />
        -->

        <!-- Access log processes all example.
             Documentation at: /docs/config/valve.html
             Note: The pattern used is equivalent to using pattern="common" -->
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b" />

      </Host>
    </Engine>
  </Service>
</Server>
EOF

cd ${project_dir}/gooalgene/${species_name}
docker-compose up -d
