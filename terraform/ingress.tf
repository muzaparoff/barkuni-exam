resource "kubernetes_ingress" "barkuni" {
  spec {
    tls {
      hosts      = ["your.domain.com"]
      secret_name = "barkuni-tls"
    }
  }
}