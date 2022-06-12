#!/bin/bash

###
# Generate self signed certificates
#
# eg.: ./generate-certificate.sh
# eg.: ./generate-certificate.sh mysite.com Brazil
####

cd $(dirname "$0")
printf "\n🔐 GENERATE SELF SIGNED CERTIFICATE [date:$(date) user:$USER] \n"

# config

dns=$1
if [ -z "$dns" ]
then
    read -p "DNS: " dns
fi

locality=$2
if [ -z "$locality" ]
then
    read -p "Country: " locality
fi

printf "\n🔹 dns:$dns locality:$locality \n"

cert_main=cert
cert_auth=root

valid_days=3650

# create dir
rm -drf $dns || exit
mkdir -p $dns || exit
cd $dns || exit

# Set our CSR variables
SUBJ="/C=${locality:0:2}/ST=$locality/O=$locality/localityName=$locality/commonName=$dns/organizationalUnitName=$dns/emailAddress=admin@$dns/"

###
# Create Certificate Authority certificate
###

printf "\n🔹 generating root certificate \n"

# Generate private key
openssl genrsa -out $cert_auth.key 2048 || exit

# Generate root certificate
openssl req -x509 -new -subj "$(echo -n "$SUBJ")" -nodes -key $cert_auth.key -sha256 -days $valid_days -out $cert_auth.crt || exit

###
# Create CA-signed certificate
###

printf "\n🔹 creating self signed certificate \n"

# Generate private key
openssl genrsa -out $cert_main.key 2048 || exit

# Create certificate-signing request
openssl req -new -subj "$(echo -n "$SUBJ")" -key $cert_main.key -out $cert_main.csr || exit

# Create a config file for the extensions
>$cert_main.ext cat <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = $dns
EOF

# Create the signed certificate
openssl x509 -req -in $cert_main.csr -CA $cert_auth.crt -CAkey $cert_auth.key -CAcreateserial -out $cert_main.crt -days $valid_days -sha256 -extfile $cert_main.ext || exit

# remove temp file
rm $cert_main.ext

###
# Create P12
####

printf "\n🔹 creating P12 certificate \n"

openssl pkcs12 -export -in $cert_main.crt -inkey $cert_main.key -password pass:$dns -out $cert_main.p12 || exit