#!/usr/bin/env bash

test "$#" -ne 0 && ARGS=( "$@" )
test "$#" -eq 0 && ARGS=( localhost "*.localdomain" )

CERT_DAYS=3650
CERT_SIZE=4096
CERT_NAME="${ARGS[0]}"
CERT_FILE=( root ca "${CERT_NAME}" )
CERT_MAIL=info@${CERT_NAME}

test -e "libsslkeylog.so" && exit 0

rm -vf *.{cnf,crt,key,srl,pub}

tr '\n' '/' <<-EOF | openssl req \
	-new    \
	-x509   \
	-utf8   \
	-batch  \
	-nodes  \
	-sha256 \
	-set_serial  "$((RANDOM))" \
	-newkey "rsa:${CERT_SIZE}" \
	-keyout "${CERT_FILE[0]}.key" \
	-out    "${CERT_FILE[0]}.crt" \
	-days   "$((CERT_DAYS))"   \
	-subj "/$(cat)" \
	-addext basicConstraints=critical,CA:true \
	-addext subjectKeyIdentifier=hash \
	-addext keyUsage=cRLSign,keyCertSign \
	-addext authorityKeyIdentifier=keyid:always,issuer \
	-addext nsCertType=sslCA,emailCA \
	-addext issuerAltName=issuer:copy \
	-addext subjectAltName=email:copy \
	;
C=XX
ST=State
L=Locality
O=RootOrg
OU=OrgUnit
CN=${CERT_NAME} Root $(date -R)
emailAddress=${CERT_MAIL}
EOF
openssl rsa -pubout -in "${CERT_FILE[0]}.key" -out "${CERT_FILE[0]}.pub"

tee "${CERT_FILE[1]}.cnf" <<-EOF
	[default]
	extensions = exts
	copy_extensions = copy
	[ req ]
	utf8 = yes
	prompt = no
	default_md = sha256
	default_bits = $((CERT_SIZE))
	req_extensions  = exts
	x509_extensions = exts
	distinguished_name = dn
	[ dn ]
	countryName            = YY
	stateOrProvinceName    = Province
	localityName           = Locality
	organizationName       = IntOrg
	organizationalUnitName = OrgUnit
	commonName             = ${CERT_NAME} Intermediate $(date -R)
	emailAddress           = ${CERT_MAIL}
	[ exts ]
	basicConstraints = critical,CA:true
	keyUsage = nonRepudiation, digitalSignature, keyEncipherment, cRLSign, keyCertSign
	subjectAltName = email:${CERT_MAIL}
EOF

openssl req \
	-new    \
	-batch  \
	-nodes  \
	-set_serial "$((RANDOM))" \
	-newkey "rsa:${CERT_SIZE}" \
	-keyout "${CERT_FILE[1]}.key" \
	-config "${CERT_FILE[1]}.cnf" \
| openssl x509 -req \
	-CAcreateserial \
	-CA      "${CERT_FILE[0]}.crt" \
	-CAkey   "${CERT_FILE[0]}.key" \
	-out     "${CERT_FILE[1]}.crt" \
	-extfile "${CERT_FILE[1]}.cnf" \
	-days    "$((CERT_DAYS))" \
	;
openssl rsa -pubout -in "${CERT_FILE[1]}.key" -out "${CERT_FILE[1]}.pub"

IP=$( hostname -I | tr -d '[:blank:]' )
IPS=( ${IP%[0-9]}{0..255} )
IFS=','
tee "${CERT_FILE[2]}.cnf" <<-EOF
	[default]
	extensions = exts
	[ req ]
	utf8 = yes
	prompt = no
	default_md = sha256
	default_bits = $((CERT_SIZE))
	req_extensions  = exts
	x509_extensions = exts
	distinguished_name = dn
	[ dn ]
	countryName            = ZZ
	stateOrProvinceName    = Istanbul
	localityName           = Kadikoy
	organizationName       = LeafOrg
	organizationalUnitName = OrgUnit
	commonName             = ${CERT_NAME} Certificate $(date -R)
	emailAddress           = ${CERT_MAIL}
	[ exts ]
	basicConstraints = critical,CA:false
	keyUsage = nonRepudiation, digitalSignature, keyEncipherment
	extendedKeyUsage = serverAuth, clientAuth, codeSigning, emailProtection
	subjectAltName = email:${CERT_MAIL}, ${IPS[*]/#/IP:}, ${ARGS[*]/#/DNS:}
EOF
unset IFS

openssl req \
	-new    \
	-batch  \
	-nodes  \
	-set_serial "$((RANDOM))" \
	-newkey "rsa:${CERT_SIZE}" \
	-keyout "${CERT_FILE[2]}.key" \
	-config "${CERT_FILE[2]}.cnf" \
| openssl x509 -req \
	-CAcreateserial \
	-CA      "${CERT_FILE[1]}.crt" \
	-CAkey   "${CERT_FILE[1]}.key" \
	-extfile "${CERT_FILE[2]}.cnf" \
	-out     "${CERT_FILE[2]}.crt" \
	-days    "$((CERT_DAYS))" \
	;
openssl rsa -pubout -in "${CERT_FILE[2]}.key" -out "${CERT_FILE[2]}.pub"

cat \
	"${CERT_FILE[2]}.crt" \
	"${CERT_FILE[1]}.crt" \
| tee bundle.crt \
#| openssl x509 -noout -text

for FILE in "${CERT_FILE[@]}"; do
	HASH=$(openssl x509 -subject_hash_old -in "${FILE}.crt" | head -1)
	openssl x509 -noout -text -in "${FILE}.crt" \
	| cat "${FILE}.crt" - \
	| tee "${HASH}.0" \
	| openssl x509 -noout -text \
	;
	continue
done

# chown -R nginx *.{crt,key,srl,cnf,pub}

mkdir -p ssl/
cp "${CERT_FILE[1]}".{crt,key,srl,cnf,pub} ssl/
chmod -R a=rwX ssl/

# [ v3_req ]
# basicConstraints = CA:false
# keyUsage = nonRepudiation, digitalSignature, keyEncipherment
# extendedKeyUsage = serverAuth, clientAuth, codeSigning, emailProtection
# subjectAltName = @san

# [ v3_ca ]
# basicConstraints = critical,CA:true
# subjectKeyIdentifier = hash
# authorityKeyIdentifier = keyid:always,issuer
# keyUsage = cRLSign, keyCertSign
# nsCertType = sslCA, emailCA
# issuerAltName = issuer:copy
# subjectAltName = email:copy

grep -qi '^env' /etc/openresty/nginx.conf || {
	apt update && apt install -y curl gcc libssl-dev
	curl -sL "https://git.lekensteyn.nl/peter/wireshark-notes/plain/src/sslkeylog.c" \
	| cc -fPIC -ldl -shared -o libsslkeylog.so -x c -
	tee -a /etc/openresty/nginx.conf <<-EOF
	env LD_PRELOAD;
	env SSLKEYLOGFILE;
	EOF
	nginx -s quit
}

