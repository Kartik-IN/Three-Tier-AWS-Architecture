# DevSecOps review

## Review status

- Python: reviewed for credential disclosure, unsafe debug behavior, SQL injection, and input validation. Queries use parameters, credentials are not returned by endpoints, and the app does not enable Flask debug mode.
- Docker: added a pinned Python base image, non-root runtime user, bytecode suppression, and a minimal runtime command.
- GitHub Actions: added least-privilege read-only permissions, pinned major action versions, dependency installation, tests, and Trivy/Checkov checks. AWS credentials are not used by this workflow.
- Terraform: the intended network controls are present, but the current Terraform files still require syntax repair before any scanner or deployment result can be trusted.

## Findings requiring follow-up

1. `db_password` is currently supplied as a Terraform variable and interpolated into the launch-template user data. Sensitive Terraform variables are still stored in state, and user data can be inspected by privileged AWS users. Move the password to Secrets Manager and have the instance retrieve it using a narrowly scoped IAM policy before production deployment.
2. The database resource currently uses `skip_final_snapshot = true`. This is acceptable only for disposable development environments; production should make final snapshots configurable and default to retaining one.
3. Egress is currently unrestricted for all tiers. Ingress tier isolation is enforced, but production hardening should use VPC endpoints and explicit egress rules where practical.
4. The ALB HTTP listener is internet-facing by design. HTTPS requires supplying an ACM certificate ARN; production should require HTTPS rather than relying on HTTP when no certificate is configured.
5. `terraform.tfvars.example` contains a placeholder password only. Never copy a real password into a committed file.

## Scanner availability

Terraform was installed, but TFLint and Checkov were not available locally. Docker was installed but no image build was run because the application dependency lock file has not yet been generated. The GitHub Actions workflow will run Checkov and Trivy in CI once the Terraform syntax and dependency hash issues are corrected.
