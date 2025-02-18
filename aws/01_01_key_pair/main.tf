provider "aws" {
  region = "eu-west-3"
}

variable "project_name" {
  type    = string
  default = "profe"
}

variable "ssh_key_path" {
  type = string
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key-ubuntu-${var.project_name}-test"
  public_key = file(var.ssh_key_path)
  # public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC01HxT+B4WAs0K7FSWvLRrgbdQkvGD+IJkXsCq26Hev usersad\sortiziz@NTTD-DBN36J3"
}

resource "aws_key_pair" "deployer2" {
  key_name   = "deployer-key-ubuntu-${var.project_name}-test2"
  public_key = file(var.ssh_key_path)
  # public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC01HxT+B4WAs0K7FSWvLRrgbdQkvGD+IJkXsCq26Hev usersad\sortiziz@NTTD-DBN36J3"
}

output "ssh_key_name" {
  value = "Clave creada ${aws_key_pair.deployer.key_name}"
}
output "ssh_key_name2" {
  value = "Clave creada ${aws_key_pair.deployer2.key_name}"
}

output "ssh_fingerprint" {
  value = "Fingerprint asociado ${aws_key_pair.deployer.fingerprint}"
}