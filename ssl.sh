#!/bin/bash

nodename="node1 node2"

mkdir ~/kube-ssl && cd ~/kube-ssl
openssl genrsa -out ca-key.pem 2048
openssl req -x509 -new -nodes -key ca-key.pem -days 10000 -out ca.pem -subj "/CN=kube-ca"

cat << 'EOF' > openssl.cnf

[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = 10.3.0.1
IP.2 = 192.168.7.100

EOF

openssl genrsa -out apiserver-key.pem 2048
openssl req -new -key apiserver-key.pem -out apiserver.csr -subj "/CN=kube-apiserver" -config openssl.cnf
openssl x509 -req -in apiserver.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out apiserver.pem -days 365 -extensions v3_req -extfile openssl.cnf

cat << 'EOF' >> worker-openssl.cnf

[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = $ENV::WORKER_IP

EOF

for FQDN in $nodename
do
	 read -p 'Worker Node IP: ' WORKER_IP 
	 echo "WORKER NODE IP is ${WORKER_IP}"
	 openssl genrsa -out ${FQDN}-worker-key.pem 2048
	 WORKER_IP=${WORKER_IP} openssl req -new -key ${FQDN}-worker-key.pem -out ${FQDN}-worker.csr -subj "/CN=${FQDN}" -config worker-openssl.cnf
	 WORKER_IP=${WORKER_IP} openssl x509 -req -in ${FQDN}-worker.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out ${FQDN}-worker.pem -days 365 -extensions v3_req -extfile worker-openssl.cnf
done

# Create ssl directory and copy pem to it
sudo mkdir -p /etc/kubernetes/ssl
sudo cp ~/kube-ssl/*.pem /etc/kubernetes/ssl

sudo chmod 600 /etc/kubernetes/ssl/*-key.pem
sudo chown root:root /etc/kubernetes/ssl/*-key.pem
