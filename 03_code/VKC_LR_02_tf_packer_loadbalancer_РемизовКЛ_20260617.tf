resource "vkcs_lb_loadbalancer" "main" {
  name          = "lab1-lb"
  vip_subnet_id = vkcs_networking_subnet.public.id
}

resource "vkcs_lb_listener" "http" {
  name            = "http-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = vkcs_lb_loadbalancer.main.id
}

resource "vkcs_lb_pool" "web" {
  name        = "web-targets"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = vkcs_lb_listener.http.id
}

resource "vkcs_lb_monitor" "web" {
  name        = "web-monitor"
  type        = "HTTP"
  delay       = 10
  timeout     = 5
  max_retries = 3
  url_path    = "/"
  pool_id     = vkcs_lb_pool.web.id
}

resource "vkcs_lb_member" "web" {
  count         = 2
  name          = "web-member-${count.index + 1}"
  address       = vkcs_compute_instance.web[count.index].network[0].fixed_ip_v4   # берём IP из ВМ
  protocol_port = 80
  pool_id       = vkcs_lb_pool.web.id
  subnet_id     = vkcs_networking_subnet.private.id
}
