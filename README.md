# Kubernetes Image Build and Push Jobs

This repository provides Kubernetes Job definitions for building and pushing Docker images. Three Job YAML files are available, each tailored for a specific workflow or operational model:

*   **`build-from-context-job.yaml`**: Builds a Docker image from a provided build context (a `.tar.gz` file containing a Dockerfile and source code). The image is first pushed to an intermediate container registry, then copied (promoted) to a final Harbor registry. This job uses separate containers for building and promoting.
*   **`push-tar-job.yaml`**: Pushes a pre-built Docker image (provided as a `.tar` file accessible via a URL) directly to a final Harbor registry. This job uses a single container focused on pushing.
*   **`unified-single-container-job.yaml`**: Provides a flexible, single main container approach. An init container determines the operational mode (`build_and_push` or `push_tar`) based on the `JOB_TYPE` environment variable. The main container, which must have all necessary tools (Kaniko, Skopeo, etc.), then executes the chosen action.

These Jobs facilitate both CI/CD build pipelines and manual image promotions.

## 1. Prerequisites

Before running these Jobs, ensure the following are in place:

### 1.1. Kubernetes Secret for Harbor Authentication

All Jobs require a Kubernetes Secret named `harbor-credentials` to authenticate with the target Harbor registry. This Secret must contain the Harbor `username` and `password`.

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

### 1.2. Intermediate Registry (for `build_from_context-job.yaml` and the "build" path of `unified-single-container-job.yaml`)

When using `build-from-context-job.yaml`, or when `unified-single-container-job.yaml` is operating in `build_and_push` mode, an intermediate container registry is required. The `image-builder` (or main container in the unified job) using Kaniko pushes the initially built image to this registry. This registry must be accessible from within the Kubernetes cluster (e.g., `docker-registry.default.svc.cluster.local:5000`). The Jobs expect this registry to be available and do not handle its deployment. This prerequisite is **not** required for `push-tar-job.yaml` or the "push_tar" path of `unified-single-container-job.yaml`.

## 2. Job Configurations (Environment Variables)

The behavior of each Job is controlled by environment variables defined within its respective YAML file.

### 2.1. Configuration for `build-from-context-job.yaml`

This Job uses two containers: `image-builder` and `skopeo-promoter`.

#### `image-builder` Container Environment Variables:

*   **`BUILD_CONTEXT_URL`**: URL to the build context tarball (`.tar.gz`).
*   **`DOCKERFILE_PATH`**: Path to the Dockerfile within the context. Default: `Dockerfile`.
*   **`INTERMEDIATE_REGISTRY_URL`**: URL of the intermediate registry.
*   **`BUILD_IMAGE_NAME`**: Name for the image in the intermediate registry.
*   **`BUILD_IMAGE_TAG`**: Tag for the image in the intermediate registry.

#### `skopeo-promoter` Container Environment Variables:

*   **`INTERMEDIATE_REGISTRY_URL`**: (Should match `image-builder`).
*   **`BUILD_IMAGE_NAME`**: (Should match `image-builder`).
*   **`BUILD_IMAGE_TAG`**: (Should match `image-builder`).
*   **`HARBOR_REGISTRY`**: URL of the final Harbor registry.
*   **`HARBOR_PROJECT`**: Project name in Harbor.
*   **`HARBOR_IMAGE_NAME`**: Final image name in Harbor.
*   **`HARBOR_IMAGE_TAG`**: Final image tag in Harbor.
*   **`HARBOR_USERNAME`**: (From Secret `harbor-credentials`, key `username`).
*   **`HARBOR_PASSWORD`**: (From Secret `harbor-credentials`, key `password`).

### 2.2. Configuration for `push-tar-job.yaml`

This Job uses one container: `skopeo-tar-pusher`.

#### `skopeo-tar-pusher` Container Environment Variables:

*   **`IMAGE_TAR_URL`**: URL to the pre-built image tarball (`.tar`).
*   **`HARBOR_REGISTRY`**: URL of the final Harbor registry.
*   **`HARBOR_PROJECT`**: Project name in Harbor.
*   **`HARBOR_IMAGE_NAME`**: Final image name in Harbor.
*   **`HARBOR_IMAGE_TAG`**: Final image tag in Harbor.
*   **`HARBOR_USERNAME`**: (From Secret `harbor-credentials`, key `username`).
*   **`HARBOR_PASSWORD`**: (From Secret `harbor-credentials`, key `password`).

## 3. Unified Single Container Job (`unified-single-container-job.yaml`)

### 3.1. Overview

The `unified-single-container-job.yaml` offers a flexible approach by using an init container to determine the operational mode and a single main container to execute the task. This main container must be equipped with all necessary tools (Kaniko, Skopeo, curl, wget, tar).

### 3.2. Combined Image Requirement

This Job requires a custom Docker image for its main container (e.g., placeholder `your-repo/kaniko-skopeo-tools:latest` in the YAML). This image must bundle:
*   Kaniko executor
*   Skopeo
*   curl
*   wget
*   tar

You are responsible for building and making this combined image available to your Kubernetes cluster.

### 3.3. Structure

