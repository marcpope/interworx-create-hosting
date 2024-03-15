#!/bin/bash
## this script performs a bunch of tasks in interworx in one file:
## creates siteworx account
## creates ftp login information
## creates a mysql user and database
## creates a lets encrypt SSL certificate (assuming domain is already pointed to sercer)
## adds user/group to lasso user/group and vice versa for file upload handling
## fixes apache privatetmp=true problem permanently

## usage ./create.sh mycoolwebsite.com mycoolwe

# Define variables
DOMAIN="$1"
UNIQNAME="$2"
EMAIL="YOUR@EMAILADDRESS.COM"
PASSWORD=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c10)
PACKAGE="Unlimited"
PHPVERSION="php82"
IPADDRESS="192.168.1.99" # change to the Public IP of your webpanel

# Execute NodeWorx CLI command
nodeworx -u root -n -c SiteWorx -a add --master_domain "$DOMAIN" --uniqname "$UNIQNAME" --email $EMAIL --password $PASSWORD --confirm_password $PASSWORD --package "$PACKAGE" --master_domain_ipv4 "$IPADDRESS" --php_version "/opt/remi/$PHPVERSION" --php_available "/opt/remi/php56,/opt/remi/php74,/opt/remi/php82" --restart_httpd 1 --softaculous 0

# generate MySQL Database
MYPASS=$(< /dev/urandom tr -dc 'A-Za-z0-9' | head -c10)
siteworx -u root --login_domain "$DOMAIN" -n -c MysqlDb --action add --name "db" --password "$MYPASS" --confirm_password "$MYPASS" --create_user 1 --user "usr" --perms "SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER,CREATE TEMPORARY TABLES,LOCK TABLES,CREATE VIEW,SHOW VIEW,CREATE ROUTINE,ALTER ROUTINE,EXECUTE,EVENT,TRIGGER" --host "localhost"

echo "Domain: $DOMAIN"
echo "-------------------------------------"
echo "ftp host: nuvay.falcondns.com"
echo "ftp user: ftp@$DOMAIN"
echo "ftp pass: $PASSWORD"
echo ""
echo "MySQL Information"
echo "-----------------"
echo "mysql user: $UNIQNAME""_usr"
echo "mysql db  : $UNIQNAME""_db"
echo "mysql pass: $MYPASS"
echo "----"
echo ""


echo "Generating SSL.."
siteworx -u root --login_domain "$DOMAIN" -u root -c Ssl -n --action generateLetsEncrypt --domain "$DOMAIN" --commonName "$DOMAIN" --subjectAltName "www.""$DOMAIN" --mode live

## copy htaccess template to correct folder
echo "Adding .htaccess file"
cp htaccess /home/$UNIQNAME/public_html/.htaccess
rm -rf /home/$UNIQNAME/public_html/index.html
chown $UNIQNAME:$UNIQNAME /home/$UNIQNAME/public_html/.htaccess

## optional section for Lasso 8.6 users
echo "--------------------"
echo "Adding User to Lasso"
usermod -a -G lasso $UNIQNAME
usermod -a -G $UNIQNAME lasso

echo "Restarting Lasso.."
lasso8ctl restart

echo "Patching Apache PrivateTmp=true problem..."
curl -s https://raw.githubusercontent.com/marcpope/privatetmp_fix/main/fix.sh | /bin/bash

echo "----"
echo "done... make sure to add DB to lasso security"
echo ""
