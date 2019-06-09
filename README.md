# Browsh As A Service

## Setup

Install `doctl` and `kubectl`. Then:

  `doctl kubernetes cluster kubeconfig save browsh`

## SSL certs
```
sudo certbot certonly -d '*.brow.sh' -d 'brow.sh' --dns-google --dns-google-credentials etc/gce-dns-admin.json --server https://acme-v02.api.letsencrypt.org/directory
sudo cp /etc/letsencrypt/live/brow.sh/cert.pem etc/browsh-tls.crt
sudo cp /etc/letsencrypt/live/brow.sh/privkey.pem etc/browsh-tls.key
terraform apply
```




