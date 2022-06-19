package vk8s

import (
	"archive/tar"
	"context"
	"fmt"
	"io"
	"io/ioutil"
	"testing"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/client"
)

const image = "ghcr.io/go-tk/vk8s:v0.0.1"

// SetUp sets up a virtual Kubernetes cluster and returns the data of kube-config to access it.
func SetUp(ctx context.Context, timeToLive time.Duration, t *testing.T) []byte {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		t.Fatal(err)
	}

	{
		if _, _, err := cli.ImageInspectWithRaw(ctx, image); client.IsErrNotFound(err) {
			t.Log("pull image")
			out, err := cli.ImagePull(ctx, image, types.ImagePullOptions{})
			if err != nil {
				t.Fatal(err)
			}
			defer out.Close()
			io.Copy(io.Discard, out)
		} else {
			if err != nil {
				t.Fatal(err)
			}
		}
	}

	var containerID string
	{
		t.Log("run container")
		resp, err := cli.ContainerCreate(
			ctx,
			&container.Config{
				Image: image,
				Env: []string{
					fmt.Sprintf("TTL=%d", timeToLive/time.Second),
				},
			},
			&container.HostConfig{
				AutoRemove: true,
			},
			nil,
			nil,
			"")
		if err != nil {
			t.Fatal(err)
		}
		containerID = resp.ID
		defer func() {
			cleanup := func() {
				t.Log("remove container")
				if err := cli.ContainerRemove(context.Background(), containerID, types.ContainerRemoveOptions{
					RemoveVolumes: true,
					Force:         true,
				}); err != nil {
					t.Logf("failed to remove container: %v", err)
				}
			}
			if t.Failed() {
				cleanup()
			} else {
				t.Cleanup(cleanup)
			}
		}()
		if err := cli.ContainerStart(ctx, containerID, types.ContainerStartOptions{}); err != nil {
			t.Fatal(err)
		}
	}

	{
		t.Log("wait for ready")
		resp, err := cli.ContainerExecCreate(ctx, containerID, types.ExecConfig{
			Cmd:          []string{"./wait-for-ready.bash"},
			AttachStderr: true,
			AttachStdout: true,
		})
		if err != nil {
			t.Fatal(err)
		}
		execID := resp.ID
		resp2, err := cli.ContainerExecAttach(ctx, execID, types.ExecStartCheck{})
		if err != nil {
			t.Fatal(err)
		}
		defer resp2.Close()
		io.Copy(io.Discard, resp2.Reader)
	}

	var kubeConfigData []byte
	{
		t.Log("extract kube-config data")
		out, _, err := cli.CopyFromContainer(ctx, containerID, "/vk8s/lib/admin.kubeconfig")
		if err != nil {
			t.Fatal(err)
		}
		defer out.Close()
		tr := tar.NewReader(out)
		if _, err := tr.Next(); err != nil {
			t.Fatal(err)
		}
		kubeConfigData, err = ioutil.ReadAll(tr)
		if err != nil {
			t.Fatal(err)
		}
	}

	return kubeConfigData
}
