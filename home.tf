provider "libvirt" {
  uri = "qemu:///system"
#  uri = "qemu+ssh://root@192.168.88.85/system"
}
#${local.timestamp_sanitized}

locals {
  timestamp = "${timestamp()}"
  timestamp_sanitized = "${replace("${local.timestamp}", "/[-| |T|Z|:]/", "")}"

  mysql_version = "v1"
  zabbix_version = "v1"
  mssymbols_version = "v1"
  minio_version = "v1"
  gitea_version = "v1"
  dev_version = "no"
#  dev_version = "${local.timestamp_sanitized}"
}

resource "libvirt_pool" "home" {
  name = "home"
  type = "dir"
  path = "/raid/terraform/libvirt-pool-home"
}

resource "libvirt_volume" "ubuntu16" {
  name   = "ubuntu16-base-qcow2"
  pool   = libvirt_pool.home.name
  source = "https://cloud-images.ubuntu.com/releases/xenial/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img"
  format = "qcow2"
}

resource "libvirt_volume" "ubuntu18" {
  name   = "ubuntu18-base-qcow2"
  pool   = libvirt_pool.home.name
  source = "https://cloud-images.ubuntu.com/releases/bionic/release/ubuntu-18.04-server-cloudimg-amd64.img"
  format = "qcow2"
}


data "template_file" "cloud_init_zabbix_agent" {
  template = file("${path.module}/fragments/zabbix_agent.cfg")
}

data "template_file" "cloud_init_base" {
  template = file("${path.module}/fragments/base.cfg")
}

data "template_file" "network_config" {
  template = file("${path.module}/network_config.cfg")
}

#####


terraform {
  required_version = ">= 0.12"
}




resource "libvirt_volume" "mysql-os" {
  name   = "mysql-os-${local.mysql_version}"
  pool   = libvirt_pool.home.name
  base_volume_id = libvirt_volume.ubuntu18.id
  size   = 10 * 1024 * 1024 * 1024
}

resource "libvirt_volume" "mysql-data" {
  name   = "mysql-data"
  pool   = libvirt_pool.home.name
  size   = 100 * 1024 * 1024 * 1024
}

data "template_file" "cloud_init_mysql" {
  template = file("${path.module}/mysql/cloud_init.cfg")
}

data "template_file" "cloud_init_mysql_hostname" {
  template = file("${path.module}/fragments/hostname.cfg")

  vars = {
    tf_hostname = "mysql"
  }
}

data "template_cloudinit_config" "mysql_cloud_init" {
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
    content      = data.template_file.cloud_init_mysql.rendered
  }

  part {
    filename     = "hostname.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_mysql_hostname.rendered
  }
}


resource "libvirt_cloudinit_disk" "mysql_commoninit" {
  name           = "mysql_commoninit.iso"
  user_data      = data.template_cloudinit_config.mysql_cloud_init.rendered
  network_config = data.template_file.network_config.rendered
  pool           = libvirt_pool.home.name
}

resource "libvirt_domain" "mysql" {
  name   = "mysql-terraform-${local.mysql_version}"
  memory = "1024"
  vcpu   = 4
  autostart = true

  cloudinit = libvirt_cloudinit_disk.mysql_commoninit.id

  network_interface {
    bridge = "br0"
    mac    = "52:54:00:12:69:02"
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
    volume_id = libvirt_volume.mysql-os.id
  }
  disk {
    volume_id = libvirt_volume.mysql-data.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}





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




resource "libvirt_volume" "mssymbols-os" {
  name   = "mssymbols-os-${local.mssymbols_version}"
  pool   = libvirt_pool.home.name
  base_volume_id = libvirt_volume.ubuntu18.id
  size   = 10 * 1024 * 1024 * 1024
}

resource "libvirt_volume" "mssymbols-data" {
  name   = "mssymbols-data"
  pool   = libvirt_pool.home.name
  size   = 100 * 1024 * 1024 * 1024
}

data "template_file" "cloud_init_mssymbols" {
  template = file("${path.module}/mssymbols/cloud_init.cfg")
}

data "template_file" "cloud_init_mssymbols_hostname" {
  template = file("${path.module}/fragments/hostname.cfg")

  vars = {
    tf_hostname = "mssymbols"
  }
}

data "template_cloudinit_config" "mssymbols_cloud_init" {
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
    content      = data.template_file.cloud_init_mssymbols.rendered
  }

  part {
    filename     = "hostname.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_init_mssymbols_hostname.rendered
  }
}


resource "libvirt_cloudinit_disk" "mssymbols_commoninit" {
  name           = "mssymbols_commoninit.iso"
  user_data      = data.template_cloudinit_config.mssymbols_cloud_init.rendered
  network_config = data.template_file.network_config.rendered
  pool           = libvirt_pool.home.name
}

resource "libvirt_domain" "mssymbols" {
  name   = "mssymbols-terraform-${local.mssymbols_version}"
  memory = "1024"
  vcpu   = 4
  autostart = true

  cloudinit = libvirt_cloudinit_disk.mssymbols_commoninit.id

  network_interface {
    bridge = "br0"
    mac    = "52:54:00:12:69:04"
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
    volume_id = libvirt_volume.mssymbols-os.id
  }
  disk {
    volume_id = libvirt_volume.mssymbols-data.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}



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


### dev

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


### gitea

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

