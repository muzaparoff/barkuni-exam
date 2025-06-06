aws_region                = "us-east-1"
eks_cluster_name          = "barkuni-exam-cluster"
vpc_id                    = "vpc-02fb1f16ffa2c1a11"
cloudwatch_log_group_name = "/aws/eks/barkuni-exam-cluster/cluster"
kms_key_id                = "arn:aws:kms:us-east-1:058264138725:key/c600ebf9-94ec-4cf6-9e5a-1403967190d2"
domain_name               = "vicarius.xyz"
organization_name         = "Barkuni"
node_group_name           = "general"
node_role_arn             = "arn:aws:iam::058264138725:role/general-eks-node-group-20250520133836818000000001"
node_desired_size         = 2
node_min_size             = 1
node_max_size             = 3
node_instance_types       = ["t3.medium"]
project_name              = "barkuni"
