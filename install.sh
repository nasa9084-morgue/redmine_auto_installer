#!/usr/bin/sh

redmine_ver="3.2.0"
wwwroot="/var/www/html"

verbose_flg=0
redminedir="redmine"
uname="user"
upass="pass"
password=""

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
        v) verbose_flg=1
           ;;
    esac
done

vecho()
{
    if [ $verbose_flg -eq 1 ]
    then
        echo $1
    fi
    return 0
}

vecho "Download Redmine..."
wget "http://www.redmine.org/releases/redmine-${redmine_ver}.tar.gz" -O "${wwwroot}/redmine.tar.gz"
state=$?
vecho "Redmine is downloaded."

if [ $state -eq 0 ]
then
    vecho "Expand downloaded tar.gz..."
    if [ $verbose_flg -eq 1 ]
    then
        tar zxvf "${wwwroot}/redmine.tar.gz" -C "${wwwroot}"
        state=$?
    else
        tar zxf "${wwwroot}/redmine.tar.gz" -C "${wwwroot}"
        state=$?
    fi
    vecho "Expand is successfully done."
fi

if [ $state -eq 0 ]
then
    vecho "Rename redmine directory..."
    mv ${wwwroot}/redmine-${redmine_ver}/ ${wwwroot}/${redminedir}/
    state=$?
    vecho "Renamed."
fi

if [ $state -eq 0 ]
then
    vecho "Create database..."
    mysql -u root --password="${password}" -e "create database if not exists redmine_${uname};"
    state=$?
    if [ $state -eq 0 ]
    then
        mysql -u root --password="${password}" -e "grant all on redmine_${uname}.* to '${uname}'@'localhost' identified by '${upass}';"
        state=$?
    fi
    vecho "Database creation is done."
fi

if [ $state -eq 0 ]
then
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
    state=$?
    vecho "Configuration is done."
fi

if [ $state -eq 0 ]
then
    vecho "Install bundler from gem..."
    gem install bundler
    state=$?
    vecho "Bundler is successfully installed."
fi

if [ $state -eq 0 ]
then
    vecho "Resolve dependency with bundler..."
    bundle install --without development test postgresql sqlite
    state=$?
    vecho "Dependency resolved."
fi

if [ $state -eq 0 ]
then
    vecho "Generate session-store secret key..."
    rake generate_secret_token
    state=$?
    vecho "Key is generated."
fi

if [ $state -eq 0 ]
then
    vecho "Create table..."
    cd redmine
    RAILS_ENV=production rake db:migrate
    state=$?
    vecho "Table is created."
fi

if [ $state -eq 0 ]
then
    vecho "Sign in Default data..."
    RAILS_ENV=production rake redmine:load_default_data
    state=$?
    vecho "Default data is loaded."
fi

if [ $state -eq 0 ]
then
    chown -R ${uname}:${uname} files log tmp public/plugin_assets
    state=$?
    if [ $state -eq 0 ]
    then
        chmod -R 755 files log tmp public/plugin_assets
        state=$?
    fi
fi
