USER=${USER:-super}
PASS=${PASS:-$(pwgen -s -1 16)}

pre_start_action() {
  # Echo out info to later obtain by running `docker logs container_name`
  echo "MARIADB_USER=$USER"
  echo "MARIADB_PASS=$PASS"
  echo "MARIADB_DATA_DIR=$DATA_DIR"

  # test if DATA_DIR has content
  if [[ ! "$(ls -A $DATA_DIR)" ]]; then
      echo "Initializing MariaDB at $DATA_DIR"
      # Copy the data that we generated within the container to the empty DATA_DIR.
      cp -R /var/lib/mysql/* $DATA_DIR
  fi

  # Ensure mysql owns the DATA_DIR
  chown -R mysql $DATA_DIR
  chown root $DATA_DIR/debian*.flag

  # test if CONFIG_DIR exists or has no content
  if [ ! -d "$CONFIG_DIR" ] || [ ! "$(ls -A $CONFIG_DIR)" ]; then
    echo "Initializing config directory at $CONFIG_DIR"
    # move config to /config and link the directory, allows mounting & backup of config
    mkdir -p $CONFIG_DIR
    mv /var/www/html/config/* $CONFIG_DIR
    rm -rf /var/www/html/config/
    ln -s $CONFIG_DIR /var/www/html

  fi

  # ensure permission
  chmod 755 $CONFIG_DIR
  chown -R www-data $CONFIG_DIR

}

post_start_action() {
  # The password for 'debian-sys-maint'@'localhost' is auto generated.
  # The database inside of DATA_DIR may not have been generated with this password.
  # So, we need to set this for our database to be portable.
  DB_MAINT_PASS=$(cat /etc/mysql/debian.cnf | grep -m 1 "password\s*=\s*"| sed 's/^password\s*=\s*//')
  mysql -u root -e \
      "GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '$DB_MAINT_PASS';"

  # Create the superuser.
  mysql -u root <<-EOF
      DELETE FROM mysql.user WHERE user = '$USER';
      FLUSH PRIVILEGES;
      CREATE USER '$USER'@'localhost' IDENTIFIED BY '$PASS';
      GRANT ALL PRIVILEGES ON *.* TO '$USER'@'localhost' WITH GRANT OPTION;
      CREATE USER '$USER'@'%' IDENTIFIED BY '$PASS';
      GRANT ALL PRIVILEGES ON *.* TO '$USER'@'%' WITH GRANT OPTION;
EOF

  rm /firstrun
}
