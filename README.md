# Monit as PID 1 in Docker

This repository runs [Monit](https://mmonit.com/monit/) as the init process (PID 1) of a Docker container, with step-by-step tests that show zombie processes being reaped, a crashed service being restarted and Monit handling the container shutdown.

## Why Monit as PID 1

The first process in a container runs as PID 1. Orphaned processes are re-parented to it, and it must reap them when they exit, or they remain as zombies. It also receives only the signals it has a handler for, so a program without a SIGTERM handler does not react to `docker stop`. Many applications are not written for this, which is why containers often add a minimal init such as tini or dumb-init.

Monit 5.35.0 and later does this work itself: it reaps every child process, and on SIGTERM it stops all services with their stop programs, in reverse dependency order, before it exits.

Unlike tini and dumb-init, Monit also supervises the services:

- It restarts a service when its process dies, when it stops answering on its port, or when it uses too much memory or CPU.
- It starts services in dependency order, and restarts dependent services together with the service they depend on.
- It runs scheduled jobs with cron syntax and checks their exit status, so the container needs no cron daemon.
- It sends alerts by email or through a script of your choice, and it can report to [M/Monit](https://mmonit.com/), which shows all your Monit instances in one place.
- It has a web interface and a command line for status, start, stop and restart.

A container that runs several services therefore needs no extra init, supervisor or cron daemon. The tests below show some of this at work.

More background and a monitrc example: [Monit as PID 1 in a container](https://mmonit.com/wiki/Monit/Container) on the Monit wiki.

## What's in the repository

- `Dockerfile` fetches and builds the current Monit source on Debian, and starts Monit as PID 1 with `monit -I`.
- `monitrc` is the test configuration, with a 3-second cycle and the web interface on port 2812. It has a program check, a process check, a system check and a zombie check.
- `scripts/program.sh` is run by the program check. It logs any zombie processes it finds, sleeps 10 seconds and exits.
- `scripts/process.sh` starts the long-running process that the process check watches through `/tmp/process.pid`.
- `scripts/check_zombies.sh` prints Monit's status and counts zombie processes. The zombie check runs it every 5 cycles.

The scripts and alert actions log to `/results` in the container.

## Requirements

Docker: Docker Desktop on macOS and Windows, or Docker Engine on Linux. See [Get Docker](https://docs.docker.com/get-started/get-docker/).

## Running the tests

### 1. Build the image

```bash
git clone https://github.com/MMonit/monit-docker-test.git
cd monit-docker-test
docker build --no-cache -t monit-test .
```

The build fetches and compiles the current Monit source, and `--no-cache` keeps Docker from reusing an earlier build. For production images, install a pre-built Monit binary instead, as the note in the Dockerfile describes.

### 2. Start the container

```bash
docker run -d --name monit-container -p 2812:2812 monit-test
```

Monit's web interface is now at http://localhost:2812, where you can follow the tests below. If a container with this name is left from an earlier run, remove it first with `docker rm -f monit-container`.

### 3. Check that Monit is PID 1

```bash
docker exec monit-container ps -p 1 -o comm=
```

The output is `monit`.

### 4. Check the services

```bash
docker exec monit-container monit summary
```

`check_zombies.sh` prints the same summary, the number of zombie processes and the latest log entries of the scripts:

```bash
docker exec monit-container /usr/local/bin/check_zombies.sh
```

### 5. Zombie reaping

Each `(sleep 1 &)` below starts a process whose parent exits at once, so the process is re-parented to PID 1. When it ends a second later, only PID 1 can reap it:

```bash
docker exec monit-container bash -c 'for i in {1..10}; do (sleep 1 &); done; sleep 3; ps -eo stat= | grep -c "^Z"'
```

The output is `0`: Monit has reaped all ten. For comparison, run the same test in a container where `sleep` is PID 1:

```bash
docker run -d --name no-init --entrypoint sleep monit-test infinity
docker exec no-init bash -c 'for i in {1..10}; do (sleep 1 &); done; sleep 3; ps -eo stat= | grep -c "^Z"'
docker rm -f no-init
```

Here the output is `10`. Nothing reaps the processes, and they stay zombies until the container is removed.

### 6. Service restart

Kill the monitored process as if it had crashed, and read its PID again ten seconds later:

```bash
docker exec monit-container bash -c 'cat /tmp/process.pid; kill -9 $(cat /tmp/process.pid); sleep 10; cat /tmp/process.pid'
```

The second PID is a new one: Monit found the process gone and started it again. `docker logs monit-container` shows the restart.

### 7. Resource usage

To see how little CPU and memory Monit uses:

```bash
docker exec monit-container ps -o pid,pcpu,pmem,rss,cmd -p 1
```

Expect a CPU share near zero and about 8 MB of resident memory.

### 8. Shutdown

```bash
docker stop monit-container
docker logs monit-container 2>&1 | grep -E "shutdown|stopped"
docker inspect -f '{{.State.ExitCode}}' monit-container
```

`docker stop` returns in about a second. Among the log lines are:

```
Monit running as PID 1, performing init shutdown responsibilities
Monit daemon with pid [1] stopped
```

The exit code is `0`: Monit stopped the services and then exited on its own. A container whose PID 1 ignores SIGTERM ends with `137` instead, killed by Docker when the stop timeout runs out.

### 9. Clean up

```bash
docker rm -f monit-container
docker rmi monit-test
```

## Troubleshooting

If the container exits right after it starts, `docker logs monit-container` shows why. To check the syntax of the control file:

```bash
docker run --rm monit-test -t
```
