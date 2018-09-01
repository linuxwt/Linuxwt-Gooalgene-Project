FROM tomcat:8.5  
MAINTAINER linuxwt

RUN mkdir /usr/local/tomcat/maven  
ADD ./maven3.5 /usr/local/tomcat/maven

ENV MAVEN_HOME /usr/local/tomcat/maven  
ENV PATH $PATH:$MAVEN_HOME/bin

EXPOSE 8080  
