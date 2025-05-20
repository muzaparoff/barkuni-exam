resource "kubernetes_ingress" "barkuni" {
  metadata {
    name      = "barkuni"
    namespace = "default"
  }

  spec {
    tls {
      hosts       = ["your.domain.com"]
      secret_name = "barkuni-tls"
    }

    rule {
      host = "your.domain.com"
      http {
        path {
          path     = "/"
          path_type = "Prefix"
          backend {
            service_name = "barkuni-service"
            service_port = 5000
          }
        }
      }
    }
  }
}