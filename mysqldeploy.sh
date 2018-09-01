docker pull mysql:5.7  
# 编写docker-compose.yml文件
mysql_dir="/data/gooalgene/mysql"  
mysql_dir="/data/gooalgene/mysql"  
if [ ! -d ${mysql_dir}/mysql ];then  
        mkdir -p ${mysql_dir}/mysql

else  
        mv ${mysql_dir}/mysql  ${mysql_dir}/mysql.bak
        mkdir -p ${mysql_dir}/mysql
fi  
touch ${mysql_dir}/docker-compose.yml  
touch ${mysql_dir}/mysqld.cnf  
cd ${mysql_dir}  
echo "mysql_linuxwt:" > ${mysql_dir}/docker-compose.yml  
echo "  restart: always" >> ${mysql_dir}/docker-compose.yml  
echo "  image: mysql:5.7" >> ${mysql_dir}/docker-compose.yml  
echo "  container_name: mysql_linuxwt" >> ${mysql_dir}/docker-compose.yml  
echo "  volumes:" >> ${mysql_dir}/docker-compose.yml  
echo "    - /etc/localtime:/etc/localtime" >> ${mysql_dir}/docker-compose.yml  
echo "    - /etc/timezone:/etc/timezone" >> ${mysql_dir}/docker-compose.yml  
echo "    - \$PWD/mysql:/var/lib/mysql" >> ${mysql_dir}/docker-compose.yml  
echo "    - \$PWD/mysqld.cnf:/etc/mysql/mysql.conf.d/mysqld.cnf" >> ${mysql_dir}/docker-compose.yml  
echo "  ports:" >> ${mysql_dir}/docker-compose.yml  
echo "    - 33066:3306" >> ${mysql_dir}/docker-compose.yml  
echo "  environment:" >> ${mysql_dir}/docker-compose.yml  
echo "    MYSQL_ROOT_PASSWORD: $1" >> ${mysql_dir}/docker-compose.yml  
# 编写mysqld.cnf(这里借鉴了我以前的一些参数，具体还要根据实际情况来取值) 
echo "[mysqld]" > mysqld.cnf  
echo "pid-file = /var/run/mysqld/mysqld.pid" >> mysqld.cnf  
echo "socket = /var/run/mysqld/mysqld.sock" >> mysqld.cnf  
echo "datadir = /var/lib/mysql" >> mysqld.cnf  
echo "symbolic-links=0" >> mysqld.cnf  
echo "character-set-server=utf8" >> mysqld.cnf  
echo "back_log=500" >> mysqld.cnf  
echo "wait_timeout=1800" >> mysqld.cnf  
echo "max_connections=3000" >> mysqld.cnf  
echo "max_user_connections=800" >> mysqld.cnf  
echo "innodb_thread_concurrency=40" >> mysqld.cnf  
echo "default-storage-engine=innodb" >> mysqld.cnf  
echo "key_buffer_size=400M" >> mysqld.cnf  
echo "innodb_buffer_pool_size=1G" >> mysqld.cnf  
echo "innodb_log_file_size=256M" >> mysqld.cnf  
echo "innodb_flush_method=O_DIRECT" >> mysqld.cnf  
echo "innodb_log_buffer_size=20M" >> mysqld.cnf  
echo "query_cache_size=40M" >> mysqld.cnf  
echo "read_buffer_size=4M" >> mysqld.cnf  
echo "sort_buffer_size=4M" >> mysqld.cnf  
echo "read_rnd_buffer_size=8M" >> mysqld.cnf  
echo "tmp_table_size=64M" >> mysqld.cnf  
echo "thread_cache_size=64" >>mysqld.cnf  
echo "max_allowed_packet=200M" >> mysqld.cnf  
echo "server-id=1" >> mysqld.cnf  
echo "log_bin=mysql-bin" >> mysqld.cnf  
echo "general-log=1" >> mysqld.cnf  

# 启动mysql容器
docker-compose up -d  
if [ $? -eq 0 ];then  
        echo "mysql container start successfully."
else  
        echo "mysql container start failed and please check the revelant file!"
        exit -1
fi  
# 先在宿主机安装mysql客户端
wget https://downloads.mysql.com/archives/get/file/MySQL-client-5.5.40-1.el7.x86_64.rpm  
mariadb_package=$(rpm -qa|grep mariadb | wc -l)  
if [ $? -eq 1 ];then  
        rpm -qa| grep mariadb | xargs rpm -e --nodeps 
        rpm -ivh MySQL-client-5.5.40-1.el7.x86_64.rpm
else  
        rpm -ivh MySQL-client-5.5.40-1.el7.x86_64.rpm
fi  
# 验证root远程账号并创建项目库,创建库用户并授予所有权限
mysql -u root -h $8 -P33066 -p$1 -e "create database $2;show databases;"  
mysql -u root -h $8 -P33066 -p$1 -e "create database $3;show databases;"  
mysql -u root -h $8 -P33066 -p$1 -e "create database $4;show databases;"  
mysql -u root -h $8 -P33066 -p$1 -e "create database $5;show databases;"  
mysql -u root -h $8 -P33066 -p$1 -e "create user '$6'@'%' identified by '$7';"  
mysql -u root -h $8 -P33066 -p$1 -e "grant all privileges on $2.* to '$6'@'%';flush privileges;"  
mysql -u root -h $8 -P33066 -p$1 -e "grant all privileges on $3.* to '$6'@'%';flush privileges;"  
mysql -u root -h $8 -P33066 -p$1 -e "grant all privileges on $4.* to '$6'@'%';flush privileges;"  
mysql -u root -h $8 -P33066 -p$1 -e "grant all privileges on $5.* to '$6'@'%';flush privileges;"  
# 验证库用户  
mysql -u $6 -h $8 -P33066 -p$7 -e "show databases;" 
