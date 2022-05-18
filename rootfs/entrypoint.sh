#!/bin/ash

# exit when any command fails
set -o errexit -o pipefail

# configuration
: "${APP_UID:=507}"
: "${APP_GID:=507}"
: "${APP_UMASK:=027}"
: "${APP_USER:=named}"
: "${APP_GROUP:=named}"
: "${APP_HOME:=/run/named}"
: "${APP_CONF_DIR:=/etc/bind}"

# export configuration
export APP_HOME APP_CONF_DIR APP_USER APP_GROUP

# invoked as root, add user and prepare container
if [ "$(id -u)" -eq 0 ]; then
  echo ">> removing default user and group"
  if getent passwd "$APP_USER" >/dev/null; then deluser "$APP_USER"; fi
  if getent group "$APP_GROUP" >/dev/null; then delgroup "$APP_GROUP"; fi

  echo ">> adding unprivileged user (uid: $APP_UID / gid: $APP_GID)"
  addgroup -g "$APP_GID" "$APP_GROUP"
  adduser -HD -h "$APP_HOME" -s /sbin/nologin -G "$APP_GROUP" -u "$APP_UID" -k /dev/null "$APP_USER"

  echo ">> fixing permissions"
  install -dm 0750 -o "$APP_USER" -g "$APP_GROUP" "$APP_HOME" /var/cache/bind /var/bind 
  chown -R "$APP_USER":"$APP_GROUP" \
          "$APP_HOME" \
          "$APP_CONF_DIR" \
          /var/cache/bind \
          /var/bind \
          /etc/s6

  echo ">> configuring rndc"
  if [[ ! -e "${APP_CONF_DIR}"/rndc.key ]]; then
    rndc-confgen -a -u named -c "${APP_CONF_DIR}"/rndc.key
  fi
  rndc_keyname=$(grep -E ^key "${APP_CONF_DIR}"/rndc.key | cut -d\" -f2)

  if [[ ! -e "${APP_CONF_DIR}"/rndc.conf ]]; then
    cat >"${APP_CONF_DIR}"/rndc.conf <<EOF
include "/etc/bind/rndc.key";
options {
  default-key "$rndc_keyname";
  default-server 127.0.0.1;
};
EOF
  fi

  echo ">> create link for syslog redirection"
  install -dm 0750 -o "$APP_USER" -g "$APP_GROUP" /run/syslogd
  ln -s /run/syslogd/syslogd.sock /dev/log

  # drop privileges and re-execute this script unprivileged
  echo ">> dropping privileges"
  export HOME="$APP_HOMEDIR" USER="$APP_USER" LOGNAME="$APP_USER" PATH="/usr/local/bin:/bin:/usr/bin"
  exec /usr/bin/setpriv --reuid="$APP_USER" --regid="$APP_GROUP" --init-groups --inh-caps=-all "$0" "$@"
fi

# tighten umask for newly created files / dirs
echo ">> changing umask to $APP_UMASK"
umask "$APP_UMASK"

echo ">> starting application"
exec /bin/s6-svscan /etc/s6

# vim: set ft=bash ts=2 sts=2 expandtab:

