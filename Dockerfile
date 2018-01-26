FROM bitnami/minideb:stretch

RUN install_packages curl docker openssh-server nginx-light
RUN curl -L https://github.com/docker/machine/releases/download/v0.13.0/docker-machine-`uname -s`-`uname -m` >/tmp/docker-machine
RUN cp /tmp/docker-machine /usr/local/bin/docker-machine

ADD swarm-defaults.conf /etc/browsh-swarm-defaults.conf
ADD nginx.conf /etc/nginx/sites-available/default
ADD swarm-service.conf /etc/init/
ADD swarm-manager.sh /usr/local/bin/
