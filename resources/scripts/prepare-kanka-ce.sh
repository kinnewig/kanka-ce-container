#!/usr/bin/env bash

# ---------------------------------------------------------------------
# 
# Copyright (C) 2026 @Sebastian Kinnewig
#
# This file is part of the Kanka CE toolchain.
# It is NOT part of the official Kanka project and is not affiliated
# with or endorsed by the Kanka developers.
#
# The code in this file is licensed under the GNU Lesser General
# Public License v2.1 (LGPL-2.1) as published by the Free Software
# Foundation.
#
# The full text of the license can be found in the file LICENSE.md.
#
# ---------------------------------------------------------------------

# Set default values
USER_ID=1000
GROUP_ID=1000

KANKA_CE_DIR=$(pwd)



# ++============================================================++
# ||                         Premilaris                         ||
# ++============================================================++
# Colours for progress and error reporting
ERROR="\033[1;31m"
GOOD="\033[1;32m"
WARN="\033[1;35m"
INFO="\033[1;34m"
BOLD="\033[1m"

cecho() {
  # Display messages in a specified colour
  COL=$1; shift
  echo -e "${COL}$@\033[0m"
}



# ++============================================================++
# ||                  Install Laravel Sail                      ||
# ++============================================================++
install_sail() {
  if command -v podman &>/dev/null; then
    podman run --rm \
      -u "$USER_ID:$GROUP_ID" \
        -v $KANKA_CE_DIR:/var/www/html:z \
        -w /var/www/html \
        laravelsail/php84-composer:latest \
        composer install --ignore-platform-reqs
  elif command -v docker &>/dev/null; then
    docker run --rm \
      -u "$USER_ID:$GROUP_ID" \
        -v $KANKA_CE_DIR:/var/www/html \
        -w /var/www/html \
        laravelsail/php84-composer:latest \
        composer install --ignore-platform-reqs
  else
    cecho ${ERROR} "Error: Neither 'podman' nor 'docker' is available on this system."
    cecho ${INFO} "Please install one of these tools to proceed:"
    cecho ${INFO} "- Debian/Ubuntu: sudo apt install podman  # or docker"
    cecho ${INFO} "- Red Hat/Fedora: sudo dnf install podman  # or docker"
    exit 1
  fi  
}



# ++============================================================++
# ||                  Add sail to bashrc                        ||
# ++============================================================++
add_to_path() {
  # Create a backup:
  BACKUP=~/.bashrc.backup.$(date +%s)
  cp ~/.bashrc $BACKUP

  # Remove previous KANKA-CE-TOOLS block if it exists
  if grep -q "#BEGIN: ADDED BY KANKA-CE-TOOLS" ~/.bashrc; then
    sed -i '/#BEGIN: ADDED BY KANKA-CE-TOOLS/,/#END: ADDED BY KANKA-CE-TOOLS/d' ~/.bashrc
  fi

  # Write the KANKA-CE-TOOLS block
  {
    echo
    echo "#BEGIN: ADDED BY KANKA-CE-TOOLS"
    echo "# Everything in this block will be overwritten the next time you run KANKA-CE-TOOLS"
    echo
    echo "# --- Laravel Sail ---"
    echo "if [ -d \"${KANKA_CE_DIR}/vendor/bin\" ]; then"
    echo "  export PATH=${KANKA_CE_DIR}/vendor/bin:\${PATH}"
    echo "fi"
    echo 
    echo "#END: ADDED BY KANKA-CE-TOOLS"
  } >> ~/.bashrc

  # Preform at least a very basic sanity check:
  if ! bash -c 'source ~/.bashrc && command -v ls >/dev/null && command -v vi >/dev/null'; then
    cecho ${ERROR} "Auto update of the ~/.bashrc failed. PATH may be broken. Restoring backup..."
    cp $BACKUP ~/.bashrc
    exit 1
  fi

  source ~/.bashrc
}



