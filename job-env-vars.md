# Required Environment Variables for the Kubernetes Job

This document lists all the environment variables that need to be configured for the Kubernetes Job, which includes the `image-builder` and `skopeo-pusher` containers.

## 1. `image-builder` Container

These variables are used by the Kaniko container to build the Docker image.

-   **`BUILD_CONTEXT_URL`**:
    -   Description: URL to the build context tarball (e.g., a `.tar.gz` file).
    -   Example: `http://example.com/my-app-context.tar.gz`

-   **`DOCKERFILE_PATH`**:
    -   Description: Path to the Dockerfile within the build context.
    -   Example: `Dockerfile.prod` (If not set, the Kaniko script defaults to `Dockerfile`)

-   **`BUILD_IMAGE_NAME`**:
    -   Description: Name of the image to be built by Kaniko. This is used internally before pushing to the final destination.
    -   Example: `my-app-built`

-   **`BUILD_IMAGE_TAG`**:
    -   Description: Tag for the image built by Kaniko.
    -   Example: `latest`

## 2. `skopeo-pusher` Container

These variables are used by the Skopeo container to push the built image to a Harbor registry.

-   **`HARBOR_REGISTRY`**:
    -   Description: The address of the Harbor registry.
    -   Example: `dockerhub.kubekey.local`

-   **`HARBOR_PROJECT`**:
    -   Description: The project within Harbor where the image will be pushed.
    -   Example: `user/cve`

-   **`HARBOR_IMAGE_NAME`**:
    -   Description: The final name for the image in the Harbor registry.
    -   Example: `my-app-final`

-   **`HARBOR_IMAGE_TAG`**:
    -   Description: The final tag for the image in the Harbor registry.
    -   Example: `v1.2.3`

-   **`HARBOR_USERNAME`**:
    -   Description: Username for authenticating with the Harbor registry.
    -   Example: `admin`

-   **`HARBOR_PASSWORD`**:
    -   Description: Password for authenticating with the Harbor registry.
    -   Example: `Harbor12345`
