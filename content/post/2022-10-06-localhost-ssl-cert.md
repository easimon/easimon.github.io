---
title: Painless self-signed certificates
subtitle: How to quickly create a self-signed TLS certificates and convert it to common formats.
date: 2022-10-06T21:00:00+02:00
tags:
  - openssl
  - tls
  - scripting
---

Whenever I needed a quick self-signed TLS certificate, it took me ages
to get the command line parameters to `openssl` right.

This code snippet creates a key and certificate for `localhost` that
is valid for approx. 1 year in PEM format. It also and creates a PKCS 12
store and a Java Keystore containing the same certificate and private key
for easier re-use in applications requiring these formats.

<!--more-->

Just use the following script, which is also available for [download](/attachments/mkselfsignedcert.sh).

```bash
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
```
