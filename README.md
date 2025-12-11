# Kaniko Test

## Overview

This repository consists of a simple nginx [Dockerfile](./dockerfile) and [build](./build.sh) script to test building and pushing using Kaniko. 

## Podman

This example uses Podman to run Kaniko in a rootless environment. In order to emulate complete rootless permissions, you need to use a rootless Podman machine. If you do not have one you can create one with:

```bash
podman machine init --cpus 8 --disk-size 50 --memory 32768 --now podman-machine-rootless
```

> *NOTE*: By excluding the `--rootful` flag above a rootless Podman machine is created

Create a [Personal Access Token](https://hub.docker.com/settings/security) in Docker Hub in order to be able to push the image. If you export the environment variables `DOCKER_HUB_USERNAME` and `DOCKER_HUB_KANIKO_PAT` the script will use these, otherwise, the script will prompt you for this information, as well as image name and tag (with sensible defaults).

## Build and Push

Give the script executable permissions, and invoke it:

```bash
chmod +x build.sh
./build.sh
```

## Run Image

Finally, run the image:

```bash
podman run --rm -p 8080:8080 docker.io/$DOCKER_HUB_USERNAME/kaniko-nginx:$TAG
```

You should now be able to access the nginx welcome page at [http://localhost:8080](http://localhost:8080).

## Permissions

By default, Podman will map container UID/GID's to that of the user (UID/GID) running on the host machine. However, in order to prevent privilege escalation (acquiring more permissions), you must add the `--security-opt=no-new-privileges` flag. Moreover, you should drop all Linux capablities with the flag `--cap-drop=ALL` and add only those that are required. Here is a breakdown of the capabilities needed:

| Capability | Purpose| Justification |
| --- | --- | --- |
| `CAP_CHOWN` | Change file owner/group | Preserve ownership when extracting base image layers |
| `CAP_FOWNER` | Bypass permission checks based on file ownership | Modify files regardless of who owns them |
| `CAP_DAC_OVERRIDE` | Bypass read/write/execute permission checks | Access files with restrictive permissions in layers |

## Kubernetes

Starting in Kubernetes `v1.30` the option to run workloads in User Namespaces was added. This feature essentially isolates workloads running in Kubernetes from the host. You can read more about this feature in the [Kubernetes User Namespaces documentation](https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/).

*TODO*: Add instructions for building/pushing images in Kubernetes using GitLab Runner Kubernetes executor.
