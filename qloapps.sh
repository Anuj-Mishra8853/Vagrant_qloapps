#!/bin/bash
# VAGRANT PROVISIONING SCRIPT FOR QLOAPPS
# AUTHOR: Anuj Mishra
# Webkul Software Pvt. Limited.
# Operating System: Ubuntu 20.04

##########################################################################################################
# This block contains variables to be defined by user. Before running this script, you must ensure that: #
#> You have vagrant installed on your server and this script is included in shell provisioning block in  #
#  Vagrantfile.                                                                                          #
#> If you want to setup database on remote host then remote host must be acccessible.                    #
#> Your domain name must be present. If not, create a DNS host entry in your firewall.                   #
# This script is strictly for one user per instance. Re-running scripts for another user will            #  
# throw errors and destroy configuration for first user.                                                 #
##########################################################################################################

# Manually set the user to 'qloapps'
user="your_username_here"  # Define the user manually

domain_name="your_domain_here"                                                                        ## mention the domain name

database_host="localhost"                                                                         ## mention database host.

database_name="qloapps"                                                                        ## mention database name

mysql_root_password=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1`  ## randomly generated database 

database_Connectivity() {
echo "CHECKING DATABASE HOST CONNECTIVITY"
database_connectivity_check=`mysqlshow --user=root --password=$mysql_root_password --host=$database_host | grep -o mysql`
if [ "$database_connectivity_check" != "mysql" ]; then
echo "$DATABASE CONNECTIVITY FAILED !"
exit 1
else
echo "DATABASE CONNECTIVITY ESTABLISHED"
fi
}

database_Availability() {
echo "CHECKING DATABASE AVAILABILITY"
database_availability_check=`mysqlshow  --user=root --password=$mysql_root_password --host=$database_host | grep -o $database_name`
if [ "$database_availability_check" == "$database_name" ]; then
echo "DATBASE $database_name ALREADY EXISTS. USE ANOTHER DATABASE NAME !"
exit 1
else
echo "DATABASE $database_name IS FREE TO BE USED"
fi
}

lamp_Installation() {
##update server
apt-get update \
    && apt-get -y install apache2 \
    && a2enmod rewrite \
    && a2enmod headers \
    && export LANG=en_US.UTF-8 \
    && apt-get update \
    && apt-get install -y software-properties-common \
    && apt-get install -y language-pack-en-base \
    && LC_ALL=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    && apt-get -y install php7.4 php7.4-curl php7.4-intl php7.4-gd php7.4-dom php7.4-iconv php7.4-xsl php7.4-mbstring php7.4-ctype php7.4-zip php7.4-pdo php7.4-xml php7.4-bz2 php7.4-calendar php7.4-exif php7.4-fileinfo php7.4-json php7.4-mysqli php7.4-mysql php7.4-posix php7.4-tokenizer php7.4-xmlwriter php7.4-xmlreader php7.4-phar php7.4-soap php7.4-fpm php7.4-bcmath libapache2-mod-php7.4 \
    && sed -i -e"s/^memory_limit\s*=\s*128M/memory_limit = 512M/" /etc/php/7.4/apache2/php.ini \
    && echo "date.timezone = Asia/Kolkata" >> /etc/php/7.4/apache2/php.ini \
    && sed -i -e"s/^upload_max_filesize\s*=\s*2M/upload_max_filesize = 16M/" /etc/php/7.4/apache2/php.ini \
    && sed -i -e"s/^max_execution_time\s*=\s*30/max_execution_time = 500/" /etc/php/7.4/apache2/php.ini

##install mysql-server=8.0
export DEBIAN_FRONTEND="noninteractive"
echo "mysql-server-8.0 mysql-server/root_password password $mysql_root_password" | debconf-set-selections
echo "mysql-server-8.0 mysql-server/root_password_again password $mysql_root_password" | debconf-set-selections
apt-get -y install mysql-server
sleep 4
database_Connectivity
sleep 2
database_Availability

##create database
mysql -h $database_host -u root -p$mysql_root_password -e "create database $database_name;" 
mysql -h $database_host -u root -p$mysql_root_password -e "grant all on $database_name.* to 'root'@'%' identified by '$mysql_root_password';"


##apache2 configuration
a2enmod rewrite
a2enmod headers

touch /etc/apache2/sites-enabled/qloapps.conf
cat <<EOF >> /etc/apache2/sites-enabled/qloapps.conf
<VirtualHost *:80> 
ServerName $domain_name
DocumentRoot /home/${user}/www/Qloapps
<Directory  /home/> 
Options FollowSymLinks 
Require all granted  
AllowOverride all 
</Directory> 

ErrorLog /var/log/apache2/error.log 
CustomLog /var/log/apache2/access.log combined 

</VirtualHost> 
EOF
}
mkdir -p /home/${user}/www/
qloapps_Download() {
apt-get install -y git
cd /home/${user}/www/  && git clone -b v1.6.1 https://github.com/Qloapps/QloApps.git

##ownership and permissions
find /home/${user}/www/  -type f -exec chmod 644 {} \;
find /home/${user}/www/  -type d -exec chmod 755 {} \;
echo "changing ownership /home/${user}/www/ "
chown -R www-data:www-data /home/${user} 

##restart servers
/etc/init.d/apache2 restart
}


logging_Credentials() {

##Logging randomly generated Mysql password in a file

echo "
_______________________________________________________________________\\

DOMAIN NAME: $domain_name
DATABASE HOST: $database_host
DATABASE USER: root
DATABASE ROOT USER'S PASSWORD: $mysql_root_password
DATABASE NAME: $database_name
________________________________________________________________________\\

Admin URL will be generated after qloapps installation. Please check admin frontname in server root directory.
REMOVE "/var/log/check.log" file after checking password.
Script Execution has been completed. If you encounter any errors, destroy this Vagrant server and re-build the Vagrant server." \
 > /var/log/check.log
echo "
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
         										              
 Vagrant Shell Provisoning is completed. Hit your domain name to start Qloapps Installation Process.    
 Also, please check /var/log/check.log file to retrieve your database credentials.                  
												      
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
"
}

main() {
lamp_Installation
qloapps_Download
logging_Credentials
}

main
