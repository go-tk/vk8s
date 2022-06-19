#!/usr/bin/env bash

set -euxo pipefail

source config.bash

./stop.bash
trap ./stop.bash EXIT

./download-bin.bash
export PATH=$(realpath bin):${PATH}

./make-lib.bash

mkdir -p run db log
echo 'rm -r run db' >>run/cleanup.bash

PIDS=()

etcd \
	--advertise-client-urls=http://${HOST_IP}:${ETCD_CLIENT_PORT} \
	--data-dir=db \
	--listen-client-urls=http://${HOST_IP}:${ETCD_CLIENT_PORT} \
	--listen-peer-urls=http://${HOST_IP}:${ETCD_PEER_PORT} \
	>log/etcd.log 2>&1 &
PIDS+=(${!})
echo "kill -9 ${!}" >>run/cleanup.bash

kube-apiserver \
	--etcd-servers=http://${HOST_IP}:${ETCD_CLIENT_PORT} \
	--allow-privileged=true \
	--authorization-mode=RBAC \
	--service-cluster-ip-range=10.43.0.0/16 \
	--service-account-issuer=https://${HOST_IP}:${KUBE_APISERVER_PORT}/ \
	--service-account-key-file=lib/service-account.crt \
	--service-account-signing-key-file=lib/service-account.key \
	--bind-address=${HOST_IP} \
	--port=0 \
	--secure-port=${KUBE_APISERVER_PORT} \
	--client-ca-file=lib/ca.crt \
	--tls-cert-file=lib/kubernetes.crt \
	--tls-private-key-file=lib/kubernetes.key \
	--v=0 \
	>log/kube-apiserver.log 2>&1 &
PIDS+=(${!})
echo "kill -9 ${!}" >>run/cleanup.bash

N=0
while true; do
	if [[ $({ kubectl --kubeconfig=lib/admin.kubeconfig get services -o custom-columns=:metadata.name --no-headers || true; } | wc -l) -ge 1 ]]; then
		break
	fi
	if [[ ${N} -eq 10 ]]; then
		exit 1
	fi
	sleep 1s
	N=$((N + 1))
done

kubectl --kubeconfig=lib/admin.kubeconfig proxy --address=0.0.0.0 --port=${KUBE_APISERVER_PROXY_PORT} --accept-hosts='.*' >log/kube-apiserver-proxy.log 2>&1 &
PIDS+=(${!})
echo "kill -9 ${!}" >>run/cleanup.bash

kube-controller-manager \
	--kubeconfig=lib/${DEBUG-kube-controller-manager}${DEBUG+proxy}.kubeconfig \
	--cluster-name=kubernetes \
	--cluster-cidr=10.42.0.0/16 \
	--cluster-signing-cert-file=lib/ca.crt \
	--cluster-signing-key-file=lib/ca.key \
	--root-ca-file=lib/ca.crt \
	--service-account-private-key-file=lib/service-account.key \
	--service-cluster-ip-range=10.43.0.0/16 \
	--port=0 \
	--secure-port=0 \
	--leader-elect=false \
	--v=0 \
	>log/kube-controller-manager.log 2>&1 &
PIDS+=(${!})
echo "kill -9 ${!}" >>run/cleanup.bash

kube-scheduler \
	--kubeconfig=lib/${DEBUG-kube-scheduler}${DEBUG+proxy}.kubeconfig \
	--port=0 \
	--secure-port=0 \
	--leader-elect=false \
	--v=0 \
	>log/kube-scheduler.log 2>&1 &
PIDS+=(${!})
echo "kill -9 ${!}" >>run/cleanup.bash

for N in $(seq ${NODES}); do
	KUBECONFIG=lib/${DEBUG-admin}${DEBUG+proxy}.kubeconfig \
		KUBELET_PORT=$((${VIRTUAL_KUBELET_PORT} + ${N} - 1)) \
		APISERVER_CERT_LOCATION=lib/kubernetes.crt \
		APISERVER_KEY_LOCATION=lib/kubernetes.key \
		virtual-kubelet \
		--provider=mock \
		--provider-config=lib/vkubelet-mock-${N}-cfg.json \
		--nodename=vkubelet-mock-${N} \
		--disable-taint \
		>log/virtual-kubelet-${N}.log 2>&1 &
	PIDS+=(${!})
	echo "kill -9 ${!}" >>run/cleanup.bash
done

CMD=(kubectl --kubeconfig=lib/admin.kubeconfig get nodes -o custom-columns=:metadata.name --no-headers -w)
awk 'NR == 1 {
	cmd = $0
	printf("cmd: %s\n", cmd) > "/dev/stderr"
	cmd = "echo $$ && exec "cmd
	cmd | getline pid
	printf("pid: %d\n", pid) > "/dev/stderr"
	while (1) {
		if ((cmd | getline line) <= 0) {
			close(cmd)
			exit(1)
		}
		printf("line: %s\n", line) > "/dev/stderr"
		lines[line]++
		if (length(lines) == '${NODES}') {
			system("kill -9 "pid)
			close(cmd)
			exit(0)
		}
	}
}' <<<${CMD[@]@Q}

for N in $(seq ${NODES}); do
	kubectl --kubeconfig=lib/admin.kubeconfig label nodes vkubelet-mock-${N} kubernetes.io/os=linux
done

if [[ ${TTL} -ge 1 ]]; then
	sleep ${TTL} &
	PIDS+=(${!})
	echo "kill -9 ${!}" >>run/cleanup.bash
fi

echo '>>>>> vk8s is up <<<<<'
echo 1 >run/ready
wait -n "${PIDS[@]}"
