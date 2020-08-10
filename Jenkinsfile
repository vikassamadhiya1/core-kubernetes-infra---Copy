pipeline {

	agent{
		dockerfile  {
      		args '-v $WORKSPACE:/jkns-ws -u="root"'
		}
	}

	options {
	  disableConcurrentBuilds()
	}

	parameters {
		booleanParam(
			name: "FORCE_DEPLOY",
			defaultValue: false,
			description: "Force a full build, test, and deployment"
		)
	}

	triggers { cron( '0 7 * * 1' ) } // Weekly trigger of pipeline on Monday at 7 AM UTC. 

	environment{
		GITHUB_API_CRED = credentials('pdxc-jenkins-github')
		GITHUB_API_KEY = "${GITHUB_API_CRED_PSW}"
		GIT_HOST = "github.dxc.com"
		AWS_DEFAULT_REGION = 'us-east-1'
		DEFAULT_PDXC_ENV = 'SB2'
		ARTIFACTORY_PACKAGE_PATH = 'core-kubernetes-infra'
		ARTIFACTORY_TEST_PACKAGE_PATH = 'tests-core-kubernetes-infra'
		deployEnv = ""
		release = ""
		deploySandbox2 = ""
	}
  stages{ // The content in this Jenkinsfile has the targeted keywords we will use in automation to track stages for dashboarding.
          // Please insure to at least leave these keywords inside the "stage" in your description of the activity to help keep clean
          // our automation processes

		stage('Establish Required Work'){
			steps{
				withAwsCredentials (roleArnCredId: 'CTK_SB2_ARN', externalIdCredId: 'CTK_SB2_EXT_ID') {
					script {
						if (env.BRANCH_NAME.startsWith('PR-')==true){
							commitType = "pullrequest"
							commitId = env.CHANGE_ID
						}
						else{
							commitType = "commit"
							commitId =  env.GIT_COMMIT
						}

						// Create release Packages
						release = sh(returnStdout: true, script: "node utilities/pipeline/common/trackValid.js release ${commitType} ${commitId}").trim()
						testRelease = sh(returnStdout: true, script: "node utilities/pipeline/common/trackValid.js testRelease ${commitType} ${commitId}").trim()

						// Deploy on Dev
						deploy = sh(returnStdout: true, script: "node utilities/pipeline/common/trackValid.js deploy ${commitType} ${commitId}").trim()
						testDeploy = sh(returnStdout: true, script: "node utilities/pipeline/common/trackValid.js testDeploy ${commitType} ${commitId}").trim()

						//cat deploy.out
						// Docs only
						doDocs = sh(returnStdout: true, script: "node utilities/pipeline/common/docsValid.js ${commitType} ${commitId}").trim()
						if (doDocs.startsWith('TRUE')==true){
							echo "Only Docs file changed so deployment will not happen = ${doDocs}"
						}
						if (release.startsWith('FAIL')==true){
							echo "${release}"
							exit 1
						}
						if (deploy.startsWith('FAIL')==true){
							echo "${deploy}"
							exit 1
						}
						if (testRelease.startsWith('FAIL')==true){
							echo "${testRelease}"
							exit 1
						}
						if (testDeploy.startsWith('FAIL')==true){
							echo "${testDeploy}"
							exit 1
						}

						deploySandbox2="FALSE"
						if ((release.startsWith('FALSE')==true) && (deploy.startsWith('FALSE')==true)
						&& (testRelease.startsWith('FALSE')==true) && (testDeploy.startsWith('FALSE')==true)
						&& (doDocs.startsWith('FALSE'))){
							deploySandbox2="TRUE"
						}

						echo "release=${release}"
						echo "deploy=${deploy}"
						echo "testrelease=${testRelease}"
						echo "testdeploy=${testDeploy}"
					  	echo "deploySandbox2=${deploySandbox2}"
						echo "doDocs=${doDocs}"
					}
				}
			}
		}

		stage("Linting") {
			parallel {
				stage ("Git Secrets") {
					steps {
						script {
							// The Jenkins workspace where source will be scanned
							env.JKNS_WS = '/jkns-ws'
							env.LOGFILE = "${env.JKNS_WS}/git-secrets.${env.BUILD_NUMBER}.txt"
							env.TERM = 'xterm'
							sh "cd ${env.JKNS_WS}"
							// make sure git secrets is installed for the repo
							// sh "git secrets --install --force"
							sh(script: 'git config --unset-all secrets.allowed', returnStatus: true)
							// make sure aws provider is added to the patterns
							status = sh(script: 'git secrets --register-aws', returnStatus: true)
							// Install template exceptions
							sh "git secrets --add --allowed 'dxc-aws-account:*+'"
							sh "echo '### LIST of prohibited patterns: git secrets ###' > ${env.LOGFILE}"
							sh "git secrets --list >> ${env.LOGFILE}"
							sh "echo '\n\n### ---------SCAN results ------------------ ###' >> ${env.LOGFILE}"
							try
							{// perform the actual scan of the git repo"
								sh "git secrets --scan >> ${env.LOGFILE} 2>&1"
								echo "None"
							}
							catch (err) { // set build status to unstable, this will not stop the pipeline
								currentBuild.result = 'UNSTABLE'
								def repo_url = sh(script: "git remote get-url origin", returnStdout: true).trim()
								// Notify someone about the security audit failure
								// emailext(
								// 	attachmentsPattern: "**/git-secrets.${env.BUILD_NUMBER}.txt",
								// 	subject: "Action Required: secret detected in GitHub by PDXC job ${env.BUILD_NUMBER}",
								// 	body: "Hello,\n\n at least one KEY prohibited by the PDXC regular expression patterns has been found in your repository ($repo_url).\n Make sure to take the appropriate actions to remediate this issue.\n\n (note that the key will remain in the git history, removing it from the file is not enough , additional action maybe require [key rotation,...]).\n\n The result of the scan is provided as an attachment of this email.",
								// 	to: "${env.CONTACT_EMAIL}",
								// 	from: "${env.CONTACT_EMAIL}"
								// )
								// Cleanup log as it actually contains the keys
								sh "cat ${env.LOGFILE}"
								sh "rm -f ${env.LOGFILE}"
								// Force an exit
								sh "exit 1"
							}
						}
					}
				}

				// stage('Veracode Scan'){
				// 	stages{
				// 		stage('Start Veracode Scan') {
				// 			when { 
				// 				//branch "master"
				// 				branch 'PR-*'

				// 				// Veracode scan may take a few minutes to finish, so you can set to only run it at a specific time every day or every week by the TimerTrigger.
				// 				//At the top of this Jenkinsfile, we defined a weekly trigger of pipeline on Monday at 7 AM UTC. triggers { cron( '0 7 * * 1' ) }, only stage
				// 				// with triggeredBy 'TimerTrigger' will run then.
				// 				//triggeredBy 'TimerTrigger'
				// 				expression {doDocs != 'TRUE' && release != 'TRUE' && deploy != 'TRUE'&& testRelease != 'TRUE'&& testDeploy != 'TRUE'}
				// 			}
				// 			steps {
				// 				withCredentials ([usernamePassword(credentialsId:'core_user',usernameVariable: 'core_user', passwordVariable: 'core_pass')]){
				// 					sh 'bash veracode/install-veracode-wrapper.sh'
				// 					// sh "INSERT_YOUR_PACKAGE_HERE" #example: sh "zip pdxc_scan.zip target/pdxc_app.jar"  
				// 					sh 'zip -r core-kubernetes-infra.zip infrastructure-template/* -x */node_modules/*'
				// 					script {
				// 						try {
				// 							sh '''
				// 								java -jar ./VeracodeJavaAPI.jar -action uploadandscan -vid $core_user -vkey $core_pass -appname platformdxc/core-kubernetes-infra -createprofile true -criticality high -version platformdxc/core-kubernetes-infra-$BUILD_NUMBER -filepath core-kubernetes-infra.zip > scan.log
				// 								# uncomment below line if you get an exception.
				// 								# sleep 5m
				// 								cat scan.log 
				// 							'''
				// 						} catch (Exception e) {
				// 							echo "Error during scan upload "
				// 							sh 'cat scan.log'
				// 							currentBuild.result = 'UNSTABLE'
				// 						}
				// 					}
				// 				}			
				// 			}
				// 		}

				// 		stage('Check Veracode Completion') {
				// 			when { 
				// 				//branch "master"
								
				// 				 branch 'PR-*'

				// 				// Veracode scan may take a few minutes to finish, so you can set to only run it at a specific time every day or every week by the TimerTrigger.
				// 				//At the top of this Jenkinsfile, we defined a weekly trigger of pipeline on Monday at 7 AM UTC. triggers { cron( '0 7 * * 1' ) }, only stage
				// 				// with triggeredBy 'TimerTrigger' will run then.
				// 				//triggeredBy 'TimerTrigger'
				// 				expression {doDocs != 'TRUE' && release != 'TRUE' && deploy != 'TRUE'&& testRelease != 'TRUE'&& testDeploy != 'TRUE'}
				// 			}
				// 			steps {
				// 				script {  
				// 					withCredentials ([
				// 						usernamePassword(credentialsId:'core_API_user',usernameVariable: 'core_API_user', passwordVariable: 'core_API_pass'),
				// 						usernamePassword(credentialsId:'core_user',usernameVariable: 'core_user', passwordVariable: 'core_pass')
				// 						]){
				// 						sh 'cat scan.log'
				// 						retry(20){
				// 							def returnResult = sh(returnStatus: true, script: 'bash veracode/check-veracode.sh')
				// 							if(returnResult == 0){
				// 								archiveArtifacts artifacts: 'veracode_scan_summary.pdf', fingerprint: true
				// 								emailext(subject: "platformdxc/core-kubernetes-infra Veracode scan BUILD_ID: '${env.BUILD_ID}' ", body: "Veracode scan BUILD_ID: '<${env.BUILD_ID}>' completed. You can check scan report at https://analysiscenter.veracode.com/api/4.0/summaryreportpdf.do?build_id=${env.BUILD_ID} ", from: 'miskra3@dxc.com',to: 'vivek.pati@dxc.com, miskra3@dxc.com')
				// 							} else if(returnResult == 1){
				// 								archiveArtifacts artifacts: 'veracode_scan_summary.pdf', fingerprint: true
				// 								emailext(subject: "platformdxc/core-kubernetes-infra Veracode scan BUILD_ID: '${env.BUILD_ID}' ", body: "Veracode scan BUILD_ID: '<${env.BUILD_ID}>' completed. You can check scan report at https://analysiscenter.veracode.com/api/4.0/summaryreportpdf.do?build_id=${env.BUILD_ID} ", from: 'miskra3@dxc.com',to: 'vivek.pati@dxc.com, miskra3@dxc.com')
				// 							}  else if(returnResult == 3){
				// 								//archiveArtifacts artifacts: 'veracode_scan_summary.pdf', fingerprint: true
				// 								emailext(subject: "platformdxc/core-kubernetes-infra Veracode scan BUILD_ID: '${env.BUILD_ID}' ", body: "Veracode scan BUILD_ID: '<${env.BUILD_ID}>' failed. check return code is 3", from: 'miskra3@dxc.com',to: 'vivek.pati@dxc.com, miskra3@dxc.com')
				// 							} else {
				// 								error "return code is $returnResult, retrying ...."
				// 							}
				// 						}
				// 					}

				// 				}
				// 			}

				// 			post {
				// 					always {

				// 						script {

				// 						echo "Build badges..."
				// 						//Build badges
				// 						def durationBuildBadge = addEmbeddableBadgeConfiguration(id: "pdxcduration", subject: "last duration")
				// 						durationBuildBadge.setStatus(currentBuild.durationString.replace(' and counting',''))
				// 						durationBuildBadge.setColor('lightgrey')
				// 						def dateBuildBadge = addEmbeddableBadgeConfiguration(id: "pdxcdate", subject: "last run")
				// 						def timejobcompleted = sh (script: 'date -u "+%F %H:%M"', returnStdout: true).trim()
				// 						dateBuildBadge.setStatus(timejobcompleted + " UTC")
				// 						dateBuildBadge.setColor('lightgrey')

				// 					}

				// 				}
				// 			}
				//}
			}
		}

		stage('Build') {
			steps {
				echo "Build Processes – Any assembly activities that chains source together, if doesnt apply please leave a 'not applicable' echo"
			}
		}

		stage('Sandbox2 Deploy') {
				when {
					branch 'master'
					//branch 'PR-*'

			expression {deploySandbox2 == "TRUE"}
			//expression { release != "TRUE" && deploySandbox2 == "TRUE"}
				}
				options { timeout(time: 90, unit: 'MINUTES') }
				environment {PDXC_ENV="SB2" }
				steps {
	
				echo "Run Terraform plan to see if anything will get destroyed."
				withAwsCredentials (roleArnCredId: 'CTK_SB2_ARN', externalIdCredId: 'CTK_SB2_EXT_ID') {
						sh '''
							# add bash shell command here
							echo "BEFORE AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}"
							echo "BEFORE AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}"
							export AWS_DEFAULT_REGION=us-east-1
							echo "PDXC_ENV=$PDXC_ENV"
							chmod +x ./deploy.sh
							bash ./deploy.sh --server-plan
							rcDeploy=$?
							if [[ $rcDeploy != 0 ]]; then exit $rcDeploy; fi
						sh '''
				}
				
				echo 'Review changes and approve'
				input message: "Apply infrastructure changes to SANDBOX2?", ok: "Apply"
				echo "Deployment of the Package to SB2"
				withAwsCredentials (roleArnCredId: 'CTK_SB2_ARN', externalIdCredId: 'CTK_SB2_EXT_ID') {
						sh '''
							# add bash shell command here
							echo "BEFORE AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}"
							echo "BEFORE AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}"
							export AWS_DEFAULT_REGION=us-east-1
							echo "PDXC_ENV=$PDXC_ENV"
							export PDXC_ENV="SB2"
							chmod +x ./deploy.sh
							./deploy.sh --server-apply
							rcDeploy=$?
							if [[ $rcDeploy != 0 ]]; then exit $rcDeploy; fi
						sh '''
				}
				// echo 'Deploy Serverless...'
				// withAwsCredentials (roleArnCredId: 'CTK_SB2_ARN', externalIdCredId: 'CTK_SB2_EXT_ID') {
				// 		sh '''
				// 			# add bash shell command here
				// 			echo "BEFORE AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}"
				// 			echo "BEFORE AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}"
				// 			export AWS_DEFAULT_REGION=us-east-1
				// 			export ALERT_ENDPOINT="vivek.pati@dxc.com"
				// 			echo "PDXC_ENV=$PDXC_ENV"
				// 			chmod +x ./deploy.sh
				// 			./deploy.sh --serverless
				// 			rcDeploy=$?
				// 			if [[ $rcDeploy != 0 ]]; then exit $rcDeploy; fi
				// 		sh '''
				// }

				
			}
			post {
				always {
					sh "rm -rf ${WORKSPACE}/server/.terraform"
					sh "rm -rf ${WORKSPACE}/server/tfplan"
				}
			}
		}

		stage('Sandbox2 Test Package'){
			when {
				// need to prepare package and upload to artifactory, only when merge is done at the master branch
				 //branch "PR*"
				branch "master"
				expression {deploySandbox2 == "TRUE"}

			}
			environment {PDXC_ENV="SB2" }


			steps{

				echo 'Server Based Sandbox2 Deployment Testing...'
				withAwsCredentials (roleArnCredId: 'CTK_SB2_ARN', externalIdCredId: 'CTK_SB2_EXT_ID') {
					withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId:'pdxc-jenkins', usernameVariable: 'ARTIFACTORY_USER', passwordVariable: 'ARTIFACTORY_PASSWORD']]) {
						sh '''
						if [ -e ./testing ] && [ -f ./testing/deploy.sh ]; then
							cd testing
							chmod 777 ./deploy.sh
							./deploy.sh --server
						fi
						'''
					}
				}

				echo 'Serverless Based Sandbox2 Lambda Function Testing...'
				withAwsCredentials (roleArnCredId: 'CTK_SB2_ARN', externalIdCredId: 'CTK_SB2_EXT_ID') {
					
					sh '''
						# add bash shell command here
						export AWS_DEFAULT_REGION=us-east-1
						echo "PDXC_ENV=$PDXC_ENV"
						export PDXC_ENV="SB2"
						if [ -e ./serverless ] && [ -f ./deploy-serverless.sh ]; then
							cd serverless/ && npm install 

							for sLambda in `serverless deploy list functions | sed 1,2d | cut -d':' -f2 | sed 's/ //g'`
							do
								echo "Start to invoke funciton: $sLambda";
								serverless invoke -f $sLambda --region $AWS_DEFAULT_REGION
								# serverless invoke -f $sLambda -t DryRun --region $AWS_DEFAULT_REGION
								if [[ $? != 0 ]]; then echo "$sLambda doesn't exist"; fi
							done
						fi
						rcTest=$?
						if [[ $rcTest != 0 ]]; then exit $rcTest; fi
					sh '''
					
				}
			}	
		}

		stage('Deploy application to EKS Cluster'){
			when {
				// need to prepare package and upload to artifactory, only when merge is done at the master branch
				//branch "PR*"
				branch "master"				
			 }
			environment {PDXC_ENV="SB2" }
			steps{
				echo "Deployment of the Package to SB2"
				withAwsCredentials (roleArnCredId: 'CTK_SB2_ARN', externalIdCredId: 'CTK_SB2_EXT_ID') {
					sh '''
						# add bash shell command here                                                     													
						chmod 777 ./utilities/deploy-application.sh
						./utilities/deploy-application.sh
					sh '''					
				}
			}
		}

		stage('Master Publish Release Package'){
			when {
				// need to prepare package and upload to artifactory, only when merge is done at the master branch
				//branch "PR*"
				branch "master"
				expression { release == 'TRUE' }
			 }
			steps{
				withAwsCredentials (roleArnCredId: 'CTK_SB2_ARN', externalIdCredId: 'CTK_SB2_EXT_ID') {
					withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId:'pdxc-jenkins', usernameVariable: 'ARTIFACTORY_USER', passwordVariable: 'ARTIFACTORY_PASSWORD']]) {
						sh '''
							chmod 777 ./utilities/release-package.sh
							./utilities/release-package.sh "master"
						'''
					}
				}
			}
		}

    	stage('Deploy DEV') {
      		when {
				branch 'master'
				//branch 'PR-*'
				expression { deploy == 'TRUE' }
      		}
      		steps {
        		echo "Deployment of the Package to dev"

        		withAwsCredentials (roleArnCredId: 'ARN_DEV', externalIdCredId: 'EXTID_DEV') {
          			withCredentials([[$class: "UsernamePasswordMultiBinding", credentialsId: "pdxc-jenkins", usernameVariable: "ARTIFACTORY_USR", passwordVariable: "ARTIFACTORY_PASSWORD"]]) {
						sh '''
							chmod 777 ./utilities/deploy-dev.sh
							./utilities/deploy-dev.sh
						'''
					}
				}	
      		}
    	}

		stage('Master Publish Test Release Package'){
			when {
				// need to prepare package and upload to artifactory, only when merge is done at the master branch
				//branch "PR*"
				branch "master"
				expression { testRelease == "TRUE" }
			 }
			steps{


				withAwsCredentials (roleArnCredId: 'CTK_SB2_ARN', externalIdCredId: 'CTK_SB2_EXT_ID') {
					withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId:'pdxc-jenkins', usernameVariable: 'ARTIFACTORY_USER', passwordVariable: 'ARTIFACTORY_PASSWORD']]) {
						sh '''
							if [ -e ./server ]; then
								chmod 777 ./utilities/release-test-package.sh
								./utilities/release-test-package.sh "master" "server"
							fi
						'''
					}
				}

				withAwsCredentials (roleArnCredId: 'CTK_SB2_ARN', externalIdCredId: 'CTK_SB2_EXT_ID') {
					withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId:'pdxc-jenkins', usernameVariable: 'ARTIFACTORY_USER', passwordVariable: 'ARTIFACTORY_PASSWORD']]) {
						sh '''
							if [ -e ./serverless ]; then
								echo "Publish Serverless Test Release Package"
								chmod 777 ./utilities/release-test-package.sh
								./utilities/release-test-package.sh "master" "serverless"
							fi
						'''
					}
				}				


			}
		}

		stage('Deploy Tests to DEV') {
			when {
						branch 'master'
						//branch 'PR-*'
						expression { testDeploy == 'TRUE' }
			}
			steps {
				echo "Deployment of the Test Package to dev"

				withAwsCredentials (roleArnCredId: 'ARN_DEV', externalIdCredId: 'EXTID_DEV') {
				withCredentials([[$class: "UsernamePasswordMultiBinding", credentialsId: "pdxc-jenkins", usernameVariable: "ARTIFACTORY_USR", passwordVariable: "ARTIFACTORY_PASSWORD"]]
				) {
								sh '''
									chmod 777 ./utilities/deploy-test-dev.sh
									./utilities/deploy-test-dev.sh
								'''
				}
				}
			}
//			post {
//						always {
//
//							junit 'testing/test-reports/*.xml'
//
//						}
//				}
		}

	
    stage('Verify') {
      steps {
        echo "Will become our Policy/Compliance-as-code"
       }
    }
    stage('Notify') { //Notify only on failure, may send alert to multiple targets using parallel condition – email, slack, teams, etc.
	    steps {
        echo "do something"
      } // Please place your actions inside a step so that we can have a controlled reference to trace your flow
	}
	
  }
}
def readJsonFile(fileName, param) {
	def filePath = "./" + fileName
	def myJson = readJSON file: +filePath

	if ( myJson.returnStatus == 'SUCCESS' ) {
		return myJson[param]
	}
	else {
		return "FALSE"
	}
}
def withAwsCredentials(Map args, Closure body) {
    withCredentials ([
        string(credentialsId: args.roleArnCredId, variable: args.roleArnCredId),
        string(credentialsId: args.externalIdCredId, variable: args.externalIdCredId)])
    {
        withAWS (role: env[args.roleArnCredId], externalId: env[args.externalIdCredId]) {
            wrap ([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs: [
                [password: env.AWS_ACCESS_KEY_ID, var: 'AWS_ACCESS_KEY_ID'],
                [password: env.AWS_SECRET_ACCESS_KEY, var: 'AWS_SECRET_ACCESS_KEY']]])
            {
                body()
            }
        }
    }
}
