# Kubernetes Build and Push Job

## 1. Overview

The `build-and-push-job.yaml` defines a Kubernetes Job that provides a flexible way to manage Docker images. It can perform one of two main actions based on the `JOB_TYPE` environment variable:

*   **Build and Push (`JOB_TYPE: "build_and_push"`):** Builds a Docker image from a provided build context (a `.tar.gz` file containing a Dockerfile and source code). The image is first pushed to an intermediate container registry, then copied to a final Harbor registry.
*   **Push Tarball (`JOB_TYPE: "push_tar"`):** Pushes a pre-built Docker image (provided as a `.tar` file accessible via a URL) directly to a final Harbor registry.

This allows for both CI/CD build pipelines and manual image promotions.

## 2. Prerequisites

Before running this Job, ensure the following are in place:

### 2.1. Kubernetes Secret for Harbor Authentication

The Job requires a Kubernetes Secret named `harbor-credentials` to authenticate with the target Harbor registry. This Secret must contain the Harbor `username` and `password`.

**Example `harbor-credentials` Secret:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: harbor-credentials
  namespace: default # Or the namespace where the Job will run
type: Opaque
stringData: # Using stringData for convenience; kubectl will encode it to base64
  username: "your-harbor-username"
  password: "your-harbor-password"
```

Apply this Secret to your Kubernetes cluster in the same namespace where the Job will be deployed.

### 2.2. Intermediate Registry (for `build_and_push` mode)

When the Job is run in `build_and_push` mode, the `image-builder` container (using Kaniko) requires an intermediate container registry to push the initially built image.
This registry must be accessible from within the Kubernetes cluster (e.g., `docker-registry.default.svc.cluster.local:5000`). The Job expects this registry to be available and does not handle its deployment.

## 3. Job Configuration (Environment Variables)

The Job's behavior is controlled by environment variables defined in the `build-and-push-job.yaml` under the `env` section of each container.

### 3.1. Common Environment Variables (Applicable to both `JOB_TYPE`s)

These variables need to be set regardless of the chosen `JOB_TYPE`.

*   **`JOB_TYPE`**:
    *   Description: Determines the operational mode of the Job.
    *   Values:
        *   `"build_and_push"`: Builds an image from context and pushes it.
        *   `"push_tar"`: Pushes a pre-built image tarball.
    *   Example: `build_and_push`

*   **`HARBOR_REGISTRY`**:
    *   Description: URL of the final Harbor registry.
    *   Example: `harbor.example.com`

*   **`HARBOR_PROJECT`**:
    *   Description: Project name within the Harbor registry.
    *   Example: `my-apps`

*   **`HARBOR_IMAGE_NAME`**:
    *   Description: Final name of the image in the Harbor registry.
    *   Example: `my-service`

*   **`HARBOR_IMAGE_TAG`**:
    *   Description: Final tag of the image in the Harbor registry.
    *   Example: `v1.0.2`

### 3.2. Variables for `JOB_TYPE: "build_and_push"`

These variables are required when `JOB_TYPE` is set to `build_and_push`.

*   **`BUILD_CONTEXT_URL`**:
    *   Description: URL to the build context tarball (`.tar.gz`) containing the Dockerfile and application source.
    *   Example: `http://artifactory.example.com/contexts/my-app-context-v1.0.2.tar.gz`

*   **`DOCKERFILE_PATH`**:
    *   Description: Path to the Dockerfile within the extracted build context.
    *   Default: `Dockerfile`
    *   Example: `build/Dockerfile.prod`

*   **`INTERMEDIATE_REGISTRY_URL`**:
    *   Description: URL of the intermediate container registry where Kaniko pushes the built image. This is often an in-cluster registry.
    *   Example: `docker-registry.default.svc.cluster.local:5000`

*   **`BUILD_IMAGE_NAME`**:
    *   Description: Name of the image in the intermediate registry.
    *   Example: `my-app-intermediate`

*   **`BUILD_IMAGE_TAG`**:
    *   Description: Tag of the image in the intermediate registry.
    *   Example: `build-123`

### 3.3. Variables for `JOB_TYPE: "push_tar"`

This variable is required when `JOB_TYPE` is set to `push_tar`.

*   **`IMAGE_TAR_URL`**:
    *   Description: URL to the pre-built image tarball (`.tar` file) to be pushed.
    *   Example: `http://artifactory.example.com/images/my-app-v1.0.2.tar`

## 4. Example Usage Scenarios

To use the Job, you typically modify the environment variables within the `build-and-push-job.yaml` file (or override them if your deployment method supports it) and then apply it to your Kubernetes cluster (e.g., `kubectl apply -f build-and-push-job.yaml`).

### 4.1. Building a New Image

To build an image from a Docker context and push it:

1.  Set `JOB_TYPE` to `"build_and_push"`.
2.  Configure `BUILD_CONTEXT_URL` to point to your context tarball.
3.  Set `DOCKERFILE_PATH` if your Dockerfile is not at the root of the context.
4.  Configure `INTERMEDIATE_REGISTRY_URL`, `BUILD_IMAGE_NAME`, and `BUILD_IMAGE_TAG` for the intermediate image.
5.  Configure `HARBOR_REGISTRY`, `HARBOR_PROJECT`, `HARBOR_IMAGE_NAME`, and `HARBOR_IMAGE_TAG` for the final destination.

**Example Snippet for `image-builder` env (partial):**
```yaml
env:
  - name: JOB_TYPE
    value: "build_and_push"
  - name: BUILD_CONTEXT_URL
    value: "http://my-jenkins/builds/my-app/context.tar.gz"
  - name: INTERMEDIATE_REGISTRY_URL
    value: "my-internal-registry:5000"
  - name: BUILD_IMAGE_NAME
    value: "temp-my-app"
  - name: BUILD_IMAGE_TAG
    value: "build-abc"
  # ... other common HARBOR_* vars
```
*(Ensure `skopeo-pusher` also has `JOB_TYPE` and its relevant HARBOR & intermediate vars set).*

### 4.2. Pushing an Existing Image Tarball

To push a pre-built image tarball:

1.  Set `JOB_TYPE` to `"push_tar"`.
2.  Configure `IMAGE_TAR_URL` to point to your image tarball.
3.  Configure `HARBOR_REGISTRY`, `HARBOR_PROJECT`, `HARBOR_IMAGE_NAME`, and `HARBOR_IMAGE_TAG` for the final destination.
4.  The `image-builder` container will skip its operations. The `skopeo-pusher` container will download and push the tarball.

**Example Snippet for `skopeo-pusher` env (partial):**
```yaml
env:
  - name: JOB_TYPE
    value: "push_tar"
  - name: IMAGE_TAR_URL
    value: "http://my-releases/my-app-v1.2.0.tar"
  # ... other common HARBOR_* vars
```
*(Ensure `image-builder` also has `JOB_TYPE` set to `push_tar`).*
