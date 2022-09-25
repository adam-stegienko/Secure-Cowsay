pipeline {
    agent any
    environment {
        GITLAB = credentials('a31843c7-9aa6-4723-95ff-87a1feb934a1')
    }
    stages {
        stage('Setup parameters') {
            steps {
                script {
                    properties([
                        disableConcurrentBuilds(), 
                        gitLabConnection(gitLabConnection: 'GitLab API Connection', jobCredentialId: ''), 
                        [$class: 'GitlabLogoProperty', repositoryName: 'adam/cowsay'], 
                        parameters([
                            validatingString(
                                description: 'Put a 2-digit value meaning the branch you would like to build your version on, as in the following examples: "1.0", "1.1", "1.2", etc.', 
                                failedValidationMessage: 'Parameter format is not valid. Build aborted. Try again with valid parameter format.', 
                                name: 'Version', 
                                regex: '^[0-9]{1,}\\.[0-9]{1,}$'
                            )
                        ]), 
                    ])
                }
            }
        }
        stage('clean') {
            steps {
                deleteDir()
            }
        }  
        stage('Non-release branch build') {
            when {
                allOf {
                    expression { env.GIT_BRANCH != "*/release*" }
                    expression { params.Version.isEmpty() }
                }
            }
            steps {
                script {
                    sh 'GIT_DISCOVERY_ACROSS_FILESYSTEM=1'
                    sh 'git pull --rebase'
                    sh 'docker build -t adam-cowsay:latest .'
                }
                echo "Latest image built for non-release branch."
            }
        }
        stage('Release branch existence validation') {
            when { not { expression { params.Version.isEmpty() } } }
            steps {
                script {
                    GIT_DISCOVERY_ACROSS_FILESYSTEM = 1
                    BRANCH = "release/$params.Version"
                    IMAGE_VERSION = params.Version
                    echo IMAGE_VERSION
                    BRANCH_EXISTING = sh(
                        script: '(git remote set-url origin http://'%GITLAB%'@ec2-3-67-195-219.eu-central-1.compute.amazonaws.com/adam/cowsay.git && git ls-remote -q | grep -w '%BRANCH%') || BRANCH_EXISTING=False',
                        returnStdout: true,
                    )
                    if (BRANCH_EXISTING) {
                        echo "The $BRANCH branch is already existing."
                    } else {
                        echo "The $BRANCH branch is not exsiting yet and needs to be created."
                        sh """#!/bin/bash -xe
                        git checkout main && git pull --rebase
                        echo $BRANCH
                        git branch $BRANCH
                        git checkout $BRANCH
                        touch version.txt
                        printf "$IMAGE_VERSION\nNOT FOR RELEASE\n" > version.txt
                        git add .
                        git commit -m "[ci-skip] The $BRANCH branch created"
                        echo $IMAGE_VERSION
                        git tag $IMAGE_VERSION
                        git push -u origin $BRANCH
                        """
                        echo "The $BRANCH branch has been created."
                    }
                }
            }
        }
        stage('Update version') {
            when { not { expression { params.Version.isEmpty() } } }
            steps {
                script {
                    TEMP_VERSION = sh(
                        script: "head -n1 ./version.txt",
                        returnStdout: true,
                    )
                    echo TEMP_VERSION
                    HOW_MANY_CHARS = sh(
                        script: "/bin/bash -c (echo \"$TEMP_VERSION\" | awk '{ print length; }')",
                        returnStdout: true,
                    )
                    echo HOW_MANY_CHARS
                    FIRST_DIGIT = sh(
                        script: "/bin/bash -c (echo \"$TEMP_VERSION\" | cut -c1)",
                        returnStdout: true,
                    )
                    echo FIRST_DIGIT
                    SECOND_DIGIT = sh(
                        script: "/bin/bash -c (echo \"$TEMP_VERSION\" | cut -c3)",
                        returnStdout: true,
                    )
                    echo SECOND_DIGIT
                    if (HOW_MANY_CHARS == 5) {
                        THIRD_DIGIT = sh(
                        script: "/bin/bash -c (echo \"$TEMP_VERSION\" | cut -c3)",
                        returnStdout: true,
                        )
                        echo THIRD_DIGIT
                        LATEST_PATCH = ($THIRD_DIGIT + 1)
                    } else {
                        LATEST_PATCH = 0
                    }
                    echo LATEST_PATCH
                    NEW_VERSION = FIRST_DIGIT + "." + SECOND_DIGIT + "." + LATEST_PATCH
                    echo NEW_VERSION
                }
            }
        }
        stage('Build') {
            when { not { expression { params.Version.isEmpty() } } }
            steps {
                script {
                    sh"""#!/bin/bash -xe
                    git fetch
                    git checkout $BRANCH && git pull --ff-only
                    docker build -t adam-cowsay:$NEW_VERSION .
                    """
                }
            }
        }
        stage('Push') {
            when { not { expression { params.Version.isEmpty() } } }
            steps {
                script {
                    sh"""#!/bin/bash -xe
                    git fetch
                    git checkout $BRANCH && git pull --ff-only
                    printf "$NEW_VERSION\nFOR RELEASE" > version.txt
                    git commit -am "[ci-skip] New $NEW_VERSION version."
                    git tag "$NEW_VERSION"
                    aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 644435390668.dkr.ecr.eu-central-1.amazonaws.com
                    docker tag adam-cowsay:$NEW_VERSION 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:$NEW_VERSION
                    docker push 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:$NEW_VERSION
                    docker tag adam-cowsay:$NEW_VERSION 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:latest
                    docker push 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:latest
                    echo "Cowsay container has been built successfully."
                    """
                }
            }
        }
        stage('Pull, Run, and Test') {
            when { not { expression { params.Version.isEmpty() } } }
            steps {
                script {
                    sh'''
                    ssh -i "adam-lab.pem" ubuntu@ec2-3-123-22-170.eu-central-1.compute.amazonaws.com
                    aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 644435390668.dkr.ecr.eu-central-1.amazonaws.com
                    docker pull 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:latest
                    docker rm -f happy_cowsay
                    docker run --name=happy_cowsay -d -p 80:8080 644435390668.dkr.ecr.eu-central-1.amazonaws.com/adam-cowsay:latest
                    sleep 5
                    curl http://ec2-3-123-22-170.eu-central-1.compute.amazonaws.com
                    '''
                }
            }
        }
    }
}  
