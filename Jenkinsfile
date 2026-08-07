  pipeline {
      agent any

      tools {
          jdk 'jdk-25'
          maven 'maven-3'
      }

      stages {
          stage('Detect Changed Services') {
              steps {
                  script {
                      env.CHANGED_SERVICES = sh(
                          script: '.jenkins/scripts/detect-changed-services.sh',
                          returnStdout: true
                      ).trim()

                      echo "Services need runs: ${env.CHANGED_SERVICES}"
                  }
              }
          }
        stage('Test changed Services'){
                when{
                    expression{
                        return env.CHANGED_SERVICES?.trim()
                    }
                }
                steps{
                    sh '.jenkins/scripts/test-changed-services.sh "${CHANGED_SERVICES}"'
                }
                post{
                    always{
                        junit allowEmptyResults: true , testResults: '**/target/surefire-reports/*.xml,**/target/failsafe-reports/*.xml'
                        archiveArtifacts allowEmptyArchive: true, artifacts: '**/target/site/jacoco/**/*'
                    }
                }
        }
      }
  }
