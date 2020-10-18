#!/usr/bin/env bash

set -e

cd "${PATH_TRANSLATED:-./ssl}"
echo

IFS=","
DAYS=365
SIZE=4096
CERT=( ${QUERY_STRING} "$@" )

# export 1>&2
# ls -lhaZ 1>&2
# pwd 1>&2

test -z "${CERT[0]}"     && exit
test -e "${CERT[0]}.crt" && exit

# test -e "${CERT[0]}.cnf" || \
tee "${CERT[0]}.cnf" <<-EOF
	[default]
	extensions = exts
	[ ca ]
	default_startdate = $(date -ur / +%Y%m%d%H%M%SZ)
	[ req ]
	utf8 = yes
	prompt = no
	default_bits = $((SIZE))
	default_md = sha256
	req_extensions  = exts
	x509_extensions = exts
	distinguished_name = dn
	[ dn ]
	countryName            = ZZ
	stateOrProvinceName    = State
	localityName           = Locality
	organizationName       = OrgName
	organizationalUnitName = OrgUnit
	commonName             = $(date -Is)
	emailAddress           = info@${CERT[0]}
	[ exts ]
	basicConstraints = critical,CA:false
	keyUsage = nonRepudiation, digitalSignature, keyEncipherment
	extendedKeyUsage = serverAuth, clientAuth, codeSigning, emailProtection
	subjectAltName = email:info@${CERT[0]}, ${CERT[*]/#/DNS:}
EOF
unset IFS

openssl req \
	-new    \
	-batch  \
	-nodes  \
	-set_serial "$((RANDOM))" \
	-newkey "rsa:${SIZE}" \
	-keyout "${CERT[0]}.key" \
	-config "${CERT[0]}.cnf" \
| openssl x509 -req \
	-CAcreateserial \
	-CA      "./ca.crt" \
	-CAkey   "./ca.key" \
	-extfile "${CERT[0]}.cnf" \
	-out     "${CERT[0]}.crt" \
	-days    "$((DAYS))" \
	;
openssl rsa -pubout -in "${CERT[0]}.key" -out "${CERT[0]}.pub"

cat "${CERT[0]}.crt" "./ca.crt" \
| tee "${CERT[0]}.bundle.crt" \
| openssl x509 -noout -text

chmod a+rX ${CERT[0]}.{crt,key,cnf,pub}
