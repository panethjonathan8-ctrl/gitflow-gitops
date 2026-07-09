# Constants for the one shared cluster environment (folder named "cluster"
# rather than "dev" precisely because it isn't just the dev environment — it
# hosts the dev, staging, AND production Kubernetes namespaces on a single
# EKS cluster). env_name below is still "dev" on purpose: it's the value
# baked into real, already-created AWS resource names (the VPC is
# "gitflow-analyzer-dev", the IAM role is "gitflow-analyzer-github-actions-dev",
# etc.) — changing it would rename/recreate live infrastructure. There is
# deliberately no live/staging or live/production folder — staging and
# production are namespaces on this one cluster, not separate clusters.
locals {
  env_name     = "dev"
  cluster_name = "gitflow-analyzer-dev"
  vpc_cidr     = "10.0.0.0/16"
}
