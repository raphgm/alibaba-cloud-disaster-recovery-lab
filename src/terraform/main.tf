terraform {
  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.230"
    }
  }
  required_version = ">= 1.6.0"
}

provider "alicloud" {
  region = var.region
}

variable "region" {
  default = "ap-southeast-1"
}

resource "alicloud_vpc" "main" {
  vpc_name   = "vpc-dr-lab"
  cidr_block = "10.20.0.0/16"
}

resource "alicloud_vswitch" "zone_a" {
  vswitch_name = "vsw-zone-a"
  vpc_id       = alicloud_vpc.main.id
  cidr_block   = "10.20.1.0/24"
  zone_id      = "${var.region}a"
}

resource "alicloud_vswitch" "zone_b" {
  vswitch_name = "vsw-zone-b"
  vpc_id       = alicloud_vpc.main.id
  cidr_block   = "10.20.2.0/24"
  zone_id      = "${var.region}b"
}

# Primary ACK cluster (Zone A) — control plane only. Worker nodes are
# managed as separate node pools below (required since provider 1.212+;
# worker_instance_types/worker_number/worker_disk_category were removed
# from this resource).
resource "alicloud_cs_managed_kubernetes" "primary" {
  name            = "dr-lab-primary"
  cluster_spec    = "ack.pro.small"
  vswitch_ids     = [alicloud_vswitch.zone_a.id]
  new_nat_gateway = true
}

resource "alicloud_cs_kubernetes_node_pool" "primary_workers" {
  cluster_id           = alicloud_cs_managed_kubernetes.primary.id
  node_pool_name       = "primary-workers"
  vswitch_ids          = [alicloud_vswitch.zone_a.id]
  instance_types       = ["ecs.g6.large"]
  desired_size         = 3
  system_disk_category = "cloud_essd"
}

# Standby node pool in Zone B — min-size 0 by default, scaled up only
# on failover. This is deliberately NOT the fix for Experiment 2's
# slow recovery — see standby-buffer.tf for that.
resource "alicloud_cs_kubernetes_node_pool" "standby_zone_b" {
  cluster_id     = alicloud_cs_managed_kubernetes.primary.id
  node_pool_name = "standby-zone-b"
  vswitch_ids    = [alicloud_vswitch.zone_b.id]
  instance_types = ["ecs.g6.large"]
  desired_size   = 0

  scaling_config {
    min_size = 0
    max_size = 5
  }
}

resource "alicloud_db_instance" "primary" {
  engine           = "MySQL"
  engine_version   = "8.0"
  instance_type    = "rds.mysql.s2.large"
  instance_storage = 100
  vswitch_id       = alicloud_vswitch.zone_a.id
  instance_name    = "rds-dr-lab-primary"
}

resource "alicloud_oss_bucket" "prod_data" {
  bucket = "prod-data-bucket-dr-lab"

  versioning {
    status = "Enabled"
  }
}

# ACL is a separate resource as of provider 1.220+ — "private" is also
# the bucket's default, but set it explicitly rather than relying on it.
resource "alicloud_oss_bucket_acl" "prod_data" {
  bucket = alicloud_oss_bucket.prod_data.bucket
  acl    = "private"
}
