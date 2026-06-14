resource "vkcs_compute_keypair" "my_key" {
  name       = "terraform-key-local"
  public_key = file("~/.ssh/terraform_rsa.pub")
}
