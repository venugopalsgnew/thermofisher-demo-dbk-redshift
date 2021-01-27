# Terraform Best Practices 

Terraform Best Practices for AWS users.

## Index

edp-operations-test/terraform/modules/s3/

Necessity of having below files under modules/s3 directory.
* s3.tf file     -  contains terraform code for s3 bucket provisioning along with compliances requirement given by Thermofisher team
* variables.tf   -  Reusability is one of the major benefits of Infrastructure as Code. In Terraform, we can use variables to make our configurations more dynamic. 
                    This means we are no longer hard coding every value into the configuration. the below code is example to define variable for s3 bucket

                    variable "bucket_name" {
                      type        = string
                      description = "S3 bucket name"
                      default     = "s3bucket-22dec2020-1"
                    }
                    
                    The type argument in a variable block allows you to restrict the type of value that will be accepted as the value for a variable
                    If no type constraint is set then a value of any type is accepted.
                    The supported type keywords are:
                      . string
                      . number
                      . bool
                      . list
                      . set
                      . map
                      . object


* output.tf      -  An output variable is defined by using an output block with a label. The label must be unique as it can be used to reference the output’s value
                    Let's define an output to show the bucket name. Add the following code in output.tf file

                    output "name of the bucket" {
                      description = "Name of the S3 bucket"
                      value = aws_s3_bucket.imports3.id
                    }

