# The fix from the article: Experiment 2 (ECS/node failure) took 6m40s
# to recover on the default autoscaler config — well past the 5-minute
# target. This always-on, warm buffer node absorbs evicted pods
# immediately on node failure instead of waiting for a fresh node to
# provision and boot.
#
# Apply just this resource after running Experiment 2 the first time:
#   terraform apply -target=alicloud_cs_kubernetes_node_pool.standby_buffer

resource "alicloud_cs_kubernetes_node_pool" "standby_buffer" {
  cluster_id     = alicloud_cs_managed_kubernetes.primary.id
  node_pool_name = "standby-buffer"
  vswitch_ids    = [alicloud_vswitch.zone_a.id]
  instance_types = ["ecs.g6.large"]
  desired_size   = 1 # always-on buffer capacity

  scaling_config {
    min_size = 1
    max_size = 1
  }
}
