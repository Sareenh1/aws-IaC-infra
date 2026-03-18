# Public Subnets
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name                                            = "${var.environment}-public-subnet-1"
    Environment                                     = var.environment
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.environment}-eks"  = "shared"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name                                            = "${var.environment}-public-subnet-2"
    Environment                                     = var.environment
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.environment}-eks"  = "shared"
  }
}

# Private Subnets (for RDS, Redis, DocDB, MQ)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = "${var.region}a"

  tags = {
    Name                                                = "${var.environment}-private-subnet-1"
    Environment                                         = var.environment
    "kubernetes.io/role/internal-elb"                   = "1"
    "kubernetes.io/cluster/${var.environment}-eks"      = "shared"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = "${var.region}b"

  tags = {
    Name                                                = "${var.environment}-private-subnet-2"
    Environment                                         = var.environment
    "kubernetes.io/role/internal-elb"                   = "1"
    "kubernetes.io/cluster/${var.environment}-eks"      = "shared"
  }
}
