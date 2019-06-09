variable "do_browsh_key" {}

module "cluster" {
  do_browsh_key = var.do_browsh_key
  source = "./cluster"
}

module "http-server" {
  source = "./http-server"
}

module "ssh-server" {
  source = "./ssh-server"
}
