terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.70.0"
    }
  }
}


provider "yandex" {
  service_account_key_file = "key.json"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = "ru-central1-a"
}

resource "yandex_vpc_network" "network" {
  name = "vvot11-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name = "vvot11-subnet" 
  zone = "ru-central1-a"
  v4_cidr_blocks = ["192.168.1.0/24"]
  network_id = yandex_vpc_network.network.id
}

# Открываем порты для доступа к серверу
resource "yandex_vpc_security_group" "nextcloud_sg" {
  name       = "nextcloud-security-group"
  network_id = yandex_vpc_network.network.id

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH"
    port          = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow HTTP"
    port          = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow HTTPS"
    port          = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts-oslogin"
}

resource "yandex_compute_disk" "boot-disk" {
  name = "vvot11-boot-disk"
  type = "network-ssd"
  image_id = data.yandex_compute_image.ubuntu.id
  size = 10
}

resource "yandex_compute_instance" "server" {
  name = "vvot11-server"
  platform_id = "standard-v3"
  hostname = "web"

  resources {
    core_fraction = 20
    cores = 2
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_iam_ssh_key" "my_key" {
  name = "my-ssh-key"
  public_key = file("/home/ksushagolubeffa/.ssh/id_rsa.pub")
}

output "web-server-ip" {
  value = yandex_compute_instance.server.network_interface[0].nat_ip_address
}


output "vm_external_ip" {
  value = yandex_compute_instance.server.network_interface[0].nat_ip_address
}

