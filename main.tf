module "cluster" {
  source = "./cluster"
}

module "http-server" {
  source = "./http-server"
}

module "ssh-server" {
  source = "./ssh-server"
}
