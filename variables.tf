variable "aws_region" {
    default = "us-west-2"
}

variable "ami" {
    default = "ami-09c5e030f74651050"
}

variable "vpc_id" {
    default = "vpc-ead09792"
}

variable "azs" {
	type = list
	default = ["us-west-2a", "us-west-2b"]
}