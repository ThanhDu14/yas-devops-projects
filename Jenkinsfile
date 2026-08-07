pipeline {
    agent any

    parameters {
        string(name: 'TARGET_SERVICES', defaultValue: '', description: 'Manually specify services to test/build (space-separated, e.g. "media product"). Leave empty for auto-detect.')
        booleanParam(name: 'RUN_INTEGRATION_TESTS', defaultValue: true, description: 'Run full Integration Tests (mvn verify with Testcontainers)')
        booleanParam(name: 'RUN_SECURITY_SCAN', defaultValue: true, description: 'Run Gitleaks secret scan stage')
    }

    tools {
        jdk 'jdk-25'
        maven 'maven-3'
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
                        if command -v gitleaks > /dev/null 2>&1; then
                            gitleaks detect --source . -v
                        else
                            echo "Gitleaks CLI not found on Jenkins agent. Skipping Gitleaks scan."
                        fi
                    '''
                }
            }
        }

        stage('Test Changed Services') {
            when {
                expression { return env.CHANGED_SERVICES?.trim() }
            }
            steps {
                sh '.jenkins/scripts/test-changed-services.sh "${CHANGED_SERVICES}" "${params.RUN_INTEGRATION_TESTS}"'
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml,**/target/failsafe-reports/*.xml'
                    archiveArtifacts allowEmptyArchive: true, artifacts: '**/target/site/jacoco/**/*'
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
