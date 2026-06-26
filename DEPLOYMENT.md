# Deployment Runbook (AWS ECS Fargate)

Deploys this app to **AWS ECS Fargate** via a **GitHub Actions** pipeline that
authenticates to AWS with **OIDC** (no stored AWS keys).

> Infrastructure (the AWS resources) is currently created **manually in the AWS
> Console** using the checklist below. The pipeline only builds and ships new
> image versions into that already-existing infrastructure.

## Architecture

```
Developer push to main
        │
        ▼
GitHub Actions ──(OIDC, short-lived token)──► AWS
   test → build image → Trivy scan → push to ECR → deploy to ECS
        │
        ▼
Internet ──► ALB (:80) ──► ECS Fargate tasks (:3000) ──► CloudWatch Logs
```

---

## One-time AWS setup (console checklist)

Do these once, in this order. Names assume `node-application-prod` to match the
workflow's `env:` block — change both if you use different names.

1. **ECR repository**
   - ECR → Create repository → name `node-application`
   - Enable **Scan on push**, set tag mutability to **Immutable**

2. **Networking** (or use the default VPC for a quick start)
   - A VPC with at least 2 subnets; public subnets for the load balancer

3. **IAM — GitHub OIDC trust** (this is what removes stored keys)
   - IAM → Identity providers → Add provider → **OpenID Connect**
     - Provider URL: `https://token.actions.githubusercontent.com`
     - Audience: `sts.amazonaws.com`
   - IAM → Roles → Create role → **Web identity** → select that provider
     - Restrict the trust to your repo: `repo:<org>/<repo>:*`
     - Attach a policy allowing: ECR push, `ecs:RegisterTaskDefinition`,
       `ecs:UpdateService`, `ecs:DescribeServices/TaskDefinition`, and
       `iam:PassRole` for the two ECS roles below
   - Copy the **role ARN** — you'll need it for `AWS_DEPLOY_ROLE`

4. **IAM — ECS roles**
   - **Execution role**: trusts `ecs-tasks.amazonaws.com`, attach the AWS managed
     `AmazonECSTaskExecutionRolePolicy` (lets ECS pull the image + write logs)
   - **Task role**: trusts `ecs-tasks.amazonaws.com`, no permissions needed (the app uses none)

5. **CloudWatch log group**: create `/ecs/node-application-prod`

6. **ECS cluster**: create a Fargate cluster named `node-application-prod`

7. **Task definition** (family `node-application-prod`)
   - Launch type **Fargate**, 0.25 vCPU / 0.5 GB
   - Container name **node-application**, port **3000**
   - Image: any placeholder for now (the pipeline overwrites it on first deploy)
   - Attach the execution role + task role; log to the group from step 5

8. **Application Load Balancer**
   - Internet-facing ALB in the public subnets, listener on **:80**
   - Target group: type **IP**, protocol HTTP :3000, health check path **/health**

9. **ECS service** (name `node-application-prod`)
   - Cluster from step 6, the task definition from step 7
   - Desired count 2, attach to the ALB target group from step 8
   - Security group: allow :3000 **only from the ALB's security group**

---

## Wire up the pipeline

1. GitHub repo → **Settings → Secrets and variables → Actions → Variables** → add:

   | Variable | Value |
   |---|---|
   | `AWS_DEPLOY_ROLE` | the OIDC role ARN from step 3 |

2. Confirm the `env:` block in `.github/workflows/ci.yml` matches your names
   (`AWS_REGION`, `ECR_REPOSITORY`, `ECS_CLUSTER`, `ECS_SERVICE`, `ECS_TASK_FAMILY`,
   `CONTAINER_NAME`).

3. (Optional) GitHub repo → **Settings → Environments → `production`** → add
   **Required reviewers** to gate the deploy with a manual approval.

---

## How a deploy happens
1. Push to `main` (or run the workflow manually).
2. `test` boots the app and checks `/health`.
3. `build-and-push` builds the image, scans it with Trivy, pushes it to ECR tagged `sha-<commit>`.
4. `deploy` (after approval, if configured) does a rolling ECS update and waits for stability.

The app URL is the ALB's DNS name.

## Rollback
Every image stays in ECR, so rollback is a redeploy of a previous task-definition revision:
```bash
aws ecs update-service --cluster node-application-prod --service node-application-prod \
  --task-definition node-application-prod:<previous-revision> --force-new-deployment
```

---

> When you want this infrastructure reproducible and reviewable (the enterprise
> standard), move the console steps above into **Terraform** — ask and it can be
> regenerated.
