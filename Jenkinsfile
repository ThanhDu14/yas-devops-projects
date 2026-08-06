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
      }
  }
