# First build our custom SSH server
FROM bitnami/minideb:stretch

RUN install_packages \
      curl \
      ca-certificates \
      git \
      autoconf \
      automake \
      g++ \
      protobuf-compiler \
      zlib1g-dev \
      libncurses5-dev \
      libssl-dev \
      pkg-config \
      libprotobuf-dev \
      make

# Install Golang to build the custom Browsh SSH server
ENV GOPATH=/go
ENV GOROOT=$GOPATH
ENV PATH=$GOPATH/bin:$PATH
RUN curl -L -o go.tar.gz https://dl.google.com/go/go1.9.2.linux-amd64.tar.gz
RUN mkdir -p $GOPATH/bin
RUN mkdir -p $GOPATH/src/browsh_ssh_server
RUN tar -C / -xzf go.tar.gz
ADD browsh-ssh-server.go $GOPATH/src/browsh_ssh_server
ADD Gopkg.toml $GOPATH/src/browsh_ssh_server
ADD Gopkg.lock $GOPATH/src/browsh_ssh_server

# Install a bleeding edge version of Mosh for true colour support
RUN git clone https://github.com/mobile-shell/mosh
RUN cd mosh && git checkout 10dca75fb21ce2e3b
RUN cd mosh && ./autogen.sh && ./configure && make && make install

# Install `dep` the current defacto dependency manager for Golang
ENV GOLANG_DEP_VERSION=0.3.2
ENV dep_url=https://github.com/golang/dep/releases/download/v$GOLANG_DEP_VERSION/dep-linux-amd64
RUN curl -L -o $GOPATH/bin/dep $dep_url
RUN chmod +x $GOPATH/bin/dep
WORKDIR $GOPATH/src/browsh_ssh_server
RUN dep ensure
RUN go build -o browsh-ssh-server browsh-ssh-server.go


FROM bitnami/minideb:stretch
ENV GOOGLE_APPLICATION_CREDENTIALS=/etc/browsh/.gce.json

# Copy the SSH server built in the previous stage.
# The Browsh SSH server is a custom Go server that simply launches a Browsh
# Docker container through a Swarm. It does not have any authentication at all.
COPY --from=0 /go/src/browsh_ssh_server/browsh-ssh-server /usr/local/bin
COPY --from=0 /usr/local/bin/mosh-server /usr/local/bin

# So that we don't run the Browsh session as root
RUN useradd -m user

RUN install_packages \
      locales \
      curl \
      uuid-runtime \
      htop \
      ca-certificates \
      nginx-light \
      iptables \
      libapparmor1 \
      libseccomp2 \
      libdevmapper1.02.1 \
      libltdl7 \
      libprotobuf10 \
      gnupg \
      netcat
RUN curl -o docker.deb https://download.docker.com/linux/debian/dists/stretch/pool/stable/amd64/docker-ce_17.12.0~ce-0~debian_amd64.deb
RUN dpkg -i docker.deb
RUN usermod -aG docker user
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8

# Logging client for Google's Stackdriver logging service
RUN curl -L -o /usr/local/bin/gcloud_logger https://github.com/tombh/gcloud_pipe_logger/releases/download/v0.0.5/gcloud_pipe_logger_0.0.5_linux_amd64
RUN chmod a+x /usr/local/bin/gcloud_logger

# Docker Machine provisions actual VMs
RUN curl -L https://github.com/docker/machine/releases/download/v0.13.0/docker-machine-`uname -s`-`uname -m` >/tmp/docker-machine
RUN cp /tmp/docker-machine /usr/local/bin/docker-machine
RUN chmod a+x /usr/local/bin/docker-machine

# Very simple HTTP server to redirect all HTTP traffic to https://www.brow.sh
ADD nginx.conf /etc/nginx/sites-available/default

# The Swarm Manager ensures there are always X number of nodes in the cluster
ADD swarm-manager.sh /usr/local/bin/

# A small script to launch a Browsh session once a user connects via SSH
ADD start-browsh-session.sh /usr/local/bin/

# Launch HTTP, SSH and the Swarm Manager daemon
ADD boot.sh /usr/local/bin/

ADD browsh-ssh-server /usr/local/bin/

CMD ["boot.sh"]
