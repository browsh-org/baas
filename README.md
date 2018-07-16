# Browsh As A Service

Terraform's current Kubernetes provider doesn't support ReplicaSets and Deployments.
For the latest news, see; https://github.com/terraform-providers/terraform-provider-kubernetes/issues/3

For now we can use this well-updated fork:
```bash
mkdir -p $GOPATH/src/github.com/sl1pm4t; cd $GOPATH/src/github.com/sl1pm4t
git clone https://github.com/sl1pm4t/terraform-provider-kubernetes
cd $GOPATH/src/github.com/sl1pm4t/terraform-provider-kubernetes
make build
cp $GOPATH/bin/terraform-provider-kubernetes $PROJECT_ROOT/.terraform/plugins/linux_amd64
```

Then patch at kubernetes/resource_kubernetes_deployment.go:375
```golang
if name == "browsh-http-server" || name == "browsh-ssh-server" {
  cmd := "echo '" + string(data) + "' | ruby patch_toleration.rb"
  output, err := exec.Command("bash", "-c", cmd).Output()
  if err != nil {
    panic("tombh hack failed")
  }
  data = output
}
```

After applying everything you also currently need to:
  1. Manually apply the Cluster Roles, see `nginx-ingress-controller.yaml`

SSL certs:
```
sudo certbot certonly -d '*.brow.sh' -d 'brow.sh' --dns-google --dns-google-credentials etc/gce-dns-admin.json --server https://acme-v02.api.letsencrypt.org/directory
sudo cp /etc/letsencrypt/live/brow.sh/cert.pem etc/browsh-tls.crt
sudo cp /etc/letsencrypt/live/brow.sh/privkey.pem etc/browsh-tls.key
terraform apply
```




