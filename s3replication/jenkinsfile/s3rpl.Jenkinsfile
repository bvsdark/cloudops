pipeline {

    agent {
        label 'master'
    }

  environment {
    region = 'us-east-1'
  }

  parameters {
    string(name: 'SourceBucket', defaultValue: 'sourcesync001', description: 'The SOURCE bucket from which the data will be replicated. SOURCE --> DESTINATION')
    string(name: 'DestBucket', defaultValue: 'destsync001', description: 'The DESTINATION bucket receiving the data from SOURCE bucket.')
    choice(name: 'Terminate', choices: ['False','True'], description: 'Disable replication')
  }

  stages {
     stage ('FindBuckets') {
       steps {
            script {
                     sh '''#!/usr/bin/env bash
                     source $WORKSPACE/s3replication/scripts/./s3rpl.sh
                        '''
            }
       }
    }
  }
 }
 