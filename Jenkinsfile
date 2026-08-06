  pipeline {
      agent any

      tools {
          jdk 'jdk-25'
          maven 'maven-3'
      }

      stages {
          stage('Check tools') {
              steps {
                  sh 'java --version'
                  sh 'mvn --version'
                  sh 'git --version'
                  sh 'docker --version'
                  sh 'docker ps'
              }
          }
      }
  }
	 
