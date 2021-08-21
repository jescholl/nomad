job "plugin-nfs-controller" {
  datacenters = ["dc1"]


  group "controllers" {
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
        type      = "controller"
        mount_dir = "/csi" # this path /csi matches the --endpoint argument for the container
      }
    }
  }
}
