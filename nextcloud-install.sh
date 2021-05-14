#/bin/bash

###############################################################################
# Script Installation Nextcloud + SSL
# Creation : 07/05/2021
# Revision : 07/05/2021
# Auteur   : wolfy
# Version  : 1
###############################################################################

set -o nounset
set -o errexit

export DEBIAN_FRONTEND=noninteractive 

###############################################################################
# VARIABLES
###############################################################################

nextcloud_version="21.0.1"
document_root="/var/www/nextcloud/"
nextcloud_ip="193.168.xxx.xxx"
nextcloud_servername="cloud.server.fr"
nextcloud_admin_username="username"
nextcloud_admin_password="********"
cert_method="openssl"
#cert_method="letsencrypt"
cert_email="admin@server.fr"

nextcloud_active_redis=1

nextcloud_db_database="name"
nextcloud_db_username="username"
nextcloud_db_hostname="localhost"
nextcloud_db_password="*********"

while [[ -z $nextcloud_db_password ]] ; do
	echo -ne "\nMariaDB Nextcloud Password: "
	read -s nextcloud_db_password
	echo -e "\n"
done

mysql_root_password=""

while [[ -z $mysql_root_password ]] ; do
	echo -n "MariaDB Root Password: "
	read -s mysql_root_password
	echo -e "\n"
done

while [[ -z $nextcloud_admin_password ]] ; do
	echo -n "Mot de passe pour l'admin (${nextcloud_admin_username}) : "
	read -s nextcloud_admin_password
done


###############################################################################
# VERIFICATION
###############################################################################


