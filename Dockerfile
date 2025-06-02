FROM debian:bullseye-slim

# NOTE: This Dockerfile builds Monit from source for testing purposes.
# For production use, download a pre-built Monit binary to significantly reduce
# the container size and avoid including build dependencies. Consider using
# Alpine Linux as the base image for even smaller containers.
# See https://mmonit.com/monit/#download

# Install necessary packages for building Monit (SSL and Pam are optional)
RUN apt-get update && \
    apt-get install -y \
    zlib1g-dev \
    libpam0g-dev \
    libssl-dev \
    libtool \
    bison \
    flex \
    autoconf \
    gcc \
    make \
    git \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Clone and build the latest Monit
WORKDIR /tmp
RUN git clone https://bitbucket.org/tildeslash/monit.git && \
    cd monit && \
    ./bootstrap && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm -rf monit

# Create directories
RUN mkdir -p /var/lib/monit /usr/local/bin /var/log

# Copy the test scripts
COPY scripts/program.sh /usr/local/bin/
COPY scripts/process.sh /usr/local/bin/
COPY scripts/check_zombies.sh /usr/local/bin/
COPY monitrc /etc/monitrc

# Set proper permissions for monitrc (required by Monit)
RUN chmod 600 /etc/monitrc

# Make scripts executable
RUN chmod +x /usr/local/bin/*.sh

# Create a directory for result files
RUN mkdir -p /results

# Expose port if you want to use the web interface
EXPOSE 2812

# Set Monit as the entrypoint (PID 1)
ENTRYPOINT ["/usr/local/bin/monit", "-I", "-c", "/etc/monitrc"]
