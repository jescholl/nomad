job "netboot" {
  datacenters = ["dc1"]
  type = "service"
  group "netboot" {
    count = 1

    network {
      port "tftp" {
        static = 69
      }
    }

    task "netboot" {
      driver = "docker"
      config {
        image = "jescholl/netboot:latest"
        network_mode = "host"
        ports = ["tftp"]
        cap_add = [
          "NET_RAW",
          "NET_BIND_SERVICE",
        ]
        args = [
          "--log-queries",
          "--log-dhcp",
          "--dhcp-range=192.168.10.1,proxy,255.255.255.0",
          "--enable-tftp",
          "--tftp-root=/var/lib/tftpboot",
          "--dhcp-userclass=set:ipxe,iPXE",
          "--pxe-service=tag:!ipxe,x86PC,PXE chainload to iPXE,undionly.kpxe",
          #"--pxe-service=tag:ipxe,x86PC,iPXE,http://boot.netboot.xyz",
          "--pxe-service=tag:ipxe,x86PC,iPXE,https://raw.githubusercontent.com/jescholl/netboot.xyz-custom/master/custom.ipxe",
          "--port=0",
        ]
      }
      resources {
        cpu    = 50
        memory = 20
      }
    }
  }
}