# ++============================================================++
# ||                     First Set up                           ||
# ++============================================================++
first_set_up() {
  # --- Podman or Docker ---
  # Check wether to use podman or docker, prefer podman.
  local provider = ""
  if command -v podman-compose &>/dev/null; then
    provider=podman
    # Tell sail to use podman
    sed -i.bak "s/docker-compose/podman-compose/g" ./vendor/laravel/sail/bin/sail
    # Skip the test if docker is running 
    {
      echo SAIL_SKIP_CHECKS=true
    } >> .env
    # Add SELinux rules
    sed -i "s|\(\${KANKA_CE_DATA}[^:]*:[^:']*\)|\1:z|g" ./docker-compose.yml
  elif command -v docker-compose &>/dev/null; then
    provider=docker
  else
    cecho ${ERROR} "Error: Neither 'podman' nor 'docker' is available on this system."
    cecho ${INFO} "Please install one of these tools to proceed:"
    cecho ${INFO} "- Debian/Ubuntu: sudo apt install podman-compose  # or docker-compose"
    cecho ${INFO} "- Red Hat/Fedora: sudo dnf install podman-compose  # or docker-compose"
    exit 1
  fi  

  # --- Start up the container ---
  sail up -d


  # --- Wait for the container to get ready ---
  echo "Waiting for MariaDB to be ready..."
  sleep 10
  # check if mariadb is ready
  MARIADB_CONTAINER=$(sail ps --format "{{.Names}}" | grep mariadb)
  if [ "$provider" = "podman" ]; then
    until podman exec $MARIADB_CONTAINER mariadb -u root -p${DB_ROOT_PASSWORD} ${DB_DATABASE} -h "localhost" --silent; do
      echo "Waiting for MariaDB to be ready..."
      sleep 2
    done
  elif [ "$provider" = "docker" ]; then
    until docker exec "$MARIADB_CONTAINER" mariadb -u root -p"${DB_ROOT_PASSWORD}" "${DB_DATABASE}" -h "localhost" --silent; do
      echo "Waiting for MariaDB to be ready..."
      sleep 2
    done
  else
    cecho ${ERROR} "Error: Neither 'podman' nor 'docker' is available on this system."
    exit 1
  fi
  echo "MariaDB ready to use!"


  # --- Configure Minio ---
  # Get the container name
  MINIO_CONTAINER=$(sail ps --format "{{.Names}}" | grep minio)
  # Authenticate
  $provider exec -it ${MINIO_CONTAINER} mc alias set kanka-minio http://localhost:9000 ${MINIO_ACCESS_KEY_ID} ${MINIO_PASSWORD}
  # Create Kanka bucket and make it public
  $provider exec -it ${MINIO_CONTAINER} mc mb kanka-minio/${MINIO_BUCKET}
  $provider exec -it ${MINIO_CONTAINER} mc anonymous set public kanka-minio/${MINIO_BUCKET}
  # Create thumbnails bucket and make it public
  $provider exec -it ${MINIO_CONTAINER} mc mb kanka-minio/thumbnails
  $provider exec -it ${MINIO_CONTAINER} mc anonymous set public kanka-minio/thumbnails


  # --- Run the installer ---
  sail artisan kanka:install
  sail artisan setup:meilisearch
}



# ++============================================================++
# ||                    The actual program                      ||
# ++============================================================++

# --- Verify that the script is called from the kanka root directory ---
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ "$(pwd)" != "${SCRIPT_DIR}" ]; then
  cecho ${ERROR} "ERROR: This script has to be called from the kanka-ce root directory."
fi


# --- Read the .env file ---
if [ ! -e "$(dirname "$0")/.env" ]; then
  cecho ${ERROR} "ERROR: $(dirname "$0")/.env does not exist!"
  exit 1
fi
source $(dirname "$0")/.env

# --- Check if the passwords are set ---
# DB_PASSWORD
if [[ -z "$DB_PASSWORD" ]]; then
    cecho ${ERROR} "DB_PASSWORD is empty!"
    exit 1
elif [[ "$DB_PASSWORD" == "password" ]]; then
    cecho ${ERROR} "DB_PASSWORD must not be 'password'!"
    exit 1
fi

# MINIO_PASSWORD
if [[ -z "$MINIO_PASSWORD" ]]; then
  cecho ${ERROR} "MINIO_PASSWORD is empty!"
  exit 1
elif [[ "$MINIO_PASSWORD" == "password" ]]; then
  cecho ${ERROR} "MINIO_PASSWORD must not be 'password'!"
  exit 1
fi

# MEILISEARCH_KEY
if [[ -z "$MEILISEARCH_KEY" ]]; then
  cecho ${ERROR} "MEILISEARCH_KEY is empty!"
  exit 1
elif [[ "$MEILISEARCH_KEY" == "password" ]]; then
  cecho ${ERROR} "MEILISEARCH_KEY must not be 'password'!"
  exit 1
fi


# --- Install Sail ---
if ! install_sail "$@"; then
  exit 1
fi


# --- Add Sail to the PATH ---
if ! add_to_path "$@"; then
  exit 1
fi

# --- Create the data dir ---
mkdir -p ${KANKA_CE_DATA}/{mariadb,redis,minio,thumbor,meilisearch}


# --- Prepare & Install Kanka CE ---
if ! first_set_up "$@"; then
  exit 1
fi

cecho ${GOOD} "KANKA-CE Sucessfully installed!"
cecho ${INFO} "  To stop Kanka-CE, run from within the Kanka-CE root directory ($(pwd)):"
cecho ${INFO} "  sail down"
cecho ${INFO} "  To start Kanka-CE, run from within the Kanka-CE root directory:"
cecho ${INFO} "  sail up -d"
echo
cecho ${INFO} "You can visit Kanka-CE on http://localhost:${APP_PORT}"
