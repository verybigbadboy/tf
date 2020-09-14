resource "libvirt_volume" "dev-os" {
  name   = "dev-os-${local.dev_version}"
  pool   = libvirt_pool.home.name
  base_volume_id = libvirt_volume.ubuntu18.id
  size   = 100 * 1024 * 1024 * 1024
}

data "template_file" "cloud_init_dev" {
  template = file("${path.module}/dev/cloud_init.cfg")
}

data "template_file" "cloud_init_dev_hostname" {
  template = file("${path.module}/fragments/hostname.cfg")

  vars = {
    tf_hostname = "dev"
  }
}

data "template_cloudinit_config" "dev_cloud_init" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "base.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_base.rendered
  }

  part {
    filename     = "master.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_dev.rendered
  }

  part {
    filename     = "hostname.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_dev_hostname.rendered
  }
}


resource "libvirt_cloudinit_disk" "dev_commoninit" {
  name           = "dev_commoninit.iso"
  user_data      = data.template_cloudinit_config.dev_cloud_init.rendered
  network_config = data.template_file.network_config.rendered
  pool           = libvirt_pool.home.name
}

resource "libvirt_domain" "dev" {
  name   = "dev-terraform-${local.dev_version}"
  memory = "4096"
  vcpu   = 4
  autostart = true

  cloudinit = libvirt_cloudinit_disk.dev_commoninit.id

  network_interface {
    bridge = "br0"
    mac    = "52:54:00:12:69:06"
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
    volume_id = libvirt_volume.dev-os.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
