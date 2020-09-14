
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

resource "libvirt_volume" "ubuntu20" {
  name   = "ubuntu20-base-qcow2"
  pool   = libvirt_pool.home.name
  source = "https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
  format = "qcow2"
}
