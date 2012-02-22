#!/bin/bash
openssl genrsa -out xbar.key 2048
openssl req -new -key xbar.key -out xbar.csr
openssl x509 -req -days 1000 -in xbar.csr -signkey xbar.key -out xbar.crt
