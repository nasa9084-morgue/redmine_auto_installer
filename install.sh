#!/usr/bin/sh

redmine_ver="3.2.0"
wwwroot="/var/www/html"

verbose_flg=0
redminedir="redmine"
uname="user"
upass="pass"
password=""
function vecho()
{
    if [ $verbose_flg -eq 1 ]
    then
        echo $1
    fi
    return 0
}

while getopts D:p:P:u:v OPT
do
    case $OPT in
        D) redminedir=$OPTARG
           ;;
        p) upass=$OPTARG
           ;;
        P) password=$OPTARG
           ;;
        u) uname=$OPTARG
           ;;
        v) varbose_flg=1
           ;;
    esac
done

vecho "Download Redmine..."
wget "http://www.redmine.org/releases/redmine-${redmine_ver}.tar.gz" -O "${wwwroot}/redmine.tar.gz"
vecho "Redmine is downloaded."

vecho "Expand downloaded tar.gz..."
if [ $verbose_flg -eq 1 ]
then
    tar zxvf "${wwwroot}/redmine.tar.gz" -C "${wwwroot}"
else
    tar zxf "${wwwroot}/redmine.tar.gz" -C "${wwwroot}"
fi
vecho "Expand is successfully done."

vecho "Rename redmine directory..."
mv ${wwwroot}/redmine-${redmine_ver} ${wwwroot}/${redminedir}
vecho "Renamed."

vecho "Create database..."
mysql -u root --password="${password}" -e "create database if not exists redmine_${uname};"
mysql -u root --password="${password}" -e "grant all on redmine_${uname}.* to '${uname}'@'localhost' identified by '${upass}';"
vecho "Database creation is done."

vecho "Config redmine database..."
cat <<EOF > config/database.yml
production:
  adapter: mysql2
  database: redmine_${uname}
  host: localhost
  usernae: ${uname}
  password: "${upass}"
  encoding: utf8
EOF
vecho "Configuration is done."

vecho "Install bundler from gem..."
gem install bundler
vecho "Bundler is successfully installed."

vecho "Resolve dependency with bundler..."
bundle install --without development test postgresql sqlite
vecho "Dependency resolved."

vecho "Generate session-store secret key..."
rake generate_secret_token
vecho "Key is generated."

vecho "Create table..."
cd redmine
RAILS_ENV=production rake db:migrate
vecho "Table is created."

vecho "Sign in Default data..."
RAILS_ENV=production rake redmine:load_default_data
vecho "Default data is loaded."

mkdir tmp public/plugin_assets
chown -R ${uname}:${uname} files log tmp public/plugin_assets
chmod -R 755 files log tmp public/plugin_assets
