FROM centos:centos7
MAINTAINER linuxwt <tengwanginit@gmail.com>
 
RUN yum -y update
 
RUN  echo '[mongodb-org-3.4]' > /etc/yum.repos.d/mongodb-org-3.4.repo
RUN  echo 'name=MongoDB Repository' >> /etc/yum.repos.d/mongodb-org-3.4.repo
RUN  echo 'baseurl=http://repo.mongodb.org/yum/redhat/7/mongodb-org/3.4/x86_64/' >> /etc/yum.repos.d/mongodb-org-3.4.repo
RUN  echo 'enabled=1' >> /etc/yum.repos.d/mongodb-org-3.4.repo
RUN  echo 'gpgcheck=0' >> /etc/yum.repos.d/mongodb-org-3.4.repo
 
RUN yum -y install make
RUN yum -y install mongodb-org
RUN mkdir -p /data/db
 
EXPOSE 27017
ENTRYPOINT ["/usr/bin/mongod"]
