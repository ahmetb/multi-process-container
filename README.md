# Sample multi-process container with s6-overlay

Normally, you should run one process per container for many good reasons.
However, sometimes you need two services running next to each other.

This repository is a sample Docker image that uses [s6-overlay] that is [s6]
optimized for containers as the [init process] as the container’s `ENTRYPOINT`.

Once the container started, it will run `/init` as its `ENTRYPOINT`, which will
scan `/etc/services.d/`for sub-directories defining the services like this:

```text
/etc
└── services.d/
    ├── service1/
    │   ├── run     # starts a python web server
    │   └── finish  # runs when service1 terminates
    └── service2/
        ├── run     # starts command "sleep 99999999"
        └── finish  # runs when service2 terminates
```

- `run` file is a small bash script that starts the service
- `finish` file runs when the service terminates. This is where you decide
  whether the container should terminate when the service dies, or should `s6`
  restart the process.

### Review: example `run` script

This script starts your service in the foreground (not like a daemon):

```sh
#!/usr/bin/with-contenv sh
echo >&2 "starting service1"
exec python -m http.server "${PORT:-8080}"
```

Note we used `#!/usr/bin/with-contenv sh` (or `... bash`). This helps us
[inherit environment variables][env] of the container.

If you don't do that and do your usual
`#!/bin/bash` (or even `#!/usr/bin/env bash`) etc, you will get fewer
environment variables. (You can also run the container with  `S6_KEEP_ENV=1`
environment variable to avoid using `with-contenv`.)

The `exec ...` command starts the long-running service process in the foreground
and most importantly, `exec` **replaces the current shell process** so that
our service is directly managed by `s6-supervise` (without `sh`/`bash` as its
parent process).

### Review: example `finish`  script

This command gets the exit code of the `run` script as `$1` argument. When the
service terminates, you can do either of these things

- Terminate the container and kill the other service: see example below.
- Have the service restarted by s6: either delete the `finish` script or don't
  use any commands like below that terminates the init process.

```sh
#!/usr/bin/env sh
echo >&2 "service1 exited. code=${1}"

# terminate other services to exit from the container
exec s6-svscanctl -t /var/run/s6/services
```

## Try it out

```sh
docker build -t test-image .
docker run --rm -i -t --name=test test-image
```

On another terminal, run `docker exec test pstree` which will show the process
tree inside the container with service1 (`python`) and service2 (`sleep`):

```text
s6-svscan-+-s6-supervise
          |-s6-supervise---python
          `-s6-supervise---sleep
```

Similarly, you can send a graceful termination signal `SIGTERM` to the container
and have both services terminate and their `finish` script runs:

```sh
docker kill --signal=TERM test
```

```text
service1 exited. code=256
service2 exited. code=256
[cont-finish.d] executing container finish scripts...
[cont-finish.d] done.
[s6-finish] sending all processes the TERM signal.
[s6-finish] sending all processes the KILL signal and exiting.
```

## Learn more

Hope you can use this sample to build containers that reliably run multiple
processes in production. Remember, you should avoid doing this and split your
processes into multiple containers as much as possible.

You can learn more at [s6-overlay] repository which has a great user manual. The
[s6] project page goes into more technical details.

[s6-overlay]: https://github.com/just-containers/s6-overlay
[s6]: https://skarnet.org/software/s6/
[init process]: https://en.wikipedia.org/wiki/Init
[env]: https://github.com/just-containers/s6-overlay#container-environment
