provider "aws" {
  region = "ap-southeast-1"
}


module "s3-s3" {
  source  = "../../../modules/s3/"
  bucket = "jiten-dev-s3"
}