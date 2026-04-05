resource "aws_vpc" "EKS_Project_VPC" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "EKS_Project_VPC"
  }
}


resource "aws_subnet" "public-1" {
  vpc_id            = aws_vpc.EKS_Project_VPC.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name                                        = "public-1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

resource "aws_subnet" "public-2" {
  vpc_id            = aws_vpc.EKS_Project_VPC.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-2b"

  tags = {
    Name                                        = "public-2"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

resource "aws_subnet" "private-1" {
  vpc_id            = aws_vpc.EKS_Project_VPC.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name                                        = "private-1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

resource "aws_subnet" "private-2" {
  vpc_id            = aws_vpc.EKS_Project_VPC.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-2b"

  tags = {
    Name                                        = "private-2"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

resource "aws_internet_gateway" "igw_eks_project" {
  vpc_id = aws_vpc.EKS_Project_VPC.id

  tags = {
    Name = "igw_eks_project"
  }
}

resource "aws_eip" "eip_eks" {
  domain = "vpc"

  tags = {
    Name = "eip_eks"
  }
}

resource "aws_nat_gateway" "natgw_eks_project" {
  allocation_id = aws_eip.eip_eks.id
  subnet_id     = aws_subnet.public-1.id


  tags = {
    Name = "natgw_eks_project"
  }

}

resource "aws_route_table" "EKS_Project_VPC-public-route" {
  vpc_id = aws_vpc.EKS_Project_VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_eks_project.id
  }

  tags = {
    Name = "EKS_Project_VPC-public-route"
  }
}



resource "aws_route_table" "EKS_Project_VPC-private-route" {
  vpc_id = aws_vpc.EKS_Project_VPC.id


  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw_eks_project.id
  }



  tags = {
    Name = "EKS_Project_VPC-private-route"
  }
}


resource "aws_route_table_association" "public-1" {
  subnet_id      = aws_subnet.public-1.id
  route_table_id = aws_route_table.EKS_Project_VPC-public-route.id
}

resource "aws_route_table_association" "public-2" {
  subnet_id      = aws_subnet.public-2.id
  route_table_id = aws_route_table.EKS_Project_VPC-public-route.id
}

resource "aws_route_table_association" "private-1" {
  subnet_id      = aws_subnet.private-1.id
  route_table_id = aws_route_table.EKS_Project_VPC-private-route.id
}

resource "aws_route_table_association" "private-2" {
  subnet_id      = aws_subnet.private-2.id
  route_table_id = aws_route_table.EKS_Project_VPC-private-route.id
}