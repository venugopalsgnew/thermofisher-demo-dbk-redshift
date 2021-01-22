# Under below locals session, we specify all common tags which would apply for every resource #

locals {
  common_tags = {
        application            = var.application
        built_by               = var.built_by
        costcenter             = var.costcenter
        group                  = var.group
        application_owner      = var.application_owner
        environment            = var.environment
        finance_contact        = var.finance_contact
        application_support    = var.application_support
        infrastructure_support = var.infrastructure_support
        dd_auto_discovery      = var.dd_auto_discovery
        hfm_entity             = var.hfm_entity
        rightsizing_exception  = var.rightsizing_exception
        project_number         = var.project_number
        compliance             = var.compliance
        tranche                = var.tranche
        division               = var.division
  }
}

# below code does create new vpc along with the common tags, one additional tag (Name tag) gets added 

resource "aws_vpc" "redshiftvpc" {
  cidr_block = var.redshiftvpccidr
  instance_tenancy = "default"

  tags = merge( 
    local.common_tags,
    {
    Name = var.vpcname
    }
  )
}


resource "aws_subnet" "apppublicsubnet" {
  count = length(var.publicazs)
  cidr_block = element(var.publicsubnetcidr, count.index)
  availability_zone = element(var.publicazs, count.index)
  vpc_id = aws_vpc.redshiftvpc.id
  tags = merge(
    local.common_tags,
    {
    Name = "${var.vpcname}-${var.publicsubnetname}-${count.index+1}"
   }
  )
}


resource "aws_subnet" "redshiftprivatesubnet" {
  count = length(var.privateazs)
  cidr_block = element(var.privatesubnetcidr, count.index)
  availability_zone = element(var.privateazs, count.index)
  vpc_id = aws_vpc.redshiftvpc.id
  tags = merge(
   local.common_tags,
    {
    Name = "${var.vpcname}-${var.privatesubnetname}-${count.index+1}"
    }
  )
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.redshiftvpc.id
  tags = merge(
    local.common_tags,
    {
    Name = "${var.vpcname}-internet_gateway"
    }
  )
}


resource "aws_route_table" "publicroutetable" {
  vpc_id = aws_vpc.redshiftvpc.id
  tags = merge(
    local.common_tags,
    {
    Name = "${var.vpcname}-public-route-table"
    }
  )
}



resource "aws_route_table_association" "publicrouteassociation" {
  count = length(var.publicazs)
  subnet_id = element(aws_subnet.apppublicsubnet.*.id, count.index)
  route_table_id = aws_route_table.publicroutetable.id
}



resource "aws_route" "publicroute" {
  route_table_id = aws_route_table.publicroutetable.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}



resource "aws_route_table" "privateroutetable" {
  vpc_id = aws_vpc.redshiftvpc.id
   tags = merge(
    local.common_tags,
    {
    Name = "${var.vpcname}-private-route-table"
    }
  )
}

resource "aws_route_table_association" "privaterouteassociation" {
  count = length(var.privateazs)
  subnet_id = element(aws_subnet.redshiftprivatesubnet.*.id, count.index)
  route_table_id = aws_route_table.privateroutetable.id
}


resource "aws_redshift_subnet_group" "subnetgroup" {
  name       = "redshift-subnet-group"
 # subnet_ids = ["aws_subnet.redshiftprivatesubnet.*.id"]
  subnet_ids = aws_subnet.redshiftprivatesubnet.*.id
  
  tags = merge(
    local.common_tags,
    {
    Name = "${var.vpcname}-redshift-subnet-group"
    }
  ) 
}



resource "aws_security_group" "redshift_SG" {
  name        = "Redshift_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.redshiftvpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    local.common_tags,
    {
    Name = "Redshift_SG"
    }
  )
}


resource "aws_eip" "natgatewayip" {
  count = length(var.publicsubnetcidr)
  vpc = true
  tags = merge(
    local.common_tags,
    {
    Name = "Elasticipfor_natgateway"
    }
  )
}


resource "aws_nat_gateway" "natgateway" {
  count = length(var.publicazs)
  allocation_id = element(aws_eip.natgatewayip.*.id, count.index)
  subnet_id = element(aws_subnet.apppublicsubnet.*.id, count.index)
  tags = merge(
    local.common_tags,
    {
    Name = "redshiftaws_natgateway"
    }
  )
}

/*
As the code below contains depends_on, it means all other resources like vpc,security group, redshift subnet group gets created
and then only redshift cluster gets provision
*/
resource "aws_redshift_cluster" "cluster" {
  cluster_identifier = var.cluster_identifier
  database_name      = var.database_name
  master_username    = var.master_username
  master_password    = var.master_pass
  node_type          = var.nodetype
  cluster_type       = var.cluster_type
  publicly_accessible = "false"
  cluster_subnet_group_name = aws_redshift_subnet_group.subnetgroup.id
  skip_final_snapshot = true
depends_on = [
    aws_vpc.redshiftvpc,
    aws_security_group.redshift_SG,
    aws_redshift_subnet_group.subnetgroup
  ]
  tags = merge(
    local.common_tags,
    {
    Name = var.clustername
    }
  )
}


/* 
# Below code of data "aws_vpc" is fetching existing vpc whose tag value as "datavpc-for-testing"


data "aws_vpc" "selected" {
  filter {
                name  = "tag:Name"
                values = ["datavpc-for-testing"]
        }
}

In order to use above VPC under for any resource we have to use vpc_id = data.aws_vpc.select.id

resource "aws_subnet" "apppublicsubnet" {
  count = length(var.publicazs)
  cidr_block = element(var.publicsubnetcidr, count.index)
  availability_zone = element(var.publicazs, count.index)
  vpc_id = data.aws_vpc.selected.id
  tags = merge(
    local.common_tags,
    {
    Name = "datavpc-for-testing-${var.publicsubnetname}-${count.index+1}"
   }
  )
}

*/
