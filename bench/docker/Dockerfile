# An image to run the benchmark on any Linux x64 box with Docker, e.g. a small VPS.
# Nim 2.4.0 from the official tarball (it ships nifler and nifmake, which are
# linked against musl), gcc 13 as in the cloud sessions, libblas for arraymancer.
# The repository is mounted at run time (bench/docker/run.sh), not copied in.
FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc libc6-dev git ca-certificates curl xz-utils musl libblas3 liblapack3 \
 && rm -rf /var/lib/apt/lists/*
ARG NIM_VERSION=2.4.0
RUN curl -fsSL -o /tmp/nim.tar.xz https://nim-lang.org/download/nim-${NIM_VERSION}-linux_x64.tar.xz \
 && curl -fsSL -o /tmp/nim.sha256 https://nim-lang.org/download/nim-${NIM_VERSION}-linux_x64.tar.xz.sha256 \
 && cd /tmp && echo "$(cut -d' ' -f1 nim.sha256)  nim.tar.xz" | sha256sum -c - \
 && tar -xJf /tmp/nim.tar.xz -C /opt && mv /opt/nim-${NIM_VERSION} /opt/nim && rm /tmp/nim.*
ENV PATH=/opt/nim/bin:$PATH NIM_LIB=/opt/nim/lib
WORKDIR /cicak
