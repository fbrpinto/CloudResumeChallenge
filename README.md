# Cloud Resume Challenge

This project is my solution for the [Cloud Resume Challenge](https://cloudresumechallenge.dev/), where I applied my knowledge of cloud computing, DevOps practices, and automation. The goal of the challenge was to build a serverless web application that tracks resume views and hosts the resume on AWS.

## Components

### 1. **Frontend (HTML/CSS)**
- The resume is designed using basic HTML and CSS and is hosted on an AWS S3 bucket configured for static website hosting.

### 2. **Backend (API Gateway + Lambda)**
- A serverless function (AWS Lambda) is triggered by API Gateway to update a visitor counter in the DynamoDB database every time the resume is viewed.

### 3. **Database (DynamoDB)**
- AWS DynamoDB is used to store the view counter.

### 4. **Infrastructure as Code (Terraform)**
- Terraform is used to manage and provision AWS resources, such as S3 buckets, DynamoDB tables, Lambda functions, and API Gateway.

### 5. **CI/CD Pipeline**
- GitHub Actions is used to automate the testing and deployment of infrastructure and code. The CI/CD pipeline automatically deploys changes to the AWS environment upon every commit to the main branch that passes the tests.

### 6. **Monitoring & Alerts**
- CloudWatch is used to monitor Lambda execution metrics and errors.
- Slack is configured for real-time alerts on any issues, including Lambda function errors.
- PagerDuty is used for enhanced monitoring and alerting.

### 7. **Testing**
- Unit and end-to-end tests are implemented using Cypress and Python’s unittest module. These ensure that the counter is updated correctly and that the Lambda function behaves as expected.

## AWS Services Used
- **S3:** Hosts the static resume.
- **CloudFront:** Distributes website content with low latency and high performance.
- **API Gateway:** Routes requests to the Lambda function.
- **Lambda:** Executes the serverless function to update the view counter.
- **DynamoDB:** Stores the view count in a NoSQL database.
- **IAM:** Manages roles and permissions for securing AWS resources.
- **CloudWatch:** Monitors logs and sends error alerts.
- **SNS:** Sends notifications via Slack/Datadog when an error occurs.

## CI/CD Pipelines

### Infrastructure CI/CD Pipeline
This pipeline deploys infrastructure using Terraform when changes are pushed to the main branch in the `infrastructure/` directory. It sets up and configures the frontend and backend infrastructure by generating TFVars files, initializing Terraform, planning, and applying the changes. AWS credentials are securely managed through GitHub secrets.

### Backend CI/CD Pipeline
This pipeline packages, tests, and deploys a Lambda function when changes are pushed to the main branch in the `backend/` directory. It builds the function, runs unit tests, and uploads the updated code to AWS Lambda using GitHub secrets for credentials.

### Frontend CI/CD Pipeline
This pipeline runs Cypress tests and deploys the frontend to an S3 bucket when changes are pushed to the main branch in the `frontend/` directory. It starts a local server, executes tests, and syncs the updated code with the S3 bucket using AWS credentials stored in GitHub secrets.

## Structure
The project is organized into four main directories:

- `/backend/`: Contains the backend code and Python unit tests.
- `/frontend/`: Contains the frontend application code and Cypress tests.
- `/infrastructure/`: Contains Terraform scripts for provisioning resources for the frontend and backend, along with a setup file for the Terraform backend to support GitHub Actions deployment.
- `.github/workflows/`: Contains the CI/CD pipelines for automating testing and deployment to AWS.

## License
This project is licensed under the MIT License.
