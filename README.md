# Kaniko Test

## Overview

This repository consists of a simple nginx [Dockerfile](./dockerfile) and [build](./build.sh) script to test building and pushing using Kaniko.

## Kaniko Status

Kaniko is a tool to build container images from a Dockerfile, inside a container or Kubernetes cluster. It does not depend on a Docker daemon and executes each command within a Dockerfile completely in userspace. Kaniko is designed to run in environments that cannot run a Docker daemon, such as a standard Kubernetes cluster.

> [!IMPORTANT]
> The Kaniko project used to be maintained by Google, but was archived in June of 2025. Luckily, Chainguard forked the project and is actively maintaining it.

The [Chainguard fork of Kaniko](https://github.com/chainguard-forks/kaniko) is actively maintained, however, you need to build and host your own kaniko images. More information can be found in the [Kaniko development documentation](https://github.com/chainguard-forks/kaniko/blob/main/DEVELOPMENT.md).

## Podman

This example uses Podman to run Kaniko in a rootless environment. In order to emulate complete rootless permissions, you need to use a rootless Podman machine. If you do not have one you can create one with:

```bash
podman machine init --cpus 8 --disk-size 50 --memory 32768 --now podman-machine-rootless
```

> [!NOTE]
> By excluding the `--rootful` flag above a rootless Podman machine is created

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

### Pod Security Standards (PSS)

Kubernetes Pod Security Standards (PSS) define three levels of security controls for pods: `restricted`, `baseline`, and `privileged`. Each level has specific requirements regarding permissions and capabilities. Here's a summary of how each level handles root access, capabilities, and privileged mode:

| Level | Allows Root | Allows Capabilities | Allows Privileged |
| --- | --- | --- | --- |
| restricted| ❌ | ❌ | ❌ |
| baseline | ✅ | Some | ❌ |
| privileged | ✅ | ✅ | ✅ |

> [!NOTE]
> Read more at the official Kubernetes documentation for [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/).

#### Catch

PSS "Restricted" checks `runAsNonRoot: true` at the spec level - it doesn't understand user namespaces. So even with `hostUsers: false`, you may still fail admission if your namespace enforces "Restricted". You'd need either:

- A namespace with "Baseline" enforcement
- A policy exception for hostUsers: false pods
- A custom admission policy (Kyverno/Gatekeeper) that allows root when hostUsers: false

#### Examples

Example Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kaniko-build
spec:
  hostUsers: false
  containers:
    - name: kaniko
      image: docker.io/smigula/kaniko-executor:latest
      args:
        - --context=/workspace
        - --dockerfile=Dockerfile
        - --no-push
        - --tarPath=/workspace/image.tar
        - --destination=test-image:latest
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
      volumeMounts:
        - name: workspace
          mountPath: /workspace
  volumes:
    - name: workspace
      emptyDir: {}
```

Example GitLab Runner:

- gitlab-runner configuration for user namespace kaniko builder:

```yaml
runners:
  config: |
    [[runners]]
      name = "kaniko-runner"
      executor = "kubernetes"
      [runners.kubernetes]
        namespace = "gitlab-runner"
        image = "docker.io/smigula/kaniko-executor:latest"
        pod_security_context = { host_users = false }

        build_container_security_context = {
          allow_privilege_escalation = false,
          capabilities = { drop = ["ALL"] }
        }

        # auth config for registry
        [[runners.kubernetes.volumes.secret]]
          name = "docker-config"
          mount_path = "/kaniko/.docker"
          secret_name = "kaniko-docker-config"
          read_only = true
```

- GitLab CI/CD configuration for building and pushing Docker images using Kaniko:

```yaml
stages:
  - build
build:
  stage: build
  image:
    name: docker.io/smigula/kaniko-executor:latest
    entrypoint: [""]
  script:
    - /kaniko/executor
      --context=$CI_PROJECT_DIR
      --dockerfile=$CI_PROJECT_DIR/Dockerfile
      --destination=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```
