# scripts/fix-permissions.sh
#!/bin/bash
set -e

# Check if argument is provided
if [ $# -eq 0 ]; then
    echo "No root password for database provided. Usage: $0 <db_password>"
    exit 1
fi

# Store argument
DB_PASSWORD="$1"

export start=`date +%s`

until [[ -f sites/frontend/site_config.json ]] && \
      [[ -n `grep -hs ^ sites/frontend/site_config.json | jq -r ".db_name // empty"` ]] && \
      [[ -n `grep -hs ^ sites/frontend/site_config.json | jq -r ".db_password // empty"` ]];
do
    echo "Waiting for sites/frontend/site_config.json to be created and populated"
    sleep 5
    if (( `date +%s` - start > 120 )); then
        echo "Timeout: sites/frontend/site_config.json not created or missing required keys"
        exit 1
    fi
done

echo "sites/frontend/site_config.json found and populated"

# Direct variable assignment
username=$(jq -r '.db_name' sites/frontend/site_config.json)
password=$(jq -r '.db_password' sites/frontend/site_config.json)

echo "Waiting for MySQL user $username to be created"
until mysql -uroot -p${DB_PASSWORD} -hdb -e "SELECT 1 FROM mysql.user WHERE User='$username'" | grep -q 1; do
    sleep 5;
done;

echo "User $username found, updating permissions";

mysql -uroot -p${DB_PASSWORD} -hdb -e "UPDATE mysql.global_priv SET HOST = '%' WHERE User = '$username'; FLUSH PRIVILEGES;";
mysql -uroot -p${DB_PASSWORD} -hdb -e "SET PASSWORD FOR '$username'@'%' = PASSWORD('$password'); FLUSH PRIVILEGES;";
mysql -uroot -p${DB_PASSWORD} -hdb -e "GRANT ALL PRIVILEGES ON \`$username\`.* TO '$username'@'%' IDENTIFIED BY '$password' WITH GRANT OPTION; FLUSH PRIVILEGES;";

echo "Permissions updated successfully"