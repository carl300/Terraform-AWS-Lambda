# Terraform-AWS-Lambda
# Multi‑Region EC2 Disaster Recovery Automation (Terraform + Lambda)

This project implements a fully automated **cross‑region EC2 Disaster Recovery (DR) pipeline** using Terraform, AWS Lambda, and EventBridge.  
It creates daily AMIs of a primary EC2 instance in **us‑east‑1** and automatically copies them to the DR region **us‑west‑2**.

The entire workflow is Infrastructure‑as‑Code and fully reproducible.

---

## 🚀 Features

### **1. Automated AMI Creation**
A Lambda function creates an AMI of the primary EC2 instance on a schedule (default: once per day).

### **2. Cross‑Region AMI Replication**
The AMI is automatically copied from the primary region (**us‑east‑1**) to the DR region (**us‑west‑2**).

### **3. EventBridge Scheduling**
A CloudWatch EventBridge rule triggers the Lambda function at a configurable interval.

### **4. IAM Roles & Policies**
Least‑privilege IAM roles allow Lambda to:
- Create AMIs  
- Tag AMIs  
- Copy AMIs across regions  
- Write logs to CloudWatch  

### **5. Terraform‑Managed Infrastructure**
All resources are created, updated, and destroyed using Terraform:
- EC2 instance  
- Security group  
- Lambda function  
- IAM roles  
- EventBridge rule  
- AMI packaging  

---

## 📁 Project Structure

