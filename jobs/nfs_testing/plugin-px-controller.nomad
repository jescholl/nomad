job "plugin-nfs-node" {
  datacenters = ["dc1"]

  # you can run node plugins as service jobs as well, but running
  # as a system job ensures all nodes in the DC have a copy.
  type = "system"

  # only one plugin of a given type and ID should be deployed on
  # any given client node
  constraint {
    operator = "distinct_hosts"
    value = true
  }

  group "nodes" {
    task "plugin" {
      driver = "docker"

      config {
        image = "mcr.microsoft.com/k8s/csi/nfs-csi:latest"

        args = [
          "-v=5",
          "--endpoint=unix://csi/csi.sock",
          "--nodeid=${node.unique.name}",
          "--logtostderr",
          "--v=5",
        ]

        # all CSI node plugins will need to run as privileged tasks
        # so they can mount volumes to the host. controller plugins
        # do not need to be privileged.
        privileged = true
      }

      csi_plugin {
        id        = "nfs0"
        type      = "node"
        mount_dir = "/csi" # this path /csi matches the --endpoint argument for the container
      }
    }
  }
}
