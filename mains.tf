provider "aws" {
  region = "us-east-1"
}

# =========================================================
# VPC
# =========================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "cdec-complete-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "cdec-igw"
  }
}

# Public Subnets

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "cdec-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "cdec-public-b"
  }
}

# Private Subnets

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.10.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "cdec-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.10.12.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "cdec-private-b"
  }
}

# Public Route Table

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "cdec-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "cdec-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# =========================================================
# EKS IAM Role
# =========================================================

resource "aws_iam_role" "eks_cluster_role" {
  name = "cdec-complete-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "eks.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# =========================================================
# EKS Cluster
# =========================================================

resource "aws_eks_cluster" "main" {
  name     = "cdec-complete-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.35"

  access_config {
    authentication_mode = "API"
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# =========================================================
# EKS Node IAM Role
# =========================================================

resource "aws_iam_role" "node_role" {
  name = "cdec-complete-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# =========================================================
# EKS Node Group
# =========================================================

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "cdec-node-group"
  node_role_arn   = aws_iam_role.node_role.arn

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only
  ]
}

# =========================================================
# EBS CSI Add-on
# =========================================================

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"

  depends_on = [
    aws_eks_node_group.main
  ]
}

# =========================================================
# S3
# =========================================================

resource "aws_s3_bucket" "frontend" {
  bucket = "cdec-studentapp-frontend-005008920274"

  tags = {
    Name = "cdec-studentapp-frontend"
  }
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# =========================================================
# Route 53
# =========================================================

resource "aws_route53_zone" "main" {
  name = "bhagvat.shop"

  tags = {
    Name = "bhagvat.shop"
  }
}

# =========================================================
# ACM Certificate
# CloudFront certificate MUST be in us-east-1
# =========================================================

resource "aws_acm_certificate" "cloudfront" {
  domain_name       = "bhagvat.shop"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.bhagvat.shop"
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60

  records = [
    each.value.record
  ]

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cloudfront" {
  certificate_arn = aws_acm_certificate.cloudfront.arn

  validation_record_fqdns = [
    for record in aws_route53_record.certificate_validation :
    record.fqdn
  ]
}

# =========================================================
# CloudFront
# =========================================================

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "cdec-s3-oac"
  description                       = "CloudFront access to S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled = true

  aliases = [
    "bhagvat.shop"
  ]

  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-frontend"

    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    target_origin_id = "S3-frontend"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.cloudfront.certificate_arn

    ssl_support_method  = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [
    aws_acm_certificate_validation.cloudfront
  ]
}

# =========================================================
# S3 CloudFront Policy
# =========================================================

data "aws_iam_policy_document" "s3_cloudfront" {
  statement {
    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.frontend.arn}/*"
    ]

    principals {
      type = "Service"

      identifiers = [
        "cloudfront.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"

      values = [
        aws_cloudfront_distribution.frontend.arn
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = data.aws_iam_policy_document.s3_cloudfront.json
}

# =========================================================
# Route 53 → CloudFront
# =========================================================

resource "aws_route53_record" "cloudfront" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "bhagvat.shop"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}
