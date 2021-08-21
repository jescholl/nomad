# volume registration
type = "csi"
id = "px-nfs-test"
name = "portworx nfs test volume"
external_id = ""
access_mode = "single-node-writer"
attachment_mode = "file-system"
plugin_id = "nfs0"

parameters {
  share = "/var/lib/osd/pxns/px-nfs-test"
  server = "px-nfs.service.consul"
}
