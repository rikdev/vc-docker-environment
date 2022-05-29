# vc-docker-environment

Docker image for Microsoft C/C++ Compiler.

## How to use this image

In the simplest case, you can just run the Docker container:

```sh
docker run --rm -it vc-docker-environment
```

In the container you can clone a Git repository with source code and build it.

If the source code is located on the host file system or in a Docker volume, you can mount it in to container:

```sh
docker run --rm -it -v "path_to_source":"C:\source" vc-docker-environment
```

If you use the ccache, you should mount the `C:\.ccache` directory from the Docker container to a persistent storage:

```sh
docker run --rm -it -v "path_to_ccache_storage":"C:\.ccache" vc-docker-environment
```

You can store the file `ccache.conf` with settings for ccache in this storage.

If you use the Conan, you should mount the `C:\.conan` directory from the Docker container to a persistent storage:

```sh
docker run --rm -it -v "path_to_conan_storage":"C:\.conan" vc-docker-environment
```
