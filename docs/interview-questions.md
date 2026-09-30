# Technical interview questions and answers

These answers describe the intended design in this repository. Terraform syntax must be repaired before deployment, and the current database credential flow should be replaced with Secrets Manager for production.

## AWS networking and architecture

1. **Why is this a three-tier architecture?**  
   The presentation tier is the internet-facing ALB, the application tier is the private EC2 Auto Scaling Group, and the data tier is private PostgreSQL RDS. Each tier has separate subnets and security-group boundaries, so clients cannot bypass the ALB or connect directly to the database.

2. **Why are there two Availability Zones?**  
   The ALB, application subnets, and database subnet group span two AZs. This reduces the impact of an AZ failure and allows the ALB and ASG to distribute traffic and instances across failure domains.

3. **What makes a subnet public or private?**  
   A public subnet has a route to an Internet Gateway. Private application and database subnets do not route directly to the Internet Gateway. Application subnets use NAT for outbound updates, while the RDS subnets remain non-public and have no public IP addresses.

4. **Why use a NAT Gateway?**  
   Private instances need outbound access for package installation, image retrieval, or updates without accepting inbound Internet traffic. A single NAT is cheaper for development; one NAT per AZ improves resilience but increases cost.

5. **How does traffic flow?**  
   A client reaches the ALB on HTTP or HTTPS. The ALB forwards to healthy EC2 targets on the application port. The application connects to PostgreSQL on TCP 5432. The database never receives client traffic directly.

6. **What would you change for a production architecture?**  
   I would use two NAT Gateways, HTTPS-only ingress, WAF, VPC endpoints for AWS services, Secrets Manager, centralized logs, stronger RDS sizing, deletion protection, and a remote encrypted Terraform backend with locking.

## Security groups and ALB

7. **How do the security groups enforce tier isolation?**  
   The ALB group allows ports 80 and 443 from the Internet. The application group allows only the application port from the ALB security-group ID. The database group allows only TCP 5432 from the application security-group ID. No application or database ingress rule permits `0.0.0.0/0`.

8. **Why reference security groups instead of application subnet CIDRs?**  
   A security-group reference expresses workload identity rather than location. Instances can scale or move between approved subnets without changing database rules, and unrelated resources in the same subnet cannot automatically connect.

9. **How does the ALB health check work?**  
   The target group checks `/health` over HTTP and expects status 200. The ASG uses ELB health checks, so an instance that fails the load-balancer check can be replaced after the grace period.

10. **How would you enable HTTPS?**  
    Supply an ACM certificate ARN in the same AWS region as the ALB. The HTTP listener can redirect to HTTPS, and the HTTPS listener forwards to the target group. In production I would make HTTPS mandatory when a certificate is configured.

11. **How would you troubleshoot an unhealthy target?**  
    Check target-group reason codes, instance status checks, the application process, container logs, the `/health` response from inside the VPC, security-group rules, route tables, and the launch-template user data. I would also verify that the app listens on `0.0.0.0`, not only localhost.

## Terraform

12. **Why use Terraform modules?**  
    VPC, security groups, ALB, compute, and RDS are isolated modules with explicit inputs and outputs. This makes boundaries reviewable, reduces duplication, and allows individual components to be reused or tested independently.

13. **How do you prevent secrets from being committed?**  
    Real `.tfvars` files, state files, `.env` files, keys, and certificates are ignored by Git. Sensitive variables prevent normal CLI display, but they do not remove secrets from state. Therefore the backend must be encrypted and access-controlled, and production credentials should come from Secrets Manager.

14. **What is the Terraform state risk?**  
    State can contain passwords, endpoints, and resource metadata even when variables are marked sensitive. I would use an encrypted S3 backend with versioning and a supported locking mechanism, restrict access to the deployment role, and never upload state to source control.

