terraform {
  backend "s3" {
    bucket   = "terraform-state-lab2"       # замените на имя вашего бакета
    key      = "lab2/terraform.tfstate"
    region   = "RegionOne"
    endpoint = "https://hb.vkcloud-storage.ru"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true

    access_key = ""
    secret_key = ""
  }
}
