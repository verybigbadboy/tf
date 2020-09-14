resource "libvirt_volume" "zabbix-server-os" {
  name   = "zabbix-server-os-${local.zabbix_version}"
  pool   = libvirt_pool.home.name
  base_volume_id = libvirt_volume.ubuntu18.id
  size   = 10 * 1024 * 1024 * 1024
}

data "template_file" "cloud_init_zabbix" {
  template = file("${path.module}/zabbix-server/cloud_init.cfg")
}

data "template_file" "cloud_init_zabbix_hostname" {
  template = file("${path.module}/fragments/hostname.cfg")

  vars = {
    tf_hostname = "zabbix"
  }
}

data "template_cloudinit_config" "zabbix_cloud_init" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "base.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_base.rendered
  }

  part {
    filename     = "zabbix_agent.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_zabbix_agent.rendered
  }

  part {
    filename     = "master.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_zabbix.rendered
  }

  part {
    filename     = "hostname.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_zabbix_hostname.rendered
  }
}


resource "libvirt_cloudinit_disk" "zabbix_server_commoninit" {
  name           = "zabbix_server_commoninit.iso"
  user_data      = data.template_cloudinit_config.zabbix_cloud_init.rendered
  network_config = data.template_file.network_config.rendered
  pool           = libvirt_pool.home.name
}

resource "libvirt_domain" "zabbix-server" {
  name   = "zabbix-server-terraform-${local.zabbix_version}"
  memory = "1024"
  vcpu   = 4
  autostart = true

  cloudinit = libvirt_cloudinit_disk.zabbix_server_commoninit.id

  network_interface {
    bridge = "br0"
    mac    = "52:54:00:12:69:03"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.zabbix-server-os.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
