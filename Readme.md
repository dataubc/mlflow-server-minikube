### For Mlservice in K8 using terraform and for MLflow
- Mlservice 
- MLflow in the cluster

##### Mlservice

Main.tf will create a load balancer in the Minikube, with the mleap:3.7 image, you need to use `minikube tunnel` before running the terraform apply, otherwise it will stuck in still creating, using NodePort won't need the same minikube tunnel. You then need to use ```minikube service <nameoftheservice>```

##### MLflow in the cluster

Postgress server for the metrics and the hyperparameters
MinIO for the artifacts, you will need to export the url,access key and the password in the client side if you are running the train.py that is using the server


