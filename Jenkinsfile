  pipeline {
      agent any

      tools {
          jdk 'jdk-25'
          maven 'maven-3'
      }

      stages {
          stage('checkout'){
            steps{
                checkout scm
            }
          }
          stage('Detect Changed services'){
            steps{
                script {
                    env.CHANGED_SERVICES = sh(
                        scripts: '.jenkins/scripts/detect-changed-service.sh',
                        returnStdout: true
                    ).trim()
                    echo "Services need runs: ${env.CHANGED_SERVICES}"
                }
            }
          }
      }
  }
	 
