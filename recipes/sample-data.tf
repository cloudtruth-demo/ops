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
