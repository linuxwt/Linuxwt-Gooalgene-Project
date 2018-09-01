# 项目需求
docker部署mysql 5.7 mongo3.4 tomcat8.5 nginx maven jdk
mysql创建四个数据库dba dbb dbc dbd设定root密码，并用一个用户shanwang来管理这四个数据库，并位该用户设定密码
mongo创建四个数据库dba dbb dbc dbd设定admin库用户和密码、用一个用户shanwang来管理这四个数据库，并为每一个数据库设定一个密码
jdk和maven都需要加入环境变量，同时容器内外都要安装maven
# installECS.sh
可以自动进行磁盘分区格式化挂载,执行该脚本需要带上一个参数比如:bash installECS.sh /dev/sdb
# mysqldeploy.sh
该脚本需要带上8个参数，具体说明如下：
$1是root密码
$2-$5是四个数据库
$6是库用户
$7是库密码
$8是ip
bash mysqldeploy.sh rootpassword dba dbb dbc dbd shanwang tengwang105 10.8.8.10  
# mongodeploy.sh
bash mongo.sh $1 $2 $3 $4 $5 $6 $7 $8 $9 $10 ${11} 
$1表示admin的库用户，$2表示其密码 
$3-$6表示dba、dbb、dbc、dbd数据库 
$7表示dba、dbb、dbc、dbd的库用户 
$8-${11}表示dba、dbb、dbc、dbd的库密码 
bash mongodeploy.sh tengwang tengwang100 dba dbb dbc dbd shanwang shanwang101 shanwang102 shanwang103 shanwang104  
# tomcatdeploy.sh
在其前端部署了一个nginx代理跳转到tomcat的默认的8080端口  


