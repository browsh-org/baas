#Browsh As A Service

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

Then when initialising Terraform, use:
`terraform init `
