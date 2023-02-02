terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.17.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

resource "kubernetes_deployment" "mlflow_deployment" {
  metadata {
    name = "mlflow-deployment"
    namespace = "neo-ml"

  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mlflow-deployment"
      }
    }

    template {
      metadata {
        labels = {
          app = "mlflow-deployment"
        }
      }

      spec {
        container {
          name  = "mlflow-deployment"
          image = "dkhundley/mlflow-server:1.0.3"
          args  = ["--host=0.0.0.0", "--port=5000", "--backend-store-uri=postgresql://mlflow_user:mlflow_pwd@mlflow-postgres-service.neo-ml:5432/mlflow_db", "--default-artifact-root=S3://mlflow/", "--workers=2"]

          port {
            name           = "http"
            container_port = 5000
            protocol       = "TCP"
          }

          env {
            name  = "MLFLOW_S3_ENDPOINT_URL"
            value = "http://10.105.142.155:9000/"
          }

          env {
            name  = "AWS_ACCESS_KEY_ID"
            value = "minioadmin"
          }

          env {
            name  = "AWS_SECRET_ACCESS_KEY"
            value = "minioadmin"
          }

          resources {
            requests = {
              cpu = "500m"
            }
          }

          image_pull_policy = "Always"
        }
      }
    }
  }
}

resource "kubernetes_service" "mlflow_service" {
  metadata {
    name = "mlflow-service"
    namespace = "neo-ml"

  }

  spec {
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 5000
      target_port = "5000"
    }

    selector = {
      app = "mlflow-deployment"
    }

    type = "NodePort"
  }
}

resource "kubernetes_config_map" "mlflow_postgres_config" {
  metadata {
    name = "mlflow-postgres-config"
    namespace = "neo-ml"


    labels = {
      app = "mlflow-postgres"
    }
  }

  data = {
    PGDATA = "/var/lib/postgresql/mlflow/data"

    POSTGRES_DB = "mlflow_db"

    POSTGRES_PASSWORD = "mlflow_pwd"

    POSTGRES_USER = "mlflow_user"
  }
}

resource "kubernetes_stateful_set" "mlflow_postgres" {
  metadata {
    name = "mlflow-postgres"
    namespace = "neo-ml"


    labels = {
      app = "mlflow-postgres"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mlflow-postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "mlflow-postgres"
        }
      }

      spec {
        container {
          name  = "mlflow-postgres"
          image = "postgres:11"

          port {
            container_port = 5432
            protocol       = "TCP"
          }

          env_from {
            config_map_ref {
              name = "mlflow-postgres-config"
            }
          }

          resources {
            requests = {
              cpu = "500m"

              memory = "1Gi"
            }
          }

          volume_mount {
            name       = "mlflow-pvc"
            mount_path = "/var/lib/postgresql/mlflow"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "mlflow-pvc"
      }

      spec {
        access_modes = ["ReadWriteOnce"]

        resources {
          requests = {
            storage = "100Mi"
          }
        }
      }
    }

    service_name = "mlflow-postgres-service"
  }
}

resource "kubernetes_service" "mlflow_postgres_service" {
  metadata {
    name = "mlflow-postgres-service"
    namespace = "neo-ml"


    labels = {
      svc = "mlflow-postgres-service"
    }
  }

  spec {
    port {
      protocol    = "TCP"
      port        = 5432
      target_port = "5432"
    }

    selector = {
      app = "mlflow-postgres"
    }

    type = "NodePort"
  }
}

resource "kubernetes_persistent_volume_claim" "mlflow_minio_pvc" {
  metadata {
    name = "mlflow-minio-pvc"
    namespace = "neo-ml"

  }

  spec {
    access_modes = ["ReadWriteMany"]

    resources {
      requests = {
        storage = "300Mi"
      }
    }

    storage_class_name = "standard"
  }
}

resource "kubernetes_deployment" "mlflow_minio_deployment" {
  metadata {
    name = "mlflow-minio-deployment"
    namespace = "neo-ml"

  }

  spec {
    selector {
      match_labels = {
        app = "mlflow-minio"
      }
    }

    template {
      metadata {
        labels = {
          app = "mlflow-minio"
        }
      }

      spec {
        volume {
          name = "mlflow-minio-storage"

          persistent_volume_claim {
            claim_name = "mlflow-minio-pvc"
          }
        }

        container {
          name  = "mlflow-minio"
          image = "minio/minio:RELEASE.2020-10-18T21-54-12Z"
          args  = ["server", "/data"]

          port {
            host_port      = 9000
            container_port = 9000
          }

          env {
            name  = "MINIO_ROOT_USER"
            value = "tytH73367"
          }

          env {
            name  = "MINIO_ROOT_PASSWORD"
            value = "HGhygs12_"
          }

          volume_mount {
            name       = "mlflow-minio-storage"
            mount_path = "/data"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mlflow_minio_service" {
  metadata {
    name = "mlflow-minio-service"
    namespace = "neo-ml"

  }

  spec {
    port {
      protocol    = "TCP"
      port        = 9000
      target_port = "9000"
    }

    selector = {
      app = "mlflow-minio"
    }

    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "mlflow_minio_ingress" {
  metadata {
    name = "mlflow-minio-ingress"
    namespace = "neo-ml"


    annotations = {
      "kubernetes.io/ingress.class" = "nginx"

      "nginx.ingress.kubernetes.il/add-base-url" = "true"

      "nginx.ingress.kubernetes.il/ssl-redirect" = "false"
    }
  }

  spec {
    rule {
      host = "mlflow-minio.local"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "mlflow-minio-service"

              port {
                number = 9000
              }
            }
          }
        }
      }
    }
  }
}
