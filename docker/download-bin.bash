#!/usr/bin/env bash

set -euxo pipefail

mkdir -p bin
cd bin

download_cfssl() {
	if [[ -f cfssl ]]; then
		return
	fi
	curl -SLf -o cfssl.tmp -C- -# https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssl_1.6.1_linux_amd64
	mv cfssl.tmp cfssl
	chmod +x cfssl
}

download_cfssljson() {
	if [[ -f cfssljson ]]; then
		return
	fi
	curl -SLf -o cfssljson.tmp -C- -# https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssljson_1.6.1_linux_amd64
	mv cfssljson.tmp cfssljson
	chmod +x cfssljson
}

download_etcd() {
	if [[ -f etcd ]]; then
		return
	fi
	curl -SLfO -C- -# https://github.com/etcd-io/etcd/releases/download/v3.4.13/etcd-v3.4.13-linux-amd64.tar.gz
	tar xf etcd-v3.4.13-linux-amd64.tar.gz
	rm etcd-v3.4.13-linux-amd64.tar.gz
	mv etcd-v3.4.13-linux-amd64/etcd .
	rm -rf etcd-v3.4.13-linux-amd64
}

download_kubernetes_server() {
	if [[ -f kube-apiserver && -f kube-controller-manager && -f kube-scheduler && -f kubectl ]]; then
		return
	fi
	curl -SLfO -C- -# https://dl.k8s.io/v1.21.12/kubernetes-server-linux-amd64.tar.gz
	tar xf kubernetes-server-linux-amd64.tar.gz
	rm kubernetes-server-linux-amd64.tar.gz
	mv kubernetes/server/bin/{kube-apiserver,kube-controller-manager,kube-scheduler,kubectl} .
	rm -rf kubernetes
}

download_virtual_kubelet() {
	if [[ -f virtual-kubelet ]]; then
		return
	fi
	GOBIN=${PWD} go install github.com/roy2220/virtual-kubelet/cmd/virtual-kubelet@new-module-name
}

download_cfssl
download_cfssljson
download_etcd
download_kubernetes_server
download_virtual_kubelet
