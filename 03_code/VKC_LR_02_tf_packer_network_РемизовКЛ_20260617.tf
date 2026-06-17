data "vkcs_networking_network" "ext_net" {
  name = "internet"
}

data "vkcs_networking_router" "existing" {
  id = "913bdd47-9155-45b2-b404-5c10d0086132"
}

resource "vkcs_networking_network" "lab1_vpc" {
  name           = "lab1-vpc"
  admin_state_up = true
}

resource "vkcs_networking_subnet" "public" {
  name            = "lab1-public"
  network_id      = vkcs_networking_network.lab1_vpc.id
  cidr            = "10.0.1.0/24"
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

resource "vkcs_networking_subnet" "private" {
  name            = "lab1-private"
  network_id      = vkcs_networking_network.lab1_vpc.id
  cidr            = "10.0.2.0/24"
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

resource "vkcs_networking_router_interface" "public" {
  router_id = data.vkcs_networking_router.existing.id
  subnet_id = vkcs_networking_subnet.public.id
}

resource "vkcs_networking_router_interface" "private" {
  router_id = data.vkcs_networking_router.existing.id
  subnet_id = vkcs_networking_subnet.private.id
}