echo -e "\n[/]"
echo " | "
echo "[+]-> nextcloud_version=${nextcloud_version}"
echo "[+]-> document_root=${document_root}"
echo "[+]-> nextcloud_ip=${nextcloud_ip}"
echo "[+]-> nextcloud_servername=${nextcloud_servername}"
echo "[+]-> nextcloud_admin_username=${nextcloud_admin_username}"
echo -n "[+]-> nextcloud_admin_password="
for (( c=1; c<=${#nextcloud_admin_password}; c++ )); do
	echo -n "*"
done
echo -e "\n | "
echo "[+]-> cert_method=${cert_method}"
echo "[+]-> cert_email=${cert_email}"
echo " | "
echo "[+]-> nextcloud_db_hostname=${nextcloud_db_hostname}"
echo "[+]-> nextcloud_db_database=${nextcloud_db_database}"
echo "[+]-> nextcloud_db_username=${nextcloud_db_username}"
echo -n "[+]-> nextcloud_db_password="
for (( c=1; c<=${#nextcloud_db_password}; c++ )); do
	echo -n "*"
done
echo -ne "\n[+]-> mysql_root_password="
for (( c=1; c<=${#mysql_root_password}; c++ )); do
	echo -n "*"
done

echo -e "\n |"

agreed=no

while [[ $agreed != "n" && $agreed != "y" ]] ; do
	echo -ne "[?]-> Valider et lancer le déploiement (y/n): "
	read agreed
	echo -ne "\n"
done

case $agreed in
	"n")
		echo "Variable non validées, Installation annulée"
		exit 0
		;;

	"y")
		echo "Variables validées, début de l'installation "
		;;

	*)
		echo "Erreur dans le script..."
		exit 1
		;;

esac



###############################################################################
# FONCTIONS
###############################################################################

function _PRINT_CENTER
{
	title="$1"
	columns=$(tput cols)
	printf "%*s\n" $(((${#title}+${columns})/2)) "${title}"
}


function _PRINT_COMMAND_STATE 
{
	# [state( 0/1  ] [message""]
	# 0 -> ajouter
	# 1 -> existe déjà
	# 2 -> supprimer
	# 3 -> erreur

	state="$1"
	m="$2"

	color=""
	neutre="\e[0;m"

	echo " "
	
	case "$state" in
		0)
			colorl="\e[0;32m"
			colorb="\e[0;32m"
			echo -e "[${colorb}+${neutre}]-> ${colorl}Ajout:${colorb} 1${neutre}, Existe déjà: 0, Supprimé: 0, Erreur: 0 - ${m}"
			;;
		1)
			colorl="\e[0;34m"
			colorb="\e[1;34m"
			echo -e "[${colorb}.${neutre}]-> Ajout: 0, ${colorl}Existe déjà:${colorb} 1${neutre}, Supprimé: 0, Erreur: 0 - ${m}"
			;;
		2)
			colorl="\e[0;36m"
			colorb="\e[1;36m"
			echo -e "[${colorb}-${neutre}]-> Ajout: 0, Existe déjà: 0, ${colorl}Supprimé:${colorb} 0${neutre}, Erreur: 0 - ${m}"
			;;
		3)
			colorl="\e[0;31m"
			colorb="\e[1;31m"
			echo -e "[${colorb}!${neutre}]-> Ajout: 0, Existe déjà: 0, Supprimé: 0, ${colorl}Erreur:${colorb} 0${neutre} - ${m}"
			;;
		*)
			colorl="\e[0;31m"
			colorb="\e[1;31m"
			echo -e "[${colorb}?${neutre}]-> Ajout: 0, Existe déjà: 0, Supprimé: 0, Erreur: 0 - Erreur de scripting..."
			;;
			
	esac
	echo " "
	sleep 1
}

function _MYSQL_SECURE_INSTALLATION
{
	db_root_password="$1"	

	mysql --user=root -e "UPDATE mysql.user SET Password=PASSWORD('${db_root_password}') WHERE User='root';DELETE FROM mysql.user WHERE User='';DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';FLUSH PRIVILEGES;"
}

function _BACKUP_FILE
{
	file_to_backup=$1
	
	cp ${file_to_backup} ${file_to_backup}.$(date +"%d_%m_%Y_%H_%M_%S").back
}

function _VERIFY_PACKAGE_IS_INSTALLED()
{
	package=${1}

	if [ "$(dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -c "ok installed")" == "1" ]
	then
    		return 1
	else
		return 0
	fi
}

function _INSTALL_PACKAGES()
{
	packages="${@}"
	for i in "${packages[@]}"; do
		echo "${i}"
	done
}



###############################################################################
# UTILS
###############################################################################

_PRINT_CENTER "Installation des paquets utils"

apt -yqq -o=Dpkg::Use-Pty=0 update 1> /dev/null

_PRINT_COMMAND_STATE 0 "apt update"

utils=(apt-transport-https ca-certificates certbot curl libmagickcore-6.q16-6-extra lsb-release openssl python-certbot-apache unzip vim wget)

apt -yqq install ${utils[@]}

#apt -yqq -o=Dpkg::Use-Pty=0 install apt-transport-https ca-certificates certbot curl libmagickcore-6.q16-6-extra lsb-release openssl python-certbot-apache unzip vim wget 1> /dev/null



_PRINT_COMMAND_STATE 0 "apt install apt-transport-ht..."

###############################################################################
# PHP
###############################################################################

_PRINT_CENTER "Installation de PHP"

if [[ ! -f /etc/apt/trusted.gpg.d/php.gpg ]] ; then

	wget -q -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg

	_PRINT_COMMAND_STATE 0 "Ajout de la clé gpg du repo php sury"

else
	_PRINT_COMMAND_STATE 1 "Clé gpg php déjà présente"
fi 

if [[ ! -f /etc/apt/sources.list.d/php.list ]] ; then

	echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

	_PRINT_COMMAND_STATE 0 "Ajout du fichier /etc/apt/source.list.d/php.list avec le repo php de sury"
else
	_PRINT_COMMAND_STATE 1 "Repository PHP de sury existe déjà"
fi

apt -yqq -o=Dpkg::Use-Pty=0 update 1> /dev/null

_PRINT_COMMAND_STATE 0 "apt update"

apt -yqq -o=Dpkg::Use-Pty=0 install php7.4 php7.4-apcu php7.4-bcmath php7.4-bz2 php7.4-common php7.4-curl php7.4-fileinfo php7.4-gd php7.4-gmp php7.4-iconv \
php7.4-imagick php7.4-intl php7.4-json php7.4-mbstring php7.4-mysql php7.4-xml php7.4-zip 1> /dev/null

_PRINT_COMMAND_STATE 0 "apt install php7.4 php7.4-apcu php7.4-..."

###############################################################################
# BDD
###############################################################################

_PRINT_CENTER "Installation de la base de donnée"


apt -yqq -o=Dpkg::Use-Pty=0 install mariadb-server mariadb-client mariadb-common 1> /dev/null

_PRINT_COMMAND_STATE 0 "apt install mariadb-server mariadb-client mariadb-common"


_MYSQL_SECURE_INSTALLATION ${mysql_root_password}

_PRINT_COMMAND_STATE 0 "Mysql Secure Installation"


###############################################################################
# APACHE2
###############################################################################

_PRINT_CENTER "Installation de Apache"


apt -yqq -o=Dpkg::Use-Pty=0 install apache2 apache2-utils 1> /dev/null

_PRINT_COMMAND_STATE 0 "apt install apache2 apache2-utils"

/usr/sbin/a2enmod ssl headers

_PRINT_COMMAND_STATE 0 "a2enmod ssl headers"
#is_enmod=$(/usr/sbin/a2enmod ssl | grep -c "ssl already enabled")
#echo "is_enmod"
#
#if [[ $is_enmod -eq 0 ]] ; then
#	_PRINT_COMMAND_STATE 0 "Activation du module apache2 ssl"
#elif [[ $is_enmod -eq 1 ]] ; then
#	_PRINT_COMMAND_STATE 1 "Module apache2 ssl déjà activé"
#else
#	_PRINT_COMMAND_STATE 3 "Erreur de scripting..."
#fi


systemctl restart apache2

_PRINT_COMMAND_STATE 0 "Systemctl restart apache2"


###############################################################################
# NEXTCLOUD
###############################################################################

_PRINT_CENTER "Installation de Nextcloud"

if [[ ! -f /srv/nextcloud-${nextcloud_version}.zip ]] ; then

	wget https://download.nextcloud.com/server/releases/nextcloud-${nextcloud_version}.zip -O /srv/nextcloud-${nextcloud_version}.zip

	_PRINT_COMMAND_STATE 0 "Archive téléchargée"

else

	_PRINT_COMMAND_STATE 1 "Archive déjà présente"

fi


if [[ ! -d /var/www/nextcloud-${nextcloud_version} ]] ; then
	
	unzip -q /srv/nextcloud-${nextcloud_version}.zip -d /var/www
	chown -R www-data:www-data /var/www/nextcloud
	mv /var/www/nextcloud /var/www/nextcloud-${nextcloud_version}

	_PRINT_COMMAND_STATE 0 "Nextcloud copié dans /var/www/nextcloud-${nextcloud_version}"

else

	_PRINT_COMMAND_STATE 1 "Nextcloud déjà present?"

fi

if [[ ! -L /var/www/nextcloud ]] ; then

	ln -s /var/www/nextcloud-${nextcloud_version} /var/www/nextcloud
	chown -R www-data:www-data /var/www/nextcloud-${nextcloud_version}

	_PRINT_COMMAND_STATE 0 "Ajout d'un nouveau lien symbolique vers le nouveau nextcloud"

else

	rm /var/www/nextcloud
	_PRINT_COMMAND_STATE 1 "Une autre version de nextcloud existe? Suppression du lien symbolique"

	ln -s /var/www/nextcloud-${nextcloud_version} /var/www/nextcloud
	chown -R www-data:www-data /var/www/nextcloud-${nextcloud_version}
	_PRINT_COMMAND_STATE 0 "Ajout d'un nouveau lien symbolique vers le nouveau nextcloud"

fi



if [[ ! -d /var/log/nextcloud ]] ; then

	mkdir -p /var/log/nextcloud/

	_PRINT_COMMAND_STATE 0 "Création du dossier de log /var/log/nextcloud"

else

	_PRINT_COMMAND_STATE 1 "Dossier de log /var/log/nextcloud/ existe déjà"

fi


if [[ -f /etc/apache2/sites-available/001-nextcloud.conf ]] ; then
	
	_BACKUP_FILE "/etc/apache2/sites-available/001-nextcloud.conf"

	_PRINT_COMMAND_STATE 1 "Conf apache existante et sauvegardée"

fi

cat > /etc/apache2/sites-available/001-nextcloud.conf <<EOF
<VirtualHost *:443>

        ServerAdmin webmaster@localhost

        DocumentRoot nextcloud.documentroot
        ServerName nextcloud.ip
        ServerName nextcloud.servername

        Alias /nextcloud "nextcloud.documentroot"

        <Directory nextcloud.documentroot >
                Require all granted
                AllowOverride All
                Options FollowSymLinks MultiViews

                <IfModule mod_dav.c>
                        Dav off
                </IfModule>
        </Directory>

        SSLEngine on

	Header always set Strict-Transport-Security "max-age=15552000; includeSubdomains;"

        ErrorLog /var/log/nextcloud/error.log
        CustomLog /var/log/nextcloud/access.log combined

</VirtualHost>
EOF

_PRINT_COMMAND_STATE 0 "Création du fichier de conf apache2 pour Nextcloud"


sed -i "s|nextcloud.documentroot|${document_root}|g" /etc/apache2/sites-available/001-nextcloud.conf
sed -i "s/nextcloud.ip/${nextcloud_ip}/g" /etc/apache2/sites-available/001-nextcloud.conf
sed -i "s/nextcloud.servername/${nextcloud_servername}/g" /etc/apache2/sites-available/001-nextcloud.conf

_PRINT_COMMAND_STATE 0 "Personnalisation du fichier de conf apache2"


sed -i "s|memory_limit = 128M|memory_limit = 512M|g" /etc/php/7.4/apache2/php.ini

_PRINT_COMMAND_STATE 0 "Extension de la limite de mémoire de PHP à 512M"


echo "Generation du certificat avec "
case $cert_method in
	"openssl")
		echo "openssl"

		openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout /etc/ssl/private/nextcloud01-selfsigned.key -out /etc/ssl/certs/nextcloud01-selfsigned.crt -subj "/C=FR/ST=France/L=Paris/O=IDK/CN=${nextcloud_servername}"

		sed "/SSLEngine on/a SSLCertificateFile /etc/ssl/certs/nextcloud01-selfsigned.crt\n\tSSLCertificateKeyFile /etc/ssl/private/nextcloud01-selfsigned.key" /etc/apache2/sites-available/001-nextcloud.conf | tee /etc/apache2/sites-available/001-nextcloud.conf

		_PRINT_COMMAND_STATE 0 "Création du certificat openssl"

		;;

	"letsencrypt")
		echo "letsencrypt"
		certbot --apache --non-interactive --agree-tos --email ${cert_email} --domain ${nextcloud_servername}
		_PRINT_COMMAND_STATE 0 "Création du certificat letsencrypt"

		;;

	*)
		echo "openssl (default)"

		openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout /etc/ssl/private/nextcloud01-selfsigned.key -out /etc/ssl/certs/nextcloud01-selfsigned.crt -subj "/C=FR/ST=France/L=Paris/O=IDK/CN=${nextcloud_servername}"

		sed "/SSLEngine on/a SSLCertificateFile /etc/ssl/certs/nextcloud01-selfsigned.crt\nSSLCertificateKeyFile /etc/ssl/private/nextcloud01-selfsigned.key" /etc/apache2/sites-available/001-nextcloud.conf | tee /etc/apache2/sites-available/001-nextcloud.conf

		_PRINT_COMMAND_STATE 0 "Création du certificat openssl"

		;;

esac

/usr/sbin/a2ensite 001-nextcloud.conf
_PRINT_COMMAND_STATE 0 "Activation du site nextcloud"

systemctl restart apache2
_PRINT_COMMAND_STATE 0 "systemctl restart apache2"


mysql -e "CREATE USER IF NOT EXISTS '${nextcloud_db_username}'@'${nextcloud_db_hostname}' IDENTIFIED BY '${nextcloud_db_password}';CREATE DATABASE IF NOT EXISTS ${nextcloud_db_database} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;GRANT ALL PRIVILEGES ON ${nextcloud_db_database}.* TO '${nextcloud_db_username}'@'${nextcloud_db_hostname}';FLUSH PRIVILEGES;"

_PRINT_COMMAND_STATE 0 "Création de la base de donnée pour Nextcloud"


#sudo -u www-data php /var/www/nextcloud/occ maintenance:install --database "mysql" --database-name "${nextcloud_db_database}"  --database-user "${nextcloud_db_username}" --database-pass "${nextcloud_db_password}" --admin-user "${nextcloud_admin_username}" --admin-pass "${nextcloud_admin_password}"
#
#_PRINT_COMMAND_STATE 0 "Installation de nextcloud réussi"
#
#
#sed "/'installed' => true,/a  default_phone_region' => 'FR'," /var/www/nextcloud/config/config.php | tee /var/www/nextcloud/config/config.php
#
#_PRINT_COMMAND_STATE 0 "Configuration de la région pour les téléphones"
#
if [[ ${nextcloud_active_redis} -eq 1 ]] ; then

	apt -yqq install redis-server php7.4-redis
#
	_PRINT_COMMAND_STATE 0 "Installation de REDIS"
#
#	sed "/'installed' => true,/a  'memcache.distributed' => '\OC\Memcache\Redis', 'redis' => [ 'host' => 'localhost', 'port' => 6379, ]," /var/www/nextcloud/config/config.php | tee /var/www/nextcloud/config/config.php
#
#	_PRINT_COMMAND_STATE 0 "Configuration pour redis ajoutée"
#
fi

###############################################################################
# NEXTCLOUD
###############################################################################

_PRINT_CENTER "Nettoyage de la RAM"

sync; echo 3 > /proc/sys/vm/drop_caches

_PRINT_COMMAND_STATE 0 "Nettoyage de la RAM et du Cache effectué"

###############################################################################
# SCAN
###############################################################################

echo "Installation finis"

echo "À rajouter dans config.php : 'default_phone_region' => 'FR',"



echo "https://${nextcloud_servername}"
echo "https://www.ssllabs.com/ssltest/"
echo "https://scan.nextcloud.com/"
