terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.11.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

resource "kubernetes_namespace" "example" {
  metadata {
    name = "mlservice"
  }
}

resource "kubernetes_deployment" "example" {
  metadata {
    name = "terraform-example"
    labels = {
      test = "MyExampleApp"
    }
    namespace = "mlservice"
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        test = "MyExampleApp"
      }
    }

    template {
      metadata {
        labels = {
          test = "MyExampleApp"
        }
      }

      spec {
        container {
          image = "mleap:3.7"
          name  = "example"

          resources {
            limits = {
              cpu    = "1"
              memory = "1024Mi"
            }
            requests = {
              cpu    = "1"
              memory = "1024Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "example" {
  metadata {
    name = "terraform-example-service"
    labels = {
      test = "MyExampleApp"
    }
    namespace = "mlservice"
  }

  spec {
    selector = {
      test = "MyExampleApp"
    }

    type = "LoadBalancer"

    port {
      name = "http"
      port = 8080
      target_port = 65327
    }
  }
}
