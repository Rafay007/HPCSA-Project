variable "region" {
  default = "eu-central-1"
}
variable "instance_type" {
  default = "t2.micro"
}
variable "ssh_connection_user" {
  default = "ubuntu"
}
variable "ami" {
  default = "ami-0c55b159cbfafe1f0"
}
variable "tag" {
  default = "terraform-test"
}
variable "creds" {
}
variable "vpc_cidr" {
}
variable "public_subnet_cidr" {
}