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

touch index.txt
test -e serial.txt || tee serial.txt <<< 00

# test -e "${CERT[0]}.cnf" || \
tee "${CERT[0]}.cnf" <<-EOF
	[default]
	extensions = exts
	# $(date -ur / +%Y%m%d%H%M%SZ)
	[ ca ]
	default_ca = ca_default
	[ ca_default ]
	serial   = serial.txt
	database = index.txt
	email_in_dn = yes
	default_md = default
	# default_days = $((DAYS))
	# default_startdate = 20200101000000Z
	# x509_extensions = exts
	# copy_extensions = none
	[ policy_anything ]
	countryName            = optional
	stateOrProvinceName    = optional
	localityName           = optional
	organizationName       = optional
	organizationalUnitName = optional
	commonName             = supplied
	emailAddress           = optional
	[ req ]
	utf8 = yes
	prompt = no
	default_md = sha256
	default_bits = $((SIZE))
	req_extensions  = exts
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

echo openssl req \
	-new    \
	-batch  \
	-nodes  \
	-set_serial "$((RANDOM))" \
	-newkey "rsa:${SIZE}" \
	-keyout "${CERT[0]}.key" \
	-config "${CERT[0]}.cnf" \
| openssl req \
	-new    \
	-batch  \
	-nodes  \
	-set_serial "$((RANDOM))" \
	-config "${CERT[0]}.cnf" \
	-key "./ca.key" \
| openssl ca \
	-utf8 \
	-batch \
	-preserveDN \
	-create_serial \
	-cert    "./ca.crt" \
	-keyfile "./ca.key" \
	-extfile "${CERT[0]}.cnf" \
	-config  "${CERT[0]}.cnf" \
	-out     "${CERT[0]}.crt" \
	-in      "/dev/stdin" \
	-days    "$((DAYS))" \
	-policy policy_anything \
	-startdate "$(date -ur / +%Y%m%d%H%M%SZ)" \
	-outdir "/tmp" \
	;
#openssl rsa -pubout -in "${CERT[0]}.key" -out "${CERT[0]}.pub"
ln -s "./ca.key" "${CERT[0]}.key"

cat "${CERT[0]}.crt" "./ca.crt" \
| tee "${CERT[0]}.bundle.crt" \
| openssl x509 -noout -text

chmod a+rX ${CERT[0]}.{crt,key,cnf,pub}

