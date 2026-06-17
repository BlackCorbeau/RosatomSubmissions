resource "vkcs_db_instance" "postgres" {
  name        = "lab1-postgres"
  flavor_id   = var.db_flavor_id
  availability_zone = "MS1"

  datastore {
    type    = "postgresql"
    version = "15"
  }

  size        = 10
  volume_type = "ceph-ssd"

  disk_autoexpand {
    autoexpand   = true
    max_disk_size = 100
  }

  network {
    uuid = vkcs_networking_network.lab1_vpc.id
  }

  depends_on = [
    vkcs_networking_router_interface.private,
  ]
}
