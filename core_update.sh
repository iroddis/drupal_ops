#!/bin/bash

if [[ $# -ne 1 ]]; then
  echo << "EOUSAGE"
Usage: core_updates.sh <X.Y.Z> [site]+
Examples:
  Update all drupal 8.X.X sites to 8.7.0:
    core_updates.sh 8.7.0
  Update a single site to 7.66:
    core_updates.sh 7.66 vcconnect
EOUSAGE
  exit 1
fi

cd /tmp
#----------------------------------------------
# Download the core, if it's not already there
#----------------------------------------------
VERSION="$1"; shift
MAJOR_VERSION="$(echo $VERSION | cut -d. -f1)"
DL_URL="https://ftp.drupal.org/files/projects/drupal-${VERSION}.zip"
CORE_DIR="drupal-${VERSION}"

if [[ ! -d "$CORE_DIR" ]]; then
  echo "Downloading core"
  curl -s "${DL_URL}" -o "/tmp/${CORE_DIR}.zip"
  unzip -q "${CORE_DIR}.zip"
  rm -rf "${CORE_DIR}/.htaccess"
else
  echo "Using pre-existing download from /tmp/${CORE_DIR}"
fi

#----------------------------------------------
# Download the core, if it's not already there
#----------------------------------------------
if [[ $# -gt 2 ]]; then
  SITES="$@"
else
  SITES="$(ls /home/ | cut -d/ -f3 | tr '\n' ' ')"
fi

for site in $SITES; do
  SITE_DIR="/home/${site}/"
  [[ ! -d ${SITE_DIR}/public_html ]] && continue

  case "$MAJOR_VERSION" in
    8)
      VER_FILE="${SITE_DIR}/public_html/core/lib/Drupal.php"
      if [[ ! -f "${VER_FILE}" ]]; then
        echo "Skipping ${site}: Not a drupal 8 site"
        continue
      fi
      CUR_VERSION="$(grep 'const VERSION =' "${VER_FILE}" | cut -d\' -f2)"
      ;;
    7)
      VER_FILE="${SITE_DIR}/public_html/includes/bootstrap.inc"
      if [[ ! -f "${VER_FILE}" ]]; then
        echo "Skipping ${site}: Not a drupal 7 site"
        continue
      fi
      CUR_VERSION="$(grep "'VERSION'" "${VER_FILE}" | cut -d\' -f4)"
      ;;
  esac

  if [[ "$CUR_VERSION" = "$VERSION" ]]; then
    echo "Skipping ${site}: Already at version ${VERSION}"
    continue
  fi

  OWNER="$(ls -lad ${SITE_DIR}/. | awk '{ print $3 }')"

  echo "Running update of ${site} as ${OWNER}"
  echo "   copying"
  su - "${OWNER}" -c "rsync -ar /tmp/${CORE_DIR}/. ${SITE_DIR}/public_html/."
  echo "   running update.php"
  su - "${OWNER}" -c "cd ${SITE_DIR}/public_html; php ./update.php"
  echo "   done"
done

echo "Cleaning up"
rm -rf /tmp/${CORE_DIR} /tmp/${CORE_DIR}.zip