15. **Why run `fmt`, `validate`, and `plan` separately?**  
    `fmt` standardizes source, `validate` checks configuration and module wiring without creating resources, and `plan` compares desired state with AWS and exposes proposed changes. A reviewed plan is the approval artifact before apply.

16. **How would you safely update the application image?**  
    CI publishes an immutable commit-SHA image tag. Terraform passes the selected tag into the launch template. A launch-template version change triggers the ASG instance refresh, allowing controlled replacement while maintaining the configured healthy percentage.

17. **What is wrong with the current Terraform implementation?**  
    The generated files currently contain invalid single-line blocks with multiple arguments, so `terraform validate` fails. This must be repaired before deployment. The database password also needs to move from Terraform/user data into Secrets Manager.

## Compute, Docker, and application

18. **Why use an Auto Scaling Group instead of standalone EC2 instances?**  
    The ASG maintains capacity, replaces unhealthy instances, distributes instances across AZs, and supports rolling instance refreshes. It also makes the application tier stateless and suitable for horizontal scaling.

19. **Why use Gunicorn?**  
    Flask’s development server is not suitable for production. Gunicorn is a production WSGI server that manages worker processes and provides a stable process model behind the ALB.

20. **What Docker security controls are present?**  
    The Dockerfile uses a pinned slim base image, installs dependencies without a package cache, runs as a non-root `app` user, excludes tests and local artifacts through `.dockerignore`, and exposes only the application port.

21. **How would you improve the image supply chain?**  
    Generate a lock file with hashes, scan images with Trivy, use ECR image scanning, sign images with a provenance system, pin base images by digest, and deploy only immutable commit-SHA tags.

22. **How does the Flask application avoid SQL injection?**  
    Database statements use psycopg parameter binding for user-provided names. Input validation restricts the name to a non-empty string of at most 100 characters. The API never returns credentials or the connection string.

## RDS and IAM

23. **Why is RDS in private subnets?**  
    A database should not be directly reachable from the Internet. The RDS instance has `publicly_accessible = false`, uses a DB subnet group spanning two AZs, and accepts port 5432 only from the application security group.

24. **What RDS protections are configured?**  
    Storage encryption, automated backup retention, configurable deletion protection, restricted security-group ingress, and private subnet placement are configured. Development may disable deletion protection, but production should enable it and retain final snapshots.

25. **What is the EC2 IAM role used for?**  
    The instance profile grants Systems Manager access through `AmazonSSMManagedInstanceCore`, avoiding public SSH. It should later receive only the narrowly scoped permissions needed to retrieve the application secret and publish logs.

26. **Why is a broad AWS-managed policy not ideal?**  
    It is convenient for a portfolio baseline but broader than least privilege. Production should replace it with a reviewed custom policy containing only required SSM, Secrets Manager, CloudWatch, and ECR actions.

## CI/CD and security

27. **How does the CI workflow reduce deployment risk?**  
    It separates checks from infrastructure mutation, uses read-only repository permissions, runs tests and filesystem scanning, validates Terraform, and runs Checkov. Applying infrastructure should be a separate explicitly approved workflow using GitHub OIDC.

28. **Why use GitHub OIDC instead of access keys?**  
    OIDC issues short-lived credentials to a trusted workflow subject. There is no long-lived AWS secret to leak or rotate. The IAM trust policy should restrict the repository, branch or environment, and audience.

29. **What monitoring would you add?**  
    ALB request count, latency, HTTP 5xx, target health, EC2 CPU, ASG capacity, RDS CPU, storage, and connections should have CloudWatch alarms. Application logs should go to a retained log group, with sensitive values filtered before logging.

30. **How would you investigate a production outage?**  
    Start at the client and ALB metrics, then inspect target health and 5xx/latency patterns. Check ASG activity and instance status, SSM access, container and application logs, security groups and routes, and finally RDS CPU, connections, storage, and events. I would correlate timestamps, avoid changing multiple layers at once, and preserve the Terraform plan and CloudWatch evidence for post-incident analysis.
