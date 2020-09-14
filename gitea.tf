
resource "libvirt_volume" "gitea-os" {
  name   = "gitea-os-${local.gitea_version}"
  pool   = libvirt_pool.home.name
  base_volume_id = libvirt_volume.ubuntu18.id
  size   = 10 * 1024 * 1024 * 1024
}

resource "libvirt_volume" "gitea-data" {
  name   = "gitea-data-static"
  pool   = libvirt_pool.home.name
  size   = 1000 * 1024 * 1024 * 1024
}

data "template_file" "cloud_init_gitea" {
  template = file("${path.module}/gitea/cloud_init.cfg")
}

data "template_file" "cloud_init_gitea_hostname" {
  template = file("${path.module}/fragments/hostname.cfg")

  vars = {
    tf_hostname = "gitea"
  }
}

data "template_cloudinit_config" "gitea_cloud_init" {
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
    content      = data.template_file.cloud_init_gitea.rendered
  }

  part {
    filename     = "hostname.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_gitea_hostname.rendered
  }
}

resource "libvirt_cloudinit_disk" "gitea_commoninit" {
  name           = "gitea_commoninit.iso"
  user_data      = data.template_cloudinit_config.gitea_cloud_init.rendered
  network_config = data.template_file.network_config.rendered
  pool           = libvirt_pool.home.name
}

resource "libvirt_domain" "gitea" {
  name   = "gitea-terraform-${local.gitea_version}"
  memory = "1024"
  vcpu   = 4
  autostart = true

  cloudinit = libvirt_cloudinit_disk.gitea_commoninit.id

  network_interface {
    bridge = "br0"
    mac    = "52:54:00:12:69:07"
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
    volume_id = libvirt_volume.gitea-os.id
  }
  disk {
    volume_id = libvirt_volume.gitea-data.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
