package vk8s_test

import (
	"context"
	"testing"
	"time"

	"github.com/go-tk/vk8s"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

func TestExample(t *testing.T) {
	kubeConfigData := vk8s.SetUp(context.Background(), 5*time.Minute, t)

	config, err := clientcmd.RESTConfigFromKubeConfig(kubeConfigData)
	if err != nil {
		t.Fatal(err)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		t.Fatal(err)
	}

	deployment := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name: "demo-deployment",
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: func(i int32) *int32 { return &i }(2),
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app": "demo",
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app": "demo",
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "web",
							Image: "nginx:1.12",
						},
					},
				},
			},
		},
	}
	deployment, err = clientset.AppsV1().Deployments(corev1.NamespaceDefault).Create(context.Background(), deployment, metav1.CreateOptions{})
	if err != nil {
		t.Fatal(err)
	}

	watch, err := clientset.CoreV1().Pods(corev1.NamespaceDefault).Watch(context.Background(), metav1.ListOptions{})
	if err != nil {
		t.Fatal(err)
	}
	defer watch.Stop()

	event := <-watch.ResultChan()
	t.Logf("event: %s pod %s", event.Type, event.Object.(*corev1.Pod).Name)
}
