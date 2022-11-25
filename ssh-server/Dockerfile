# Allow the Browsh image version to be injected via the command line during build
ARG BROWSH_IMAGE_TAG

# First build our custom SSH server
# The Browsh SSH server is a custom Go server that launches Browsh upon a successful
# SSH connection.
FROM bitnami/minideb:bullseye

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
ADD . $GOPATH/src/browsh_ssh_server
RUN dep ensure
RUN go build -o browsh-ssh-server ssh-server.go

# Now wrap the SSH server image around the original Browsh Docker image
FROM browsh/browsh:v1.8.0

# Copy the SSH server built in the previous stage.
COPY --from=0 /go/src/browsh_ssh_server/browsh-ssh-server /usr/local/bin
COPY --from=0 /usr/local/bin/mosh-server /usr/local/bin

USER root
RUN install_packages \
      xvfb \
      libgtk-3-0 \
      curl \
      ca-certificates \
      libdbus-glib-1-2 \
      procps \
      libasound2 \
      libxtst6

USER user
ADD start-browsh-session.sh /usr/local/bin/
RUN ln -s /app/bin/browsh /app/browsh; ln -s /app/bin/firefox /app/firefox
RUN touch /app/debug.log && echo "Browsh logs start" > /app/debug.log

# Firefox behaves quite differently to normal on its first run, so by getting
# that over and done with here when there's no user to be dissapointed means
# that all future runs will be consistent.
RUN TERM=xterm script \
  --return \
  -c "/app/bin/browsh" \
  /dev/null \
  >/dev/null & \
  sleep 10

CMD browsh-ssh-server -host-key /etc/browsh/id_rsa & touch /app/debug.log && tail -f /app/debug.log
