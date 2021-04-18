#!/usr/bin/env bash
set -e
###################################################################
# Script: create-openssl-cert-and-key.sh
# Author: Cody Lane
#
# Description:
#   This creates a self-signed openssl key and certificate to be
#   used with local development.
#
# Usage:
#   The following variables are configurable
#
#    KEY_DIR:
#      The path where the crt and key will be
#      enerated.
#      Default. '.'
#
#    KEY_EXPIRE_AFTER_DAYS:
#      The number of days that key is valid for
#      Default: 365
#
#    KEY_NAME:
#      The name of the certificate.
#      Default: FQDN
#
#    KEY_COUNTRY:
#      The certificates default Country:
#      Default: US
#   KEY_STATE:
#     The certificates default State:
#     Default: DC
#
#   KEY_LOCATION:
#     The certificates default Location:
#     Default: DC
#
#   KEY_ORG:
#     The certificates default Organization:
#     Default: HOME
#
#   KEY_ORG_UNIT:
#     The certificates default Organization Unit:
#      #Default: IT Department
#
#   KEY_CN:
#     The certificates Common Name:
#     Default: FQDN
#
###################################################################

KEY_DIR="${KEY_DIR:-.}"
KEY_EXPIRE_AFTER_DAYS=365
KEY_TYPE="rsa"
KEY_BITS=4096
KEY_NAME="${KEY_NAME:-$(hostname -f)}"
# KEY_COUNTRY="${KEY_COUNTRY:-US}"
# KEY_STATE="${KEY_STATE:-DC}"
# KEY_LOCATION="${KEY_LOCATION:-DC}"
# KEY_ORG="${KEY_ORG:-HOME}"
# KEY_ORG_UNIT="${KEY_ORG:-IT Department}"
KEY_CN="${KEY_CN:-${KEY_NAME}}"

[ -f "${KEY_DIR}/${KEY_NAME}.crt" ] && exit 0

cd /etc/nginx

openssl req \
  -x509 \
  -nodes \
  -days   ${KEY_EXPIRE_AFTER_DAYS} \
  -newkey "${KEY_TYPE}:${KEY_BITS}" \
  -keyout "${KEY_DIR}/${KEY_NAME}.key" \
  -out    "${KEY_DIR}/${KEY_NAME}.crt" \
  -subj   "/CN=${KEY_CN}"

cat > /etc/nginx/conf.d/ssl.conf <<EOF
server {
    listen       443 ssl http2 default_server;
    listen  [::]:443 ssl http2 default_server;

    ssl_certificate      /etc/nginx/${HOSTNAME}.crt;
    ssl_certificate_key  /etc/nginx/${HOSTNAME}.key;

    server_name  ${HOSTNAME} localhost;

    access_log  /var/log/nginx/default.access.log  main;

    root   /var/www/default;
}
EOF
