pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '5', artifactNumToKeepStr: '3'))
        timeout(time: 60, unit: 'MINUTES')
    }

    parameters {
        string(name: 'TARGET_SERVICES', defaultValue: '', description: 'Chỉ định danh sách services cần build/test (cách nhau bởi dấu cách, vd: "media product"). Để trống để tự động nhận diện.')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Bỏ qua Unit/Integration Tests và SonarCloud để Build & Deploy nhanh (Chỉ dùng cho dev/hotfix, cấm trên main)')
        booleanParam(name: 'RUN_INTEGRATION_TESTS', defaultValue: false, description: 'Chạy Full Integration Tests (mvn verify với Testcontainers)')
        booleanParam(name: 'RUN_SECURITY_SCAN', defaultValue: true, description: 'Chạy quét rò rỉ bí mật với Gitleaks')
        booleanParam(name: 'FAIL_ON_SECURITY_VULN', defaultValue: false, description: 'Chặn đứng Pipeline (FAIL) nếu phát hiện lộ Secret hoặc lỗ hổng CRITICAL')
        booleanParam(name: 'DEPLOY_TO_GCP', defaultValue: false, description: 'Deploy lên hạ tầng GCP sau khi build thành công')
    }

    tools {
        jdk 'jdk-25'
        maven 'maven-3'
    }

    environment {
        TESTCONTAINERS_RYUK_DISABLED = 'true'
        PATH = "/tmp/bin:${env.PATH}"
    }

    stages {
        // ==========================================
        // GUARD: Kiểm tra tính hợp lệ của tham số
        // ==========================================
        stage('Guard: Validate Branch Rules') {
            steps {
                script {
                    def branch = env.BRANCH_NAME ?: env.GIT_BRANCH ?: ''
                    if (branch.contains('main') && params.SKIP_TESTS && params.DEPLOY_TO_GCP) {
                        error("⛔ VI PHẠM CHÍNH SÁCH BẢO MẬT: Không được phép bật SKIP_TESTS khi deploy nhánh 'main' lên Production!")
                    }
                }
            }
        }

        // ==========================================
        // PHẦN 1: CI (Continuous Integration)
        // ==========================================
        stage('Clean Old Artifacts') {
            steps {
                sh '''
                    echo "🧹 Dọn dẹp target directories và reports cũ..."
                    find . -type d -name "target" -prune -exec rm -rf {} + 2>/dev/null || true
                    rm -f gitleaks-report.json trivy-report.json BAO_CAO_CI.md 2>/dev/null || true
                '''
            }
        }

        stage('Detect Changed Services') {
            steps {
                script {
                    if (params.TARGET_SERVICES?.trim()) {
                        env.CHANGED_SERVICES = params.TARGET_SERVICES.trim()
                        echo "👉 Sử dụng danh sách services thủ công: ${env.CHANGED_SERVICES}"
                    } else {
                        env.CHANGED_SERVICES = sh(
                            script: '.jenkins/scripts/detect-changed-services.sh',
                            returnStdout: true
                        ).trim()
                        echo "🔍 Tự động phát hiện các services thay đổi: ${env.CHANGED_SERVICES}"
                    }
                }
            }
        }

        stage('Security Scan (Gitleaks)') {
            when {
                expression { return params.RUN_SECURITY_SCAN }
            }
            steps {
                script {
                    def failOnVuln = params.FAIL_ON_SECURITY_VULN ? 'true' : 'false'
                    sh """
                        if ! command -v gitleaks > /dev/null 2>&1 && [ ! -f /tmp/bin/gitleaks ]; then
                            echo "⬇️ Đang tải Gitleaks binary..."
                            mkdir -p /tmp/bin
                            curl -sSL https://github.com/gitleaks/gitleaks/releases/download/v8.24.0/gitleaks_8.24.0_linux_x64.tar.gz | tar -xz -C /tmp/bin
                            chmod +x /tmp/bin/gitleaks
                        fi
                        export PATH="/tmp/bin:\$PATH"

                        if [ "${failOnVuln}" = "true" ]; then
                            echo "🔒 Security Gate: Bật chế độ chặn cứng nếu phát hiện lộ Secret!"
                            gitleaks detect --source . -v --report-path gitleaks-report.json --report-format json
                        else
                            echo "ℹ️ Security Gate: Chế độ cảnh báo (ghi log vào báo cáo)."
                            gitleaks detect --source . -v --report-path gitleaks-report.json --report-format json || true
                        fi
                    """
                }
            }
        }

        stage('Test Changed Services') {
            when {
                allOf {
                    expression { return !params.SKIP_TESTS }
                    expression { return env.CHANGED_SERVICES?.trim() }
                }
            }
            steps {
                script {
                    def runIt = params.RUN_INTEGRATION_TESTS != null ? params.RUN_INTEGRATION_TESTS.toString() : "false"
                    sh ".jenkins/scripts/test-changed-services.sh \"${env.CHANGED_SERVICES}\" \"${runIt}\""
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml,**/target/failsafe-reports/*.xml'
                    archiveArtifacts allowEmptyArchive: true, artifacts: '**/target/site/jacoco/**/*'
                }
            }
        }

        stage('Quality Analysis (SonarCloud)') {
            when {
                allOf {
                    expression { return !params.SKIP_TESTS }
                    expression { return env.CHANGED_SERVICES?.trim() }
                }
            }
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh 'mvn -B -pl "${CHANGED_SERVICES}" -am org.sonarsource.scanner.maven:sonar-maven-plugin:sonar -Dsonar.token=$SONAR_TOKEN -Dsonar.organization=thanhdu14 -Dsonar.projectKey=ThanhDu14_yas-devops-projects || true'
                }
            }
        }

        stage('Vulnerability Scan (Trivy)') {
            steps {
                script {
                    def failOnVuln = params.FAIL_ON_SECURITY_VULN ? 'true' : 'false'
                    sh """
                        if ! command -v trivy > /dev/null 2>&1 && [ ! -f /tmp/bin/trivy ]; then
                            echo "⬇️ Đang tải Trivy binary..."
                            mkdir -p /tmp/bin
                            curl -sSL https://github.com/aquasecurity/trivy/releases/download/v0.73.0/trivy_0.73.0_Linux-64bit.tar.gz | tar -xz -C /tmp/bin trivy
                            chmod +x /tmp/bin/trivy
                        fi
                        export PATH="/tmp/bin:\$PATH"

                        echo "🛡️ Quét lỗ hổng thư viện (Trivy)..."
                        trivy fs --offline-scan --skip-version-check --scanners vuln --severity HIGH,CRITICAL --format json -o trivy-report.json --no-progress . || true
                        if [ ! -f trivy-report.json ] || [ ! -s trivy-report.json ]; then
                            echo '{"Results": []}' > trivy-report.json
                        fi

                        if [ "${failOnVuln}" = "true" ]; then
                            echo "🔒 Security Gate: Kiểm tra chặn nếu tồn tại lỗ hổng CRITICAL!"
                            trivy fs --offline-scan --skip-version-check --scanners vuln --severity CRITICAL --exit-code 1 --no-progress .
                        fi
                    """
                }
            }
        }

        stage('Build Changed Services') {
            when {
                expression { return env.CHANGED_SERVICES?.trim() }
            }
            steps {
                sh '.jenkins/scripts/build-changed-services.sh "${CHANGED_SERVICES}"'
            }
        }

        // ==========================================
        // PHẦN 2: CD (Continuous Deployment) → GCP
        // ==========================================
        stage('Approval for Deployment') {
            when {
                expression { return params.DEPLOY_TO_GCP }
            }
            steps {
                script {
                    def deployBranch = env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'current'
                    timeout(time: 15, unit: 'MINUTES') {
                        input message: "❓ Bạn có chắc chắn muốn Deploy nhánh [${deployBranch}] lên GCP?", ok: '🚀 Chấp thuận Deploy'
                    }
                }
            }
        }

        stage('Push Docker Images to GAR') {
            when {
                allOf {
                    expression { return params.DEPLOY_TO_GCP }
                    expression { return env.CHANGED_SERVICES?.trim() }
                }
            }
            steps {
                withCredentials([
                    string(credentialsId: 'gcp-project-id', variable: 'GCP_PROJECT_ID'),
                    string(credentialsId: 'gcp-region', variable: 'GCP_REGION'),
                    file(credentialsId: 'gcp-service-account-key', variable: 'GCP_SA_KEY')
                ]) {
                    sh '''
                        if ! command -v gcloud > /dev/null 2>&1 && [ ! -f /tmp/google-cloud-sdk/bin/gcloud ]; then
                            echo "⬇️ Đang tải Google Cloud SDK..."
                            curl -sSL https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz | tar -xz -C /tmp
                        fi
                        export PATH="/tmp/google-cloud-sdk/bin:$PATH"

                        export GAR_REPO="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/yas-docker-repo"
                        echo "🔐 Xác thực với Google Cloud..."
                        if [ -f "$GCP_SA_KEY" ]; then
                            gcloud auth activate-service-account --key-file="$GCP_SA_KEY"
                        fi
                        gcloud config set project "$GCP_PROJECT_ID"

                        # Truyền Short Commit SHA để tag image chính xác
                        export GIT_COMMIT_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo '')"

                        echo "🐳 Build & Push Docker Images..."
                        .jenkins/scripts/push-images.sh "${CHANGED_SERVICES}"
                    '''
                }
            }
        }

        stage('Deploy Backend to VM (MIG)') {
            when {
                expression { return params.DEPLOY_TO_GCP }
            }
            steps {
                withCredentials([
                    string(credentialsId: 'gcp-project-id', variable: 'GCP_PROJECT_ID'),
                    string(credentialsId: 'gcp-region', variable: 'GCP_REGION'),
                    file(credentialsId: 'gcp-service-account-key', variable: 'GCP_SA_KEY')
                ]) {
                    sh '''
                        export PATH="/tmp/google-cloud-sdk/bin:$PATH"
                        export GAR_REPO="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/yas-docker-repo"
                        echo "🔐 Xác thực với Google Cloud..."
                        if [ -f "$GCP_SA_KEY" ]; then
                            gcloud auth activate-service-account --key-file="$GCP_SA_KEY"
                        fi
                        gcloud config set project "$GCP_PROJECT_ID"

                        echo "🚀 Deploy Backend lên VM trong MIG..."
                        export BRANCH_NAME="${BRANCH_NAME:-${GIT_BRANCH:-main}}"
                        .jenkins/scripts/deploy-backend.sh
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                sh '''
                    if command -v python3 > /dev/null 2>&1; then
                        python3 .jenkins/scripts/generate-report.py
                    elif command -v python > /dev/null 2>&1; then
                        python .jenkins/scripts/generate-report.py
                    else
                        echo "Python not found to generate markdown report."
                    fi
                    # Dọn dẹp triệt để Build Cache và dangling images sau khi build
                    docker builder prune -f 2>/dev/null || true
                    docker system prune -f 2>/dev/null || true
                '''
                archiveArtifacts allowEmptyArchive: true, artifacts: 'BAO_CAO_CI.md, gitleaks-report.json, trivy-report.json'
            }
        }
        success {
            script {
                if (params.DEPLOY_TO_GCP) {
                    echo """
                    ========================================
                    🎉 CI/CD PIPELINE HOÀN TẤT!
                    ========================================
                    ✅ CI: Test, Scan, Build → PASSED
                    ✅ CD: Deploy lên GCP → THÀNH CÔNG
                    ========================================
                    """
                }
            }
        }
        failure {
            echo "❌ Pipeline thất bại! Kiểm tra logs để biết chi tiết."
        }
    }
}
