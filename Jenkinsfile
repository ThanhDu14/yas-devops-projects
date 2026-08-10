pipeline {
    agent any

    parameters {
        string(name: 'TARGET_SERVICES', defaultValue: '', description: 'Manually specify services to test/build (space-separated, e.g. "media product"). Leave empty for auto-detect.')
        booleanParam(name: 'RUN_INTEGRATION_TESTS', defaultValue: false, description: 'Run full Integration Tests (mvn verify with Testcontainers)')
        booleanParam(name: 'RUN_SECURITY_SCAN', defaultValue: true, description: 'Run Gitleaks secret scan stage')
    }

    tools {
        jdk 'jdk-25'
        maven 'maven-3'
    }

    environment {
        TESTCONTAINERS_RYUK_DISABLED = 'true'
        TESTCONTAINERS_HOST_OVERRIDE = 'host.docker.internal'
    }

    stages {
        stage('Detect Changed Services') {
            steps {
                script {
                    if (params.TARGET_SERVICES?.trim()) {
                        env.CHANGED_SERVICES = params.TARGET_SERVICES.trim()
                        echo "Using manually specified services: ${env.CHANGED_SERVICES}"
                    } else {
                        env.CHANGED_SERVICES = sh(
                            script: '.jenkins/scripts/detect-changed-services.sh',
                            returnStdout: true
                        ).trim()
                        echo "Auto-detected changed services: ${env.CHANGED_SERVICES}"
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
                    sh '''
                        if ! command -v gitleaks > /dev/null 2>&1; then
                            echo "Downloading Gitleaks binary..."
                            mkdir -p /tmp/bin
                            curl -sSL https://github.com/gitleaks/gitleaks/releases/download/v8.24.0/gitleaks_8.24.0_linux_x64.tar.gz | tar -xz -C /tmp/bin
                            export PATH="/tmp/bin:$PATH"
                        fi
                        gitleaks detect --source . -v || true
                    '''
                }
            }
        }

        stage('Test Changed Services') {
            when {
                expression { return env.CHANGED_SERVICES?.trim() }
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
                expression { return env.CHANGED_SERVICES?.trim() }
            }
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh 'mvn -B -pl "${CHANGED_SERVICES}" -am org.sonarsource.scanner.maven:sonar-maven-plugin:sonar -Dsonar.token=$SONAR_TOKEN -Dsonar.organization=thanhdu14 -Dsonar.projectKey=ThanhDu14_yas-devops-projects'
                }
            }
        }

        stage('Vulnerability Scan (Trivy)') {
            steps {
                script {
                    sh '''
                        if ! command -v trivy > /dev/null 2>&1; then
                            echo "Downloading Trivy binary..."
                            mkdir -p /tmp/bin
                            curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /tmp/bin
                            export PATH="/tmp/bin:$PATH"
                        fi
                        trivy fs . --severity HIGH,CRITICAL --no-progress || true
                    '''
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
    }
}
