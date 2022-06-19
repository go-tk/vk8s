#!/usr/bin/env bash

set -euxo pipefail

rm -rf lib
mkdir lib
cd lib

generate_ca() {
	cfssl gencert -initca - <<EOF | cfssljson -bare ca
{
  "CN": "vk8s",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "CA": {
    "expiry": "876000h"
  }
}
EOF
	rm ca.csr
	mv ca.pem ca.crt
	mv ca-key.pem ca.key
}

generate_config() {
	cat >config.json <<EOF
{
  "signing": {
    "profiles": {
      "vk8s": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "876000h"
      }
    }
  }
}
EOF
}

remove_config() {
	rm config.json
}

generate_kubernetes_cert() {
	cfssl gencert \
		-ca=ca.crt \
		-ca-key=ca.key \
		-config=config.json \
		-profile=vk8s \
		-hostname=localhost,${HOST_IP} \
		- <<EOF | cfssljson -bare kubernetes
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
	rm kubernetes.csr
	mv kubernetes.pem kubernetes.crt
	mv kubernetes-key.pem kubernetes.key
}

generate_service_account_cert() {
	cfssl gencert \
		-ca=ca.crt \
		-ca-key=ca.key \
		-config=config.json \
		-profile=vk8s \
		-hostname=localhost,${HOST_IP} \
		- <<EOF | cfssljson -bare service-account
{
  "CN": "service-account",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
	rm service-account.csr
	mv service-account.pem service-account.crt
	mv service-account-key.pem service-account.key
}

generate_admin_kubeconfig() {
	cfssl gencert \
		-ca=ca.crt \
		-ca-key=ca.key \
		-config=config.json \
		-profile=vk8s \
		- <<EOF | cfssljson -bare admin
{
  "CN": "system:admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF
	kubectl config set-cluster default \
		--certificate-authority=ca.crt \
		--embed-certs=true \
		--server=https://${HOST_IP}:${KUBE_APISERVER_PORT} \
		--kubeconfig=admin.kubeconfig
	kubectl config set-credentials default \
		--client-certificate=admin.pem \
		--client-key=admin-key.pem \
		--embed-certs=true \
		--kubeconfig=admin.kubeconfig
	kubectl config set-context default \
		--cluster=default \
		--user=default \
		--kubeconfig=admin.kubeconfig
	kubectl config use-context default --kubeconfig=admin.kubeconfig
	rm admin.csr admin.pem admin-key.pem
}

generate_kube_controller_manager_kubeconfig() {
	cfssl gencert \
		-ca=ca.crt \
		-ca-key=ca.key \
		-config=config.json \
		-profile=vk8s \
		- <<EOF | cfssljson -bare kube-controller-manager
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF
	kubectl config set-cluster default \
		--certificate-authority=ca.crt \
		--embed-certs=true \
		--server=https://${HOST_IP}:${KUBE_APISERVER_PORT} \
		--kubeconfig=kube-controller-manager.kubeconfig
	kubectl config set-credentials default \
		--client-certificate=kube-controller-manager.pem \
		--client-key=kube-controller-manager-key.pem \
		--embed-certs=true \
		--kubeconfig=kube-controller-manager.kubeconfig
	kubectl config set-context default \
		--cluster=default \
		--user=default \
		--kubeconfig=kube-controller-manager.kubeconfig
	kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
	rm kube-controller-manager.csr kube-controller-manager.pem kube-controller-manager-key.pem
}

generate_kube_scheduler_kubeconfig() {
	cfssl gencert \
		-ca=ca.crt \
		-ca-key=ca.key \
		-config=config.json \
		-profile=vk8s \
		- <<EOF | cfssljson -bare kube-scheduler
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
	kubectl config set-cluster default \
		--certificate-authority=ca.crt \
		--embed-certs=true \
		--server=https://${HOST_IP}:${KUBE_APISERVER_PORT} \
		--kubeconfig=kube-scheduler.kubeconfig
	kubectl config set-credentials default \
		--client-certificate=kube-scheduler.pem \
		--client-key=kube-scheduler-key.pem \
		--embed-certs=true \
		--kubeconfig=kube-scheduler.kubeconfig
	kubectl config set-context default \
		--cluster=default \
		--user=default \
		--kubeconfig=kube-scheduler.kubeconfig
	kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
	rm kube-scheduler.csr kube-scheduler.pem kube-scheduler-key.pem
}

generate_proxy_kubeconfig() {
	cat >proxy.kubeconfig <<EOF
kind: Config
apiVersion: v1
clusters:
- name: default
  cluster:
    server: http://${HOST_IP}:${KUBE_APISERVER_PROXY_PORT}
contexts:
- name: default
  context:
    cluster: default
current-context: default
EOF
}

generate_virtual_kubelet_configs() {
	for N in $(seq ${NODES}); do
		cat >vkubelet-mock-${N}-cfg.json <<EOF
{
  "vkubelet-mock-${N}": {
    "cpu": "16",
    "memory": "32Gi",
    "pods": "128"
  }
}
EOF
	done
}

generate_ca
generate_config
generate_kubernetes_cert
generate_service_account_cert
generate_admin_kubeconfig
if [[ -v DEBUG ]]; then
	generate_proxy_kubeconfig
else
	generate_kube_controller_manager_kubeconfig
	generate_kube_scheduler_kubeconfig
fi
generate_virtual_kubelet_configs
remove_config
