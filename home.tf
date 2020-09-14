provider "libvirt" {
  uri = "qemu:///system"
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

data "template_file" "cloud_init_zabbix_agent" {
  template = file("${path.module}/fragments/zabbix_agent.cfg")
}

data "template_file" "cloud_init_base" {
  template = file("${path.module}/fragments/base.cfg")
}

data "template_file" "network_config" {
  template = file("${path.module}/network_config.cfg")
}

terraform {
  required_version = ">= 0.12"
}