*   **Init Container (`init-determine-action`):**
    *   Reads the `JOB_TYPE` environment variable.
    *   Based on `JOB_TYPE`, it writes an "action" string (`build` or `push_tar`) to a file on a shared `emptyDir` volume (`/pod-info/action_type`).
*   **Main Container (`main-task-executor`):**
    *   Reads the action string from `/pod-info/action_type`.
    *   Executes the corresponding logic (either building and promoting an image or downloading and pushing a tarball) using the tools available in its image.

### 3.4. Prerequisites

*   **`harbor-credentials` Secret:** As described in Section 1.1.
*   **Intermediate Registry:** Required if `JOB_TYPE` is set to `build_and_push` (see Section 1.2).
*   **Combined Docker Image:** The main container image must be available and include all necessary tools as mentioned in Section 3.2.

### 3.5. Job Configuration (Environment Variables)

#### Init Container (`init-determine-action`):

*   **`JOB_TYPE`**:
    *   Description: Determines the operational mode.
    *   Values: `"build_and_push"` or `"push_tar"`.
    *   Example: `build_and_push`

#### Main Container (`main-task-executor`):

This container uses a comprehensive set of environment variables. Depending on the action determined by the init container, only a subset will be actively used by the script.

*   **For the "build_and_push" path (`JOB_TYPE: "build_and_push"`):**
    *   `BUILD_CONTEXT_URL`: URL to the build context tarball (`.tar.gz`).
    *   `DOCKERFILE_PATH`: Path to the Dockerfile within the context. Default: `Dockerfile`.
    *   `INTERMEDIATE_REGISTRY_URL`: URL of the intermediate registry.
    *   `BUILD_IMAGE_NAME`: Name for the image in the intermediate registry.
    *   `BUILD_IMAGE_TAG`: Tag for the image in the intermediate registry.
    *   `HARBOR_REGISTRY`, `HARBOR_PROJECT`, `HARBOR_IMAGE_NAME`, `HARBOR_IMAGE_TAG`: For the final destination.
    *   `HARBOR_USERNAME`, `HARBOR_PASSWORD`: From secrets.
*   **For the "push_tar" path (`JOB_TYPE: "push_tar"`):**
    *   `IMAGE_TAR_URL`: URL to the pre-built image tarball (`.tar`).
    *   `HARBOR_REGISTRY`, `HARBOR_PROJECT`, `HARBOR_IMAGE_NAME`, `HARBOR_IMAGE_TAG`: For the final destination.
    *   `HARBOR_USERNAME`, `HARBOR_PASSWORD`: From secrets.

*(Refer to the `env` section in `unified-single-container-job.yaml` for example values. The script within the main container has checks for required variables based on the determined action.)*

## 4. Example Usage Scenarios

To use a Job, modify the relevant environment variables within its YAML file (or override them if your deployment method supports it) and then apply it to your Kubernetes cluster.

### 4.1. Using `build-from-context-job.yaml`

To build an image from a Docker context and push it:

1.  Open `build-from-context-job.yaml`.
2.  In the `image-builder` container's `env` section:
    *   Configure `BUILD_CONTEXT_URL`, `DOCKERFILE_PATH`, `INTERMEDIATE_REGISTRY_URL`, `BUILD_IMAGE_NAME`, `BUILD_IMAGE_TAG`.
3.  In the `skopeo-promoter` container's `env` section:
    *   Ensure `INTERMEDIATE_REGISTRY_URL`, `BUILD_IMAGE_NAME`, `BUILD_IMAGE_TAG` match.
    *   Configure `HARBOR_REGISTRY`, `HARBOR_PROJECT`, `HARBOR_IMAGE_NAME`, `HARBOR_IMAGE_TAG`.
4.  Apply: `kubectl apply -f build-from-context-job.yaml`

### 4.2. Using `push-tar-job.yaml`

To push a pre-built image tarball:

1.  Open `push-tar-job.yaml`.
2.  In the `skopeo-tar-pusher` container's `env` section:
    *   Configure `IMAGE_TAR_URL`, `HARBOR_REGISTRY`, `HARBOR_PROJECT`, `HARBOR_IMAGE_NAME`, `HARBOR_IMAGE_TAG`.
3.  Apply: `kubectl apply -f push-tar-job.yaml`

### 4.3. Using `unified-single-container-job.yaml`

1.  Open `unified-single-container-job.yaml`.
2.  In the `init-determine-action` container's `env` section:
    *   Set `JOB_TYPE` to either `"build_and_push"` or `"push_tar"`.
3.  In the `main-task-executor` container's `env` section, configure the relevant variables based on the chosen `JOB_TYPE`:
    *   If `JOB_TYPE` is `"build_and_push"`, set `BUILD_CONTEXT_URL`, `DOCKERFILE_PATH`, `INTERMEDIATE_REGISTRY_URL`, `BUILD_IMAGE_NAME`, `BUILD_IMAGE_TAG`, and all `HARBOR_*` variables.
    *   If `JOB_TYPE` is `"push_tar"`, set `IMAGE_TAR_URL` and all `HARBOR_*` variables.
4.  Ensure the `image` field for `main-task-executor` points to your custom image that bundles all required tools.
5.  Apply: `kubectl apply -f unified-single-container-job.yaml`
