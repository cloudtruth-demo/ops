resource "aws_security_group" "cluster" {
  name        = "${var.local_name_prefix}eks-cluster-${var.name}"
  description = "Security group for the eks cluster"
  vpc_id      = var.vpc_id
}

resource "aws_iam_role" "cluster" {
  name = "${var.local_name_prefix}eks-${var.name}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "eks.amazonaws.com",
          "eks-fargate-pods.amazonaws.com"
         ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "service-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_policy" "eks-cloudwatch-policy" {
  name   = "${var.local_name_prefix}eks-cloudwatch-policy-${var.name}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cloudwatch-policy" {
  policy_arn = aws_iam_policy.eks-cloudwatch-policy.arn
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_policy" "eks-nlb-policy" {
  name   = "${var.local_name_prefix}eks-nlb-policy-${var.name}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "elasticloadbalancing:*",
                "ec2:CreateSecurityGroup",
                "ec2:Describe*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "nlb-policy" {
  policy_arn = aws_iam_policy.eks-nlb-policy.arn
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role" "pod-execution" {
  name               = "${var.local_name_prefix}eks-pod-execution-${var.name}"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "eks.amazonaws.com",
          "eks-fargate-pods.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

}

resource "aws_iam_role_policy_attachment" "execution-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.pod-execution.name
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.local_name_prefix}${var.name}/cluster"
  retention_in_days = 30
}

resource "aws_eks_cluster" "main" {
  name     = "${var.local_name_prefix}${var.name}"
  role_arn = aws_iam_role.cluster.arn
  version = var.kubernetes_version

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    security_group_ids = flatten([
      aws_security_group.cluster.id,
      compact(var.cluster_security_groups),
    ])
    subnet_ids = var.cluster_subnet_ids
  }

  timeouts {
    delete = "30m"
  }

  depends_on = [
    aws_cloudwatch_log_group.cluster,
    aws_iam_role_policy_attachment.cluster-policy,
    aws_iam_role_policy_attachment.service-policy,
  ]
}

resource aws_eks_fargate_profile "main" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.local_name_prefix}${var.name}"
  pod_execution_role_arn = aws_iam_role.pod-execution.arn
  subnet_ids             = var.profile_subnet_ids

  tags = {
    Name                                                 = "${var.local_name_prefix}public-subnet"
    Environment                                          = var.atmos_env
    Source                                               = "atmos"
    Namespaces                                           = join(" ", var.namespaces)
    "kubernetes.io/cluster/${aws_eks_cluster.main.name}" = "owned"
    "k8s.io/cluster/${aws_eks_cluster.main.name}"        = "owned"
  }

  selector {
    namespace = "kube-system"
  }

  dynamic "selector" {
    for_each = var.namespaces
    content {
      namespace = selector.value
    }
  }

  timeouts {
    create = "10m"
    delete = "10m"
  }
}

data "tls_certificate" "main" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "main" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.main.certificates.0.sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

data "template_file" "kubeconfig" {
  template = <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: ${aws_eks_cluster.main.endpoint}
    certificate-authority-data: ${aws_eks_cluster.main.certificate_authority[0].data}
  name: ${aws_eks_cluster.main.name}
contexts:
- context:
    cluster: ${aws_eks_cluster.main.name}
    user: aws-${aws_eks_cluster.main.name}
  name: ${aws_eks_cluster.main.name}
current-context: ${aws_eks_cluster.main.name}
users:
- name: aws-${aws_eks_cluster.main.name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws
      args:
        - "eks"
        - "get-token"
        - "--cluster-name"
        - "${aws_eks_cluster.main.name}"
EOF
}

// To allow terraform to supply credentials during the patch of coredns below
// that is needed for fargate eks
data "template_file" "kubeconfig-tf" {
  template = <<EOF
apiVersion: v1
kind: Config
clusters:
- name: "${aws_eks_cluster.main.name}"
  cluster:
    certificate-authority-data: ${aws_eks_cluster.main.certificate_authority.0.data}
    server: ${aws_eks_cluster.main.endpoint}
contexts:
- name: terraform
  context:
    cluster: "${aws_eks_cluster.main.name}"
    user: terraform
users:
- name: terraform
  user:
    token: ${data.aws_eks_cluster_auth.main.token}
EOF
}

resource "null_resource" "coredns_patch" {
  depends_on = [aws_eks_fargate_profile.main]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOF
kubectl --kubeconfig=<(echo '${data.template_file.kubeconfig-tf.rendered}') --context terraform \
  patch deployment coredns \
  --namespace kube-system \
  --type=json \
  -p='[{"op": "remove", "path": "/spec/template/metadata/annotations", "value": "eks.amazonaws.com/compute-type"}]'
EOF
  }
}
