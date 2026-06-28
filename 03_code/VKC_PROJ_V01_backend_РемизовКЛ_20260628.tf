terraform {
  backend "s3" {
    bucket   = "tf-state-final-assessment"               # имя твоего бакета (должен существовать)
    key      = "final-assessment/terraform.tfstate"      # путь к файлу состояния внутри бакета
    region   = "ru-msk"                      # твой регион
    endpoint = "https://hb.ru-msk.vkcloud-storage.ru"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
  }
}
