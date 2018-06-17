##brow.sh Load Balancer
This needs to have a permanent IP. It will forward requests to any of;
  1. Static web site at https://www.brow.sh
  2. SSH server, ie; `ssh brow.sh`
  3. The HTTP Service - `https://text.brow.sh`

Can GKE or Kubernetes already do all these? Or do we need to create a custom app? It looks
like Ingress is the de facto way to achieve this

##SSH Server - 2GB RAM, ephemeral
Wrap the Browsh Docker image in another Docker image, so that each instance is its own SSH
server. Then for each new incoming connection make a query to a permanents store to see what
access the user has.

##SSH Browsh Instances - 2GB RAM, ephemeral
These can be run on pre-emptible nodes. The SSH server pill proxy connections to these
instances.

##HTTP Service - 2GB RAM, ephemeral

##Node Pools
https://nickcharlton.net/posts/kubernetes-terraform-google-cloud.html

First you need remove the default pool that GKE provides. Then probably create 2 node pools,
1 for the SSH Server and possible load balancer, then another 1 for 

GKE seems to exclusively support: auto repair, upgrade and scale! See: https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=8&ved=0ahUKEwjAhfmH3NHbAhUBlJQKHVCSAqMQFgh9MAc&url=https%3A%2F%2Fnickcharlton.net%2Fposts%2Fkubernetes-terraform-google-cloud.html&usg=AOvVaw1gE1VxU0nsENHNya2_YQrk

