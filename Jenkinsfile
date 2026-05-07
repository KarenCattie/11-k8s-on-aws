pipeline {
    agent any

    environment {
        AWS_REGION       = 'ca-central-1'
        ECR_REGISTRY     = '790400775070.dkr.ecr.ca-central-1.amazonaws.com'
        ECR_REPOSITORY   = 'aws-java-app'
        IMAGE_NAME       = "${ECR_REGISTRY}/${ECR_REPOSITORY}"
        EKS_CLUSTER      = 'my-cluster'
        K8S_NAMESPACE    = 'my-app'
        DEPLOYMENT_NAME  = 'java-app-deployment'
        CONTAINER_NAME   = 'java-mysql-app'                                    // matches container name in java-app.yaml
    }

    stages {
        stage('Set Image Version') {
            steps {
                script {
                    // Simple versioning: project version + Jenkins build number
                    // e.g. 1.0-12 (build #12). No git tags, no gradle version bump — keep it light.
                    env.IMAGE_VERSION = "1.0-${BUILD_NUMBER}"
                    echo "Building image version: ${env.IMAGE_VERSION}"
                }
            }
        }

        stage('Build & Test Docker Image') {
            when { branch 'main' }
            steps {
                // Tests run INSIDE the multi-stage Dockerfile (gradle build).
                // If any test fails, gradle build exits non-zero, docker build fails,
                // and this stage fails — same testing guarantee, no host-mount issues.
                echo 'Building Docker image (Gradle build + tests run inside the build stage)...'
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_VERSION} ."
            }
        }

        stage('Push to ECR') {
            when { branch 'main' }
            steps {
                // Same ECR login pattern you used before — relies on the EC2 instance's IAM role
                // (or AWS creds inside the Jenkins container) having ECR push permission.
                sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                sh "docker push ${IMAGE_NAME}:${IMAGE_VERSION}"
            }
        }

        stage('Deploy to EKS') {
            when { branch 'main' }
            steps {
                script {
                    // 1. Tell kubectl how to reach the cluster.
                    //    This generates ~/.kube/config inside the Jenkins container pointing to my-cluster.
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}"

                    // 2. Update the running deployment's image to the version we just pushed.
                    //    'kubectl set image' is cleaner than editing the YAML file:
                    //    it patches the live deployment in-place and triggers a rolling update.
                    sh """
                        kubectl set image deployment/${DEPLOYMENT_NAME} \
                            ${CONTAINER_NAME}=${IMAGE_NAME}:${IMAGE_VERSION} \
                            -n ${K8S_NAMESPACE}
                    """

                    // 3. Wait for the rollout to finish before declaring victory.
                    //    If new pods crash-loop, this will fail the build — exactly what we want.
                    sh "kubectl rollout status deployment/${DEPLOYMENT_NAME} -n ${K8S_NAMESPACE} --timeout=300s"
                }
            }
        }
    }

    post {
        success {
            echo "Deployed ${IMAGE_NAME}:${IMAGE_VERSION} to EKS successfully!"
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
