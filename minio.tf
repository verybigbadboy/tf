resource "libvirt_volume" "minio-os" {
  name   = "minio-os-${local.minio_version}"
  pool   = libvirt_pool.home.name
  base_volume_id = libvirt_volume.ubuntu18.id
  size   = 10 * 1024 * 1024 * 1024
}

resource "libvirt_volume" "minio-data" {
  name   = "minio-data"
  pool   = libvirt_pool.home.name
  size   = 1000 * 1024 * 1024 * 1024
}

data "template_file" "cloud_init_minio" {
  template = file("${path.module}/minio/cloud_init.cfg")
}

data "template_file" "cloud_init_minio_hostname" {
  template = file("${path.module}/fragments/hostname.cfg")

  vars = {
    tf_hostname = "minio"
  }
}

data "template_cloudinit_config" "minio_cloud_init" {
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
    content      = data.template_file.cloud_init_minio.rendered
  }

  part {
    filename     = "hostname.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_minio_hostname.rendered
  }
}


resource "libvirt_cloudinit_disk" "minio_commoninit" {
  name           = "minio_commoninit.iso"
  user_data      = data.template_cloudinit_config.minio_cloud_init.rendered
  network_config = data.template_file.network_config.rendered
  pool           = libvirt_pool.home.name
}

resource "libvirt_domain" "minio" {
  name   = "minio-terraform-${local.minio_version}"
  memory = "1024"
  vcpu   = 4
  autostart = true

  cloudinit = libvirt_cloudinit_disk.minio_commoninit.id

  network_interface {
    bridge = "br0"
    mac    = "52:54:00:12:69:05"
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
    volume_id = libvirt_volume.minio-os.id
  }
  disk {
    volume_id = libvirt_volume.minio-data.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
