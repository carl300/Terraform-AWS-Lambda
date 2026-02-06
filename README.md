# Terraform-AWS-Lambda
Multi‑Region EC2 Disaster Recovery Automation

This project implements a production‑grade Disaster Recovery (DR) pipeline for EC2 workloads using Terraform, AWS Lambda, and EventBridge. It automatically creates AMIs of a primary EC2 instance in us‑east‑1 and replicates them to us‑west‑2 for regional failover.

The EC2 instance hosts a full application stack — Jenkins, a Node.js  app, Prometheus, and Grafana — and the DR pipeline ensures the entire environment can be restored in the DR region using the latest replicated AMI.

The solution includes:

Terraform‑provisioned EC2, IAM, Lambda, and EventBridge

Python Lambda function for AMI creation and cross‑region replication

Automated scheduling and tagging

Fully reproducible infrastructure‑as‑code

Real‑world DR architecture suitable for scaling to multiple instances

This repository demonstrates cloud automation, resilience engineering, and multi‑region AWS design patterns.
