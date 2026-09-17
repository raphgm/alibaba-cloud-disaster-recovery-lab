# The fix from the article: Experiment 2 (ECS/node failure) took 6m40s
# to recover on the default autoscaler config — well past the 5-minute
# target. This always-on, warm buffer node absorbs evicted pods
# immediately on node failure instead of waiting for a fresh node to
# provision and boot.
#
# Apply just this resource after running Experiment 2 the first time:
#   terraform apply -target=alicloud_cs_kubernetes_node_pool.standby_buffer
#
# cluster_id/vswitch_id default to this module's own primary cluster and
# zone-A vswitch (main.tf), so applying alongside it needs no extra input.
# To apply this fix against an existing cluster instead — without editing
# this file — override both:
#   terraform apply -target=alicloud_cs_kubernetes_node_pool.standby_buffer \
#     -var="standby_buffer_cluster_id=cs-xxxxxxxx" \
#     -var="standby_buffer_vswitch_id=vsw-xxxxxxxx"

variable "standby_buffer_cluster_id" {
  description = "ACK cluster ID to attach the standby buffer node pool to. Defaults to this module's own primary cluster."
  type        = string
  default     = null
}

variable "standby_buffer_vswitch_id" {
  description = "Vswitch ID for the standby buffer node pool. Defaults to this module's own zone-A vswitch."
  type        = string
  default     = null
}

resource "alicloud_cs_kubernetes_node_pool" "standby_buffer" {
  cluster_id     = coalesce(var.standby_buffer_cluster_id, alicloud_cs_managed_kubernetes.primary.id)
  node_pool_name = "standby-buffer"
  vswitch_ids    = [coalesce(var.standby_buffer_vswitch_id, alicloud_vswitch.zone_a.id)]
  instance_types = ["ecs.g6.large"]
  desired_size   = 1 # always-on buffer capacity

  scaling_config {
    min_size = 1
    max_size = 1
  }
}
