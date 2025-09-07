### 🚀 Project 2: Automated Deployment Pipeline (AWS)

A complete CI/CD pipeline that automatically tests, builds, and deploys your Node.js web application to AWS ECS Fargate using GitHub Actions.

---

## 🌐 What This Project Delivers

- ✅ Node.js web application with health checks
- ✅ Docker containerization
- ✅ ESLint integration with Airbnb style guide
- ✅ AWS ECR for container storage
- ✅ AWS ECS Fargate for serverless hosting
- ✅ GitHub Actions CI/CD pipeline
- ✅ Live production URL
- ✅ Optional staging environment
- ✅ CloudWatch logging and monitoring

---

## 🛠️ Prerequisites

Before you begin, ensure the following tools are installed:

- [Node.js](https://nodejs.org/) v18+
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [AWS CLI](https://aws.amazon.com/cli/) v2
- [Git](https://git-scm.com/)
- GitHub account
- AWS account (free tier is sufficient)

---


## 📁 Project Structure
```
.
├── app.js
├── package.json
├── Dockerfile
├── .dockerignore
├── .gitignore
├── .eslintrc.js
├── aws-setup.sh
├── test/
├── coverage/
└── .github/
    └── workflows/
        └── deploy-aws.yml
```

---

## ✅ Step-by-Step Setup

### 1. Test Locally

Install dependencies 
```bash
npm install
```

Test the application
```bash
npm start
```

- App: [http://localhost:3001](http://localhost:3001)
- Health: `/health`
- API: `/api/info`

---

### 2. Test Docker Build

```bash
docker build -t my-webapp .
docker run -p 3001:3001 -e ENVIRONMENT=local my-webapp
```

---

### 3. Provision AWS Infrastructure

```bash
aws configure
aws sts get-caller-identity
chmod +x aws-setup.sh
./aws-setup.sh
```

This script creates:
- ECR repository
- ECS cluster and service
- IAM roles
- Security group
- CloudWatch log group
- Initial task definition

---

### 4. Add GitHub Repository Secrets

Go to: **Settings → Secrets and variables → Actions**

Add the following secrets:

| Secret Name              | Value from Script         |
|--------------------------|---------------------------|
| AWS_ACCESS_KEY_ID        | IAM access key            |
| AWS_SECRET_ACCESS_KEY    | IAM secret key            |
| AWS_REGION               | `us-east-1`               |
| ECR_REPOSITORY           | `my-webapp`               |
| ECR_REGISTRY             | ECR URI                   |
| ECS_CLUSTER              | `webapp-cicd-cluster`     |
| ECS_SERVICE              | `webapp-cicd-service`     |
| ECS_TASK_DEFINITION      | `webapp-cicd-task`        |
| SMTP_USERNAME            | SMTP email username       |
| SMTP_PASSWORD            | SMTP app password         |
| NOTIFICATION_EMAIL       | Recipient email for alerts|


---

### 5. Deploy via GitHub

```bash
git init
git add .
git commit -m "Initial commit: AWS DevOps webapp with CI/CD"
git branch -M main
git remote add origin https://github.com/YOURUSERNAME/YOURREPO.git
git push -u origin main
```

---

### 6. Watch the Magic Happen

- Go to your GitHub repo → **Actions tab**
- Observe the workflow:
  - ✅ Test Stage
  - ✅ Build & Push to ECR
  - ✅ Deploy to ECS

Look for:

```
🚀 Your app is live at: http://[IP]:3001
```
        
---

### 7. Test Your Live App

Once deployed, access your app via the public IP:

- App: `http://[IP]:3001`
- Health: `/health`
- API: `/api/info`

---

## 🧪 Testing Setup

Install testing tools:

```bash
npm install --save-dev jest supertest
```

Example test in `test/app.test.js`:

```js
const request = require('supertest');
const app = require('../app');

test('GET /health returns 200', async () => {
  const res = await request(app).get('/health');
  expect(res.statusCode).toBe(200);
});
```

Add to GitHub Actions:

```yaml
- name: Run tests
  run: npm test
```

---

## 🧼 ESLint Configuration

`.eslintrc.js`:

```js
module.exports = {
  env: {
    node: true,
    commonjs: true,
    es2021: true,
    jest: true,
  },
  extends: 'airbnb-base',
  parserOptions: {
    ecmaVersion: 'latest',
  },
  rules: {
    'no-console': 'off',
    'import/extensions': ['error', 'ignorePackages'],
  },
};
```

---

## 📦 .dockerignore

```dockerignore
node_modules
npm-debug.log
.git
.gitignore
README.md
.dockerignore
Dockerfile
test/
coverage/
.eslintrc.js
```

---

## 📦 .gitignore

```gitignore
node_modules/         # Dependencies
npm-debug.log         # Logs
coverage/             # Test coverage
.env                  # Secrets
.DS_Store             # macOS system file
.nyc_output/          # Coverage output
dist/                 # Build artifacts
build/                # Compiled output
```

---

## 📈 Advanced Features

### 🔀 Blue-Green Deployments

Deploy to a second ECS service (`webapp-green-service`) and switch traffic using ALB or DNS.

```bash
aws ecs update-service \
  --cluster webapp-cicd-cluster \
  --service webapp-green-service \
  --force-new-deployment
```

---

### 🧩 Connect a Database

Provision RDS:

```bash
aws rds create-db-instance \
  --db-instance-identifier webapp-db \
  --engine postgres \
  --master-username admin \
  --master-user-password yourpassword \
  --allocated-storage 20 \
  --publicly-accessible
```

Add `DATABASE_URL` to GitHub secrets and use in your app:

```js
const dbUrl = process.env.DATABASE_URL;
```

---

### 🧪 Staging/Prod Separation

Run setup with a different cluster name:

```bash
CLUSTER_NAME="webapp-staging-cluster"
./aws-setup.sh
```

Use GitHub environments to separate workflows.

        
### ✅ Step 8: Making Changes

```bash
git add app.js
git commit -m "Updated welcome message"
git push
```

* GitHub Actions redeploys automatically
* Update live in \~3-5 mins

---

## 📊 How It Works

### Pipeline Flow

1. Code Push → GitHub Actions Trigger
2. Test Stage → Run tests and Docker build
3. Build & Push → Image pushed to ECR
4. Deploy → ECS service updated
5. App goes live!

### AWS Components

* **ECR**: Docker image registry
* **ECS Fargate**: Serverless container hosting
* **CloudWatch**: Logs and metrics
* **IAM**: Secure permission control
* **VPC/Security Groups**: Network access

---

## 🔧 Troubleshooting

### 🖥️ Local Issues
* **npm install fails**

```bash
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
```

• Reinstall dependencies from scratch.
• Make sure you’re using Node.js v18+ (node -v).

⸻

* **Port 3001 already in use**

```bash
lsof -ti :3001 | xargs kill -9
PORT=3002 npm start
```

• Kill the process holding the port or run the app on a new port.

⸻

* **Docker build fails with “node_modules not found”**

```bash
docker system prune -af
docker build -t my-webapp .
```bash

• Clean up Docker cache and rebuild.
• Double-check .dockerignore includes node_modules/.

⸻

* **Container exits immediately**

```bash
docker logs <container_id>
```

• Ensure npm start is the correct command in Dockerfile.
• Verify EXPOSE 3001 is present and app listens on 0.0.0.0, not localhost.

⸻

### ☁️ AWS Issues
• AWS CLI not configured

```bash
aws configure
aws sts get-caller-identity
```

• Ensure your access key, secret, and region are set.

⸻

* **Permission denied (IAM)**

• Attach AdministratorAccess policy (for testing only).
• For production, create a role with:
• AmazonEC2ContainerRegistryFullAccess
• AmazonECS_FullAccess
• CloudWatchLogsFullAccess

⸻

* **script aws-setup.sh fails**

```bash
aws --version
bash -x aws-setup.sh
```

• Check for syntax errors or missing permissions.
• Ensure chmod +x aws-setup.sh is run first.

⸻

* **ECR authentication error (no basic auth credentials)**
        
```bash
aws ecr get-login-password --region us-east-1 \
| docker login --username AWS --password-stdin <account_id>.dkr.ecr.us-east-1.amazonaws.com
```

• Ensure you log in to ECR before pushing.

⸻

### ⚙️ GitHub Actions Issues
* **Workflow not running**

• File must be in .github/workflows/deploy-aws.yml.
• Ensure workflows are enabled under repo → Settings → Actions.
• Secrets are case-sensitive.

⸻

* **Authentication failed**

• Recheck AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.
• Ensure your IAM user has ECS/ECR permissions.

⸻

* **ECR push failed**

• Verify repository exists in ECR:

```bash
aws ecr describe-repositories
```

• If missing, create it:

```bash
aws ecr create-repository --repository-name my-webapp
```



⸻

* **Timeouts in GitHub Actions**

• Add retries in Docker login/push steps.
• Check runner has internet access (self-hosted runners may block Docker Hub).

⸻

### 🚀 Deployment Issues
* **ECS service not updating**

• Check ECS service events in AWS console.
• Run:

```bash
aws ecs describe-services --cluster webapp-cicd-cluster --services webapp-cicd-service
```



⸻

* **App not accessible**

• Wait 3–5 minutes for ECS to provision.
• Ensure security group allows inbound on port 3001.
• If using ALB, check target group health checks.

⸻

* **Container keeps restarting**

```bash
aws logs tail /ecs/webapp-cicd-task --follow
```

• Verify app listens on correct port (process.env.PORT || 3001).
•  Check for missing env variables (DATABASE_URL, API_KEY).

⸻

* **ECS task stuck in PENDING**

• Likely insufficient Fargate resources or no subnets.
• Ensure your cluster has public subnets with internet access or private subnets with a NAT gateway.

⸻

* **Health check failing in ECS**

• ECS default health check path is /.
• Update task definition or ALB target group health check to /health.

⸻

* **CloudWatch logs not showing up**

• Ensure task definition includes:

```json
"logConfiguration": {
  "logDriver": "awslogs",
  "options": {
    "awslogs-group": "/ecs/webapp-cicd-task",
    "awslogs-region": "us-east-1",
    "awslogs-stream-prefix": "ecs"
  }
}
```
        
⸻

* **Container restarting**:

  * Check CloudWatch logs using `aws logs` to debug
  * Common issue: App not listening on correct port

---

## 📈 Advanced Features

### Environment Variables

```javascript
const dbUrl = process.env.DATABASE_URL || 'localhost';
const apiKey = process.env.API_KEY || 'dev-key';
```

### Multiple Environments

```bash
CLUSTER_NAME="webapp-staging-cluster"
./aws-setup.sh
```

### Monitoring & Alerts

* Use CloudWatch Logs
* Add alarms for CPU/memory thresholds

---
---

## 🧹 Clean Up Resources

```bash
aws ecs update-service --cluster webapp-cicd-cluster --service webapp-cicd-service --desired-count 0
aws ecs delete-service --cluster webapp-cicd-cluster --service webapp-cicd-service --force
aws ecs delete-cluster --cluster webapp-cicd-cluster
aws ecr delete-repository --repository-name my-webapp --force
aws logs delete-log-group --log-group-name /ecs/webapp-cicd-task
```

(Optional: delete IAM user and keys if created)
        
---

## 🧠 What You Learned

- ✅ Node.js app deployment best practices
- ✅ Docker containerization
- ✅ ESLint and linting rules
- ✅ GitHub Actions CI/CD pipelines
- ✅ AWS ECS Fargate + ECR usage
- ✅ IAM security roles
- ✅ Infrastructure automation
- ✅ CloudWatch monitoring
- ✅ Blue-green deployments
- ✅ Staging/production separation

---

## 🚀 Next Steps

* Add AWS X-Ray for distributed tracing.
* Configure CloudWatch Alarms and SNS notifications for failures.
* Enable AWS WAF or Shield for protection against DDoS and OWASP Top 10 threats.
* Use AWS Secrets Manager or SSM Parameter Store for secrets instead of plain environment variables.
* Add container runtime security with Falco or Sysdig Secure.
* Implement AWS CodeDeploy + ECS for traffic-shift canaries.
* Add rollback strategy if deployment health checks fail.
* Add integration tests and end-to-end (E2E) tests using Playwright or Cypress.
* Collect test coverage reports with Jest + Istanbul and upload to GitHub Actions.
* Move to **Project 3: Kubernetes Orchestration**

🎉 **Congratulations! You built a full AWS DevOps pipeline!**//
