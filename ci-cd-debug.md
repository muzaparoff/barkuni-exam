# Why does GitHub Actions get "Kubernetes cluster unreachable: ... i/o timeout"?

## Common Causes

1. **EKS API endpoint is not reachable from the public Internet**
   - The endpoint is private, or public access is not enabled, or public CIDRs are restricted.

2. **Network ACLs or Security Groups block traffic**
   - Even if you allow all in SGs, NACLs or missing routes can block traffic.

3. **No route to Internet Gateway**
   - The EKS control plane or public subnet does not have a route to an IGW.

4. **AWS/GitHub transient network issue**
   - Sometimes, GitHub-hosted runners' IPs are temporarily blocked or not routable.

5. **VPC Endpoints for EKS API**
   - If present, these can restrict access to only inside the VPC.

6. **EKS cluster is not fully ready**
   - Even if status is ACTIVE, the API server may not be ready.

## What does NOT cause this error

- IAM permissions (would result in "forbidden" or "unauthorized", not timeout)
- Missing CA or cluster role ARN in GitHub secrets (would result in auth errors, not timeout)
- EKS version (1.27 is supported)

## How to Debug

- **Check EKS Console > Networking > API server endpoint access**
  - Public access enabled
  - Public access CIDRs: `0.0.0.0/0` (for testing)
- **Check VPC Route Tables**
  - Public subnet(s) have `0.0.0.0/0` → IGW
- **Check NACLs**
  - Allow all traffic in/out (rules 100/101 as you have)
- **Check Security Groups**
  - Allow inbound 443 from `0.0.0.0/0` to the EKS control plane SG
- **Check from your laptop**
  - If you can't connect from your laptop, it's not a GitHub Actions issue.
- **Check DNS resolution**
  - nslookup resolves to public IPs

## What else can you do?

- Try running the same kubectl/helm commands from a different public cloud shell (AWS CloudShell, Google Cloud Shell, etc).
- If it works from there, it's a GitHub runner network issue.
- If it fails everywhere, it's a VPC/network config issue.

## Summary

**This error is almost always a network path issue between the GitHub Actions runner and the EKS API endpoint.**  
Double-check public access, CIDRs, NACLs, route tables, and try from another public network for confirmation.
