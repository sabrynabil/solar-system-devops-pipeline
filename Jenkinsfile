pipeline {
    agent any
    tools { 
            nodejs 'nodejs-22-6-0' 
        }
    environment {
            MONGO_URI = 'mongodb+srv://supercluster.d83jj.mongodb.net/superData'
            MONGO_DB_CREDS = credentials('MONGO_DB_CRED')
            MONGO_USERNAME= credentials('MONGO_DB_USR')
            MONGO_PASSWORD= credentials('MONGO_DB_PWD')
            SONAR_SCANNER_HOME = tool 'sonarqube-scanner-730' ;
            GITEA_TOKEN= credentials('gitea-api-token')

        }


    stages {
        stage('Installing Dependencies') {
            steps {
                sh 'npm install'
            }
        }

        stage('Dependencies Check') {
            parallel {
                stage('NPM Audit Dependencies') {
                    steps {
                        sh 'npm audit --audit-level=critical '
                    }
                }

                stage('OWASP Dependencies') {
                    steps {
                        // latest owasp check version 12.3.6
                        dependencyCheck additionalArguments: '''
                            --scan \'./\'
                            --out \'./\'
                            --format \'ALL\'
                            --disableYarnAudit
                            --prettyPrint''', odcInstallation: 'owasp-check'
                        dependencyCheckPublisher failedTotalCritical: 2, pattern: 'dependency-check-report.xml', stopBuild: true
                    }
                }
            }
        }
        stage('Unit Test') {
            steps {
                    sh 'echo $MONGO_DB_CREDS'
                    sh 'echo $MONGO_DB_CREDS_USR'
                    sh 'echo $MONGO_DB_CREDS_PSD'
                    sh 'npm test -- --reporter spec'
                }
            
         }
        stage('Code Coverage') {
            steps {
                catchError(buildResult: 'SUCCESS', message: 'Opss, i Will fix it in the future', stageResult: 'UNSTABLE') {
                    sh 'npm run coverage'
                }  
            }
         }
        stage('SAST Analysis / SonarQube Scan') {
            
            steps {
                timeout(time: 250, unit: 'SECONDS') {
                    withSonarQubeEnv('sonarqube-server') {
                        sh ' echo $SONAR_SCANNER_HOME '
                        sh '''
                        $SONAR_SCANNER_HOME/bin/sonar-scanner \
                        -Dsonar.projectKey=Solar-System-Project \
                        -Dsonar.sources=app.js \
                        -Dsonar.host.url=http://localhost:9000 \
                        -Dsonar.javascript.lcov.reportPaths=./coverage/lcov.info
                    '''
                    }
                    waitForQualityGate abortPipeline: true
                }
            }  
        }
        stage('Building Docker Image') {
            steps {
                sh 'docker build -t sabrynabilx/solar-system-app:$GIT_COMMIT .'
            }
        }
        stage('Scanning Image') {
            steps {
                sh '''
                    trivy image sabrynabilx/solar-system-app:$GIT_COMMIT \
                        --severity LOW,MEDIUM,HIGH \
                        --exit-code 0 \
                        --format json -o trivy-scan-MIDIUM-results.json \
                        --quiet 

                    trivy image sabrynabilx/solar-system-app:$GIT_COMMIT \
                        --severity CRITICAL \
                        --exit-code 1 \
                        --format json -o trivy-scan-Critical-results.json \
                        --quiet 
                '''
            }
            post {
                always {
                    sh '''
                        trivy convert \
                            --format template --template "@/usr/local/share/trivy/templates/html.tpl" \
                            --output trivy-scan-MIDIUM-results.html trivy-scan-MIDIUM-results.json
                        trivy convert \
                            --format template --template "@/usr/local/share/trivy/templates/html.tpl" \
                            --output trivy-scan-Critical-results.html trivy-scan-Critical-results.json
                        trivy convert \
                            --format template --template "@/usr/local/share/trivy/templates/html.tpl" \
                            --output trivy-scan-MIDIUM-results.xml trivy-scan-MIDIUM-results.json
                        trivy convert \
                            --format template --template "@/usr/local/share/trivy/templates/html.tpl" \
                            --output trivy-scan-Critical-results.xml trivy-scan-Critical-results.json
                    '''
                }
            }
            
        }
        stage('Push Docker Image') {
            steps {
                withDockerRegistry(credentialsId: 'dockerhub-cred', url: "") {
                    sh 'docker push sabrynabilx/solar-system-app:$GIT_COMMIT'
                }
            }
        }
        stage('Deploy - AWS EC2') {
            when {
                branch 'feature/*'
            }
            steps {
                script {
                    sshagent(['SSH-KEY']) {
                        sh '''
                            ssh -o StrictHostKeyChecking=no ubuntu@98.89.24.162  "
                                if docker ps -a | grep -q solar-system-app; then
                                    echo "Container exists. Stopping and removing..."
                                    docker stop solar-system-app && docker rm solar-system-app
                                    echo "Old container removed."
                                fi
                                docker run --name solar-system-app \
                                -e MONGO_URI=$MONGO_URI \
                                -e MONGO_USERNAME=$MONGO_USERNAME \
                                -e MONGO_PASSWORD=$MONGO_PASSWORD \
                                -d -p 3030:3030 sabrynabilx/solar-system-app:$GIT_COMMIT
                                "
                                 

                        '''

                    }
                }
            }
        }
       stage('Integration Test') {
            when {
                branch 'feature/*'
            }
            steps {
                sh 'printenv | grep -i branch' 
                withAWS(credentials: 'AWS-CRED-EC2-S3-LAMBDA', region: 'us-east-1') {
                    sh '''
                        bash aws-ec2-script.sh
                    '''
                }
            }
        }
        stage('k8s Update image tag') {
            when {
                branch 'PR*'
            }
            steps {
                sh 'git clone -b main http://localhost:3000/sabry-org/argocd-solarsystem'
                dir('argocd-solarsystem/kubernetes') {
                    sh """
                        git checkout main
                        git checkout -b feature-$BUILD_ID
                        sed -i "s#sabrynabilx.*#sabrynabilx/solar-system-app:$GIT_COMMIT#g"  deployment.yml
                        cat deployment.yml


                        git config --global user.email "sabrynabil009@gmail.com"
                        git remote set-url origin http://$GITEA_TOKEN@localhost:3000/sabry-org/argocd-solarsystem.git
                        git add .
                        git commit -am "Update image Docker"
                        git push origin feature-$BUILD_ID
                        
                    """
                }
            }
        }
        stage('K8S Raise PR') {
            when {
                branch 'PR*'
            }
            steps {
                    sh """
                        echo $GITEA_TOKEN
                        curl -X 'POST' \
                        'http://localhost:3000/api/v1/repos/sabry-org/argocd-solarsystem/pulls' \
                        -H 'accept: application/json' \
                        -H "Authorization: token $GITEA_TOKEN" \
                        -H 'Content-Type: application/json' \
                        -d '{
                            "assignee": "sabry",
                            "assignees": [
                                "sabry"
                            ],
                            "base": "main",
                            "body": "Update Docker Image in deployment manifest",
                            "head": "feature-$BUILD_ID",
                            "title": "Docker Image Update - Build #$BUILD_ID"
                        }'
                    """
            }
        }
        stage('App Deployed ?') {
            when {
                branch 'PR*'
            }
            steps {
                timeout(time: 1, unit: 'DAYS') {
                    input message: 'IS the PR Merged and Argocd Synced' , ok: 'Yes PR is Merged and ArgoCD Application is Synced'
                    
                }
            }
        }
        stage('DAST - OWASP ZAP Scan') {
            when {
                branch 'PR*'
            }
            steps {
                catchError(buildResult: 'SUCCESS', message: 'i will handle it') {
                    sh '''
                        echo $(pwd)
                        chmod 777 $(pwd)
                        docker run --network kind \
                            -v $(pwd):/zap/wrk/:rw \
                            ghcr.io/zaproxy/zaproxy zap-api-scan.py \
                            --verbose \
                            -t http://172.19.0.2:30000/api-docs \
                            -f openapi \
                            -r zap_report.html \
                            -w zap_report.md \
                            -J zap_json_report.json \
                            -x zap_xml_report.xml \
                            -c zap_ignore_rules

                    '''
                }
            }
        }

        stage('Upload Reports to S3') {
            when {
                branch 'PR*'
            }
            steps {
                withAWS(credentials: 'AWS-CRED-EC2-S3-LAMBDA', region: 'us-east-1') {
                    sh """
                        ls -ltr
                        mkdir reports-$BUILD_ID
                        cp -rf coverage/ reports-$BUILD_ID/
                        cp dependency*.* test-results.* trivy*.* reports-$BUILD_ID/
                        ls -ltr reports-$BUILD_ID/
                    """
                    s3Upload(
                        bucket: 'solar-system-jenkins-sabry-reports',
                        path: "jenkins-$BUILD_ID/",
                        file: "reports-$BUILD_ID"
                    )
                    
                }

            }
        }
    }
    post {
        always {
            script {
                if(fileExists('argocd-solarsystem')) {
                    sh 'rm -rf argocd-solarsystem'
                }
            }
            junit allowEmptyResults: true, keepProperties: true, stdioRetention: 'ALL', testResults: 'test-results.xml' 
            junit allowEmptyResults: true, keepProperties: true, stdioRetention: 'ALL', testResults: 'dependency-check-junit.xml'
            junit allowEmptyResults: true, keepProperties: true, stdioRetention: 'ALL', testResults: 'trivy-scan-Critical-results.xml'
            junit allowEmptyResults: true, keepProperties: true, stdioRetention: 'ALL', testResults: 'trivy-scan-MIDIUM-results.xml'

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'dependency-check-jenkins.html', reportName: 'HTML Report', reportTitles: '', useWrapperFileDirectly: true])

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'trivy-scan-MIDIUM-results.html', reportName: 'Trivy image Medium Vul Report', reportTitles: '', useWrapperFileDirectly: true]) 

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'trivy-scan-Critical-results.html', reportName: 'Trivy Scan-Critical Vul Report', reportTitles: '', useWrapperFileDirectly: true])

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: 'coverage/lcov-report', reportFiles: 'index.html', reportName: 'Coverage Report', reportTitles: '', useWrapperFileDirectly: true]) 

            publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, icon: '', keepAll: true, reportDir: './', reportFiles: 'zap_report.html', reportName: 'DAST - OWASP ZAP', reportTitles: '', useWrapperFileDirectly: true])

        }

    }
} 