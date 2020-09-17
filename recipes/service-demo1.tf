locals {
  demo1_env = {
    AWS_REGION = var.region
    SVC_ENV    = var.atmos_env
    SVC_NAME   = "$${name}"
    SVC_PORT   = "$${port}"
  }

  demo1_svc_env = join(",\n", formatlist("{ \"name\" : \"%s\", \"value\" : \"%s\" }", keys(local.demo1_env), values(local.demo1_env)))
}

module "service-demo1-alb" {
  source = "../modules/alb"

  atmos_env          = var.atmos_env
  global_name_prefix = var.global_name_prefix
  local_name_prefix  = var.local_name_prefix
  name               = "demo1"

  internal      = false
  listener_cidr = "0.0.0.0/0"
  zone_id       = module.dns.public_zone_id
  subnet_ids    = module.vpc.public_subnet_ids
  vpc_id        = module.vpc.vpc_id
  logs_bucket   = aws_s3_bucket.logs.bucket

  destination_port = module.service-demo1.port

  destination_security_group = module.service-demo1.security_group_id
  alb_certificate_arn        = module.wildcart-cert.certificate_arn
}

module "service-demo1" {
  source = "../modules/ecs-service"

  atmos_env          = var.atmos_env
  global_name_prefix = var.global_name_prefix
  local_name_prefix  = var.local_name_prefix
  region             = var.region

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  // The default security groups allow outbound to internet which is required for
  // pulling docker image from ECR
  security_groups = module.vpc.security_group_ids

  name            = "demo1"
  ecs_cluster_arn = aws_ecs_cluster.services.arn

  create_repository   = 1
  integrate_with_lb   = 1
  alb_target_group_id = module.service-demo1-alb.lb_target_group_id

  port = 8000

  container_count = 1

  // https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-tasks-size
  cpu    = 256
  memory = 512

  // When upstream image gets updated, one can deploy it with:
  // atmos -e dev container activate -c services demo1
  containers_template = <<TMPL
    [
      {
        "name": "$${name}",
        "image": "$${registry_host}/$${repository_name}:latest",
        "portMappings": [
          {
            "containerPort": $${port},
            "hostPort": $${port}
          }
        ],
        "environment" : [
            ${local.demo1_svc_env}
        ],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "$${log_group_name}",
                "awslogs-region": "${var.region}",
                "awslogs-stream-prefix": "$${name}"
            }
        }
      }
    ]
TMPL

}


// Bucket with some extra sample data for cloudtruth demo
resource "aws_s3_bucket" "sample-data" {
  bucket        = "${var.global_name_prefix}sample-data"
  force_destroy = var.force_destroy_buckets

  tags = {
    Env    = var.atmos_env
    Source = "atmos"
  }
}

resource "aws_s3_bucket_object" "sample-json" {
  bucket = aws_s3_bucket.sample-data.bucket
  key = "data/sample.json"
  source = "../templates/sample.json"
}

resource "aws_s3_bucket_object" "sample-yml" {
  bucket = aws_s3_bucket.sample-data.bucket
  key = "data/sample.yml"
  source = "../templates/sample.yml"
}
