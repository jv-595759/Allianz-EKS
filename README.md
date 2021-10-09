# Prerequisites

1. Access to an aws account.
2. terrafom CLI installed locally.

# Deploy an App

You can change the application image and port by changing the variables "app_image" and "app_port". To deploy the application, 

```
terraform init

terraform plan
terraform apply
```

# Access the application

Get the loadbalancer DNS name from aws console/cli and use any web browser to access the application at port 80. The URL will be,
```
http://<loadbalancer_DNS_name>:80
```

# To clean up 

```
terraform destroy
```
