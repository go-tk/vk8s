# vk8s

Setting up a virtual Kubernetes cluster inside a Docker container for integration testing.

**Note**: A virtual Kubernetes cluster consists of virtual nodes, once newly-created pods are
assigned to these nodes, pods will immediately be reported as RUNNING status, but in reality
no any container of pods has been created and run, this is a trick achieved by [virtual-kubelet](https://github.com/virtual-kubelet/virtual-kubelet).

# Examples

- [Use in Shell](#use-in-shell)
- [Use in Go](#use-in-go)

## Use in Shell

```sh
# Run vk8s in background
docker run --name=vk8s -e TTL=300 -d --rm ghcr.io/go-tk/vk8s:v0.1.1

# Ensure vk8s is ready
docker exec vk8s ./wait-for-ready.bash

# Create a pod
docker exec -i vk8s kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.14.2
EOF

# List pods
docker exec vk8s kubectl get pods

# Clean up
docker rm -f vk8s
```

## Use in Go

```go
package xxx

import (
        "context"
        "testing"
        "time"

        "github.com/go-tk/vk8s"
        "k8s.io/client-go/kubernetes"
        "k8s.io/client-go/tools/clientcmd"
)

func TestXXX(t *testing.T) {
        kubeConfigData := vk8s.SetUp(context.Background(), 5*time.Minute, t)

        config, err := clientcmd.RESTConfigFromKubeConfig(kubeConfigData)
        if err != nil {
                t.Fatal(err)
        }

        clientset, err := kubernetes.NewForConfig(config)
        if err != nil {
                t.Fatal(err)
        }

        _ = clientset // Do anything you want to do with clientset
}
```
