export NODES=${NODES:-3}
export TTL=${TTL:-0}

export ETCD_CLIENT_PORT=${ETCD_CLIENT_PORT:-2379}
export ETCD_PEER_PORT=${ETCD_PEER_PORT:-2380}
export KUBE_APISERVER_PORT=${KUBE_APISERVER_PORT:-6443}
export KUBE_APISERVER_PROXY_PORT=${KUBE_APISERVER_PROXY_PORT:-8080}
export VIRTUAL_KUBELET_PORT=${VIRTUAL_KUBELET_PORT:-10260}

export HOST_IP=$(ip route get 1.1.1.1 | grep -Eo ' src [^ ]+ ' | cut -d' ' -f 3)
