resource "aws_ecr_repository" "ecr" {
  name                 = "${var.prefix}-saas-provider-backend" # TODO: refactor variable
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_codestarconnections_connection" "codestarconnection" {
  name          = "${var.prefix}-connection"
  provider_type = "GitHub"
}

resource "aws_iam_role" "codepipeline_role" {
  name = "${var.prefix}-codepipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "codebuild.amazonaws.com",
          "codepipeline.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.prefix}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObjectAcl",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codestar-connections:UseConnection"
      ],
      "Resource": "${aws_codestarconnections_connection.codestarconnection.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild",
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:InitiateLayerUpload",
        "ecr:ListImages",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "eks:Describe*",
        "eks:ListClusters",
        "ssm:GetParameterHistory",
        "ssm:GetParametersByPath",
        "ssm:GetParameters",
        "ssm:GetParameter",
        "ssm:DescribeParameters"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# CodeBuild project to build source. buildspec.yml is includes in source.
resource "aws_codebuild_project" "saas-app-image-build" {
  name         = "${var.prefix}-build"
  description  = "Terraform SaaS Backend App Image Build"
  service_role = aws_iam_role.codepipeline_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.ecr.name
    }

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = "903434732822" #TODO: refactor to secret
    }

    environment_variable {
      name  = "AWS_ACCESS_KEY_ID"
      value = var.aws_access_key
    }

    environment_variable {
      name  = "AWS_SECRET_ACCESS_KEY"
      value = var.aws_secret_key
    }

    environment_variable {
      name  = "PIPELINE_ROLE_ARN"
      value = aws_iam_role.codepipeline_role.arn
    }

    environment_variable {
      name  = "EKS_CLUSTER_NAME"
      value = aws_eks_cluster.cluster.name
    }

    environment_variable {
      name = "docker_user"
      value = "phunguyen19"
    }

    environment_variable {
      name = "docker_password"
      value = "K%dm5].2bvw8yLLV" # TODO: variable refactor
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}


resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${var.prefix}-codepipeline-bucket"
  acl    = "private"
  force_destroy = true
}

resource "aws_codepipeline" "codepipeline" {
  name     = "${var.prefix}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.codestarconnection.arn
        FullRepositoryId = "phunguyen19/saas-provider-backend"
        BranchName       = "feat/build-finish"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.saas-app-image-build.name
      }
    }
  }
}

