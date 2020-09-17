variable "cloudtruth_account_id" {
  description = "The AWS account ID for the cloudtruth account that will be assuming the role"
  default = "811566399652"
}

resource "aws_iam_role" "cloudtruth" {
  description = "The role that cloudtruth will assume in order to access your AWS account"
  name = "cloudtruth"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::${var.cloudtruth_account_id}:root"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

// This policy allows cloudtruth to list and read your S3 buckets
//
resource "aws_iam_role_policy" "cloudtruth-s3" {
  name   = "cloudtruth-s3"
  role   = aws_iam_role.cloudtruth.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BucketSelection",
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListAllMyBuckets"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Sid": "BucketAccess",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

//  This policy allows cloudtruth to list and read your AWS SSM Parameter Store
//
resource "aws_iam_role_policy" "cloudtruth-ssm" {
  name   = "cloudtruth-ssm"
  role   = aws_iam_role.cloudtruth.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
        {
            "Sid": "ParameterAccess",
            "Action": [
                "ssm:DescribeParameters",
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }

  ]
}
EOF
}
