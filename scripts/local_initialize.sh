#!/bin/bash
set -eu

echo -n "Are you sure you want to initialize a new project (y/n)? "
read answer

if [ "$answer" != "${answer#[Yy]}" ] ;then # this grammar (the #[] operator) means that the variable $answer where any Y or y in 1st position will be dropped if they exist.
  cp .env.dev .env

  # Setup product name and the default language
  echo -n "Enter your project name: "
  read PROJECT_NAME
  echo -n "Choose the default language (ja/en/vi): "
  read DEFAULT_LANGUAGE
  echo -n "Set the admin panel route (Default: /admin): "
  read ADMIN_ROUTE

  sed -i _backup "s/demoshop/${PROJECT_NAME}/g" .env >> .env
  sed -i _backup "s/ja/${DEFAULT_LANGUAGE}/g" .env >> .env
  sed -i _backup "s/admin/${ADMIN_ROUTE}/g" .env >> .env
  rm -rf .env_backup
  sed -i _backup "s/demoshop/${PROJECT_NAME}/g" ./scripts/create_db.sql

  ## Setup domain name
  URL=local.$PROJECT_NAME.vn

  rm -rf docker/conf/eccube/eccube.conf docker/conf/proxy/proxy.conf
  rm -rf eccube
  rm -rf data
  
  echo "===> Cloning the source code of Eccube4..."
  git clone git@github.com:EC-CUBE/ec-cube.git eccube

  # Firing up Docker containers
  echo "===> Starting up Docker containers..."
  docker-compose up -d
  echo "===> Docker containers started"

  echo "===> Start importing EC-CUBE data..."
  docker-compose exec db /bin/sh -c "/scripts/wait-for-it.sh localhost:3306 --timeout=0 -- /usr/bin/mysql -uroot -p${PROJECT_NAME} ${PROJECT_NAME}_ec < /databases/eccube.sql"
  echo "===> Imported the EC-CUBE data"

  echo "===> Start the installation of Composer dependecies"
  docker-compose exec php /bin/sh -c /scripts/composer_install
  echo "===> Installed the composer dependencies"

  docker-compose exec php /bin/sh -c "cd /var/www/eccube && bin/console cache:clear --no-warmup"

  echo "===> Initilizing eccube database"
  docker-compose exec php bash -c "cd /var/www/eccube && bin/console eccube:install -n"

  echo "===> Removing unused files."
  bash ./scripts/remove_unused_files

  echo "===> Restart Docker containers..."
  docker-compose restart

  ## revert create_db file
  git checkout ./scripts/create_db.sql
  rm -rf ./scripts/create_db.sql_backup

  # Setting Hosts
  echo "===> Add domain to hosts file"
  sudo -- sh -c "echo '127.0.0.1 ${URL}' >> /etc/hosts"

  # Open Site in browser
  open https://"${URL}"

  echo "===> Local setup successfully finished!"

else
    echo "Canceled project Initiation:"
fi
