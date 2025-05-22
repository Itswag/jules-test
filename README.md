# Kubernetes Image Build and Push Jobs

This repository provides Kubernetes Job definitions for building and pushing Docker images. Two separate Job YAML files are available, each tailored for a specific workflow:

*   **`build-from-context-job.yaml`**: Builds a Docker image from a provided build context (a `.tar.gz` file containing a Dockerfile and source code). The image is first pushed to an intermediate container registry, then copied (promoted) to a final Harbor registry.
*   **`push-tar-job.yaml`**: Pushes a pre-built Docker image (provided as a `.tar` file accessible via a URL) directly to a final Harbor registry.

These Jobs facilitate both CI/CD build pipelines and manual image promotions.

## 1. Prerequisites

Before running these Jobs, ensure the following are in place:

### 1.1. Kubernetes Secret for Harbor Authentication

Both Jobs require a Kubernetes Secret named `harbor-credentials` to authenticate with the target Harbor registry. This Secret must contain the Harbor `username` and `password`.

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

### 1.2. Intermediate Registry (for `build-from-context-job.yaml`)

When using `build-from-context-job.yaml`, the `image-builder` container (using Kaniko) requires an intermediate container registry to push the initially built image. This registry must be accessible from within the Kubernetes cluster (e.g., `docker-registry.default.svc.cluster.local:5000`). The Job expects this registry to be available and does not handle its deployment. This prerequisite is **not** required for `push-tar-job.yaml`.

## 2. Job Configurations (Environment Variables)

The behavior of each Job is controlled by environment variables defined within its respective YAML file.

### 2.1. Configuration for `build-from-context-job.yaml`

This Job uses two containers: `image-builder` and `skopeo-promoter`.

#### `image-builder` Container Environment Variables:

*   **`BUILD_CONTEXT_URL`**:
    *   Description: URL to the build context tarball (`.tar.gz`) containing the Dockerfile and application source.
    *   Example: `http://artifactory.example.com/contexts/my-app-context-v1.0.2.tar.gz`
*   **`DOCKERFILE_PATH`**:
    *   Description: Path to the Dockerfile within the extracted build context.
    *   Default: `Dockerfile` (as defined in the Kaniko script)
    *   Example: `build/Dockerfile.prod`
*   **`INTERMEDIATE_REGISTRY_URL`**:
    *   Description: URL of the intermediate container registry where Kaniko pushes the built image.
    *   Example: `docker-registry.default.svc.cluster.local:5000`
*   **`BUILD_IMAGE_NAME`**:
    *   Description: Name of the image in the intermediate registry.
    *   Example: `my-app-intermediate`
*   **`BUILD_IMAGE_TAG`**:
    *   Description: Tag of the image in the intermediate registry.
    *   Example: `build-123`

#### `skopeo-promoter` Container Environment Variables:

*   **`INTERMEDIATE_REGISTRY_URL`**: (Should match `image-builder`)
    *   Description: URL of the intermediate container registry from which to pull the image.
    *   Example: `docker-registry.default.svc.cluster.local:5000`
*   **`BUILD_IMAGE_NAME`**: (Should match `image-builder`)
    *   Description: Name of the image in the intermediate registry.
    *   Example: `my-app-intermediate`
*   **`BUILD_IMAGE_TAG`**: (Should match `image-builder`)
    *   Description: Tag of the image in the intermediate registry.
    *   Example: `build-123`
*   **`HARBOR_REGISTRY`**:
    *   Description: URL of the final Harbor registry.
    *   Example: `harbor.example.com`
*   **`HARBOR_PROJECT`**:
    *   Description: Project name within the Harbor registry.
    *   Example: `my-apps`
*   **`HARBOR_IMAGE_NAME`**:
    *   Description: Final name for the image in the Harbor registry.
    *   Example: `my-service`
*   **`HARBOR_IMAGE_TAG`**:
    *   Description: Final tag for the image in the Harbor registry.
    *   Example: `v1.0.2`
*   **`HARBOR_USERNAME`**: (From Secret `harbor-credentials`, key `username`)
*   **`HARBOR_PASSWORD`**: (From Secret `harbor-credentials`, key `password`)

### 2.2. Configuration for `push-tar-job.yaml`

This Job uses one container: `skopeo-tar-pusher`.

#### `skopeo-tar-pusher` Container Environment Variables:

*   **`IMAGE_TAR_URL`**:
    *   Description: URL to the pre-built image tarball (`.tar` file) to be pushed.
    *   Example: `http://artifactory.example.com/images/my-app-v1.0.2.tar`
*   **`HARBOR_REGISTRY`**:
    *   Description: URL of the final Harbor registry.
    *   Example: `harbor.example.com`
*   **`HARBOR_PROJECT`**:
    *   Description: Project name within the Harbor registry.
    *   Example: `my-apps`
*   **`HARBOR_IMAGE_NAME`**:
    *   Description: Final name for the image in the Harbor registry.
    *   Example: `my-service`
*   **`HARBOR_IMAGE_TAG`**:
    *   Description: Final tag for the image in the Harbor registry.
    *   Example: `v1.0.2`
*   **`HARBOR_USERNAME`**: (From Secret `harbor-credentials`, key `username`)
*   **`HARBOR_PASSWORD`**: (From Secret `harbor-credentials`, key `password`)

## 3. Example Usage Scenarios

To use a Job, modify the relevant environment variables within its YAML file (or override them if your deployment method supports it) and then apply it to your Kubernetes cluster.

### 3.1. Using `build-from-context-job.yaml`

To build an image from a Docker context and push it:

1.  Open `build-from-context-job.yaml`.
2.  In the `image-builder` container's `env` section:
    *   Configure `BUILD_CONTEXT_URL` to point to your context tarball.
    *   Set `DOCKERFILE_PATH` if your Dockerfile is not at the root of the context.
    *   Configure `INTERMEDIATE_REGISTRY_URL`, `BUILD_IMAGE_NAME`, and `BUILD_IMAGE_TAG`.
3.  In the `skopeo-promoter` container's `env` section:
    *   Ensure `INTERMEDIATE_REGISTRY_URL`, `BUILD_IMAGE_NAME`, and `BUILD_IMAGE_TAG` match the `image-builder` values.
    *   Configure `HARBOR_REGISTRY`, `HARBOR_PROJECT`, `HARBOR_IMAGE_NAME`, and `HARBOR_IMAGE_TAG` for the final destination.
4.  Apply the Job: `kubectl apply -f build-from-context-job.yaml`

### 3.2. Using `push-tar-job.yaml`

To push a pre-built image tarball:

1.  Open `push-tar-job.yaml`.
2.  In the `skopeo-tar-pusher` container's `env` section:
    *   Configure `IMAGE_TAR_URL` to point to your image tarball.
    *   Configure `HARBOR_REGISTRY`, `HARBOR_PROJECT`, `HARBOR_IMAGE_NAME`, and `HARBOR_IMAGE_TAG` for the final destination.
3.  Apply the Job: `kubectl apply -f push-tar-job.yaml`
