```hcl
resource "kubernetes_ingress" "barkuni" {
  # ...existing code...
  spec {
    tls {
      hosts      = ["your.domain.com"]
      secret_name = "barkuni-tls"
    }
    # ...existing code...
  }
  # ...existing code...
}
# ...existing code...
```