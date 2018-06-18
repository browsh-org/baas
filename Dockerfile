# First build our custom SSH server
# The Browsh SSH server is a custom Go server that launches Browsh upon a successful
# SSH connection.
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
ADD ssh-server/ $GOPATH/src/browsh_ssh_server

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
RUN go build -o browsh-ssh-server ssh-server.go

# Now wrap the SSH server image around the original Browsh Docker image
FROM tombh/texttop:v1.1.0

# Copy the SSH server built in the previous stage.
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
      libprotobuf10 \
      gnupg \
      netcat

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8

# Logging client for Google's Stackdriver logging service
RUN curl -L -o /usr/local/bin/gcloud_logger https://github.com/tombh/gcloud_pipe_logger/releases/download/v0.0.5/gcloud_pipe_logger_0.0.5_linux_amd64
RUN chmod a+x /usr/local/bin/gcloud_logger

# A small script to launch a Browsh session once a user connects via SSH
ADD ssh-server/start-browsh-session.sh /usr/local/bin/

ADD ssh-server/browsh-ssh-server /usr/local/bin/

CMD ["browsh-ssh-server"] # && tailf /app/debug.log
