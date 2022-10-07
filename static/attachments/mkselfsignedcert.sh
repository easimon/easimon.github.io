#!/usr/bin/env bash

# host name this certificate is for
HOSTNAME="localhost"

# base filename for all certificate files
CERTNAME="certificate"

# password for PKCS12 and Java Keystore
# leave as is for default password for Java keystores
PASSWORD="changeit"

# PEM, e.g. Apache, nginx, ...
openssl req \
  -new                      \
  -x509                     \
  -subj   "/C=DE/ST=Somestate/L=SomeLocation/O=SomeOrganization/CN=${HOSTNAME}" \
  -nodes                    \
  -newkey "rsa:4096"        \
  -days   365               \
  -keyout "${CERTNAME}.key" \
  -out    "${CERTNAME}.crt"

# PKCS 12, e.g. IIS, .NET applications
openssl pkcs12 \
  -export \
  -nodes \
  -passout  "pass:${PASSWORD}" \
  -certfile "${CERTNAME}.crt"  \
  -in       "${CERTNAME}.crt"  \
  -inkey    "${CERTNAME}.key"  \
  -out      "${CERTNAME}.p12"

# Java Keystore, e.g. Tomcat
keytool -importkeystore \
  -srckeystore   "${CERTNAME}.p12" \
  -srcstoretype  "pkcs12"          \
  -srcstorepass  "${PASSWORD}"       \
  -destkeystore  "${CERTNAME}.jks" \
  -deststoretype "JKS"             \
  -deststorepass "${PASSWORD}"
