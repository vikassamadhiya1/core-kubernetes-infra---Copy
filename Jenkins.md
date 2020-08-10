# Jenkins for Platform DXC

Platform DXC Repositories are processed by a shared Jenkins implementation for the Continuous Integration and Continuous Deployment Pipelines.  The Jenkins instances that scan the Platform-DXC Organization is below:

[Jenkins Instance](http://jenkins.platformdxc.com/)

To manage multiple Jenkinsfile instances supporting multiple pipelines in the same repo simply rename the template to < substitution >.Jenkinsfile and replicate to another < substitution >.Jenkinsfile

Consider following the general Jenkinsfile Best Practices
[Jenkins Pipeline Best Practices](https://github.com/jenkinsci/pipeline-examples/blob/master/docs/BEST_PRACTICES.md)

[Jenkinsfile Syntax](https://jenkins.io/doc/book/pipeline/syntax/) is available.

## Jenkinsfile

Jenkinsfiles, using a domain specific language based on the Groovy programming language, are persistent files that model delivery pipelines “as code”, containing the complete set of encoded steps (steps, nodes, and stages) necessary to define the entire application life-cycle. Pipeline automates software delivery; essentially becoming the intersecting point between development and operations.

!["Server Diagram"](./docs/images/jenkinspipeline.drawio.png)

Stages:

- [Establish Required Work](#establish-required-work)
- [Linting Git Secrets](#linting-git-secrets)
- [Start Veracode Scan](#start-veracode-scan)
- [Check Veracode Completion](#check-veracode-completion)
- [Build](#build)
- [Sandbox2 Unit Test Serverless](#sandbox2-unit-test-serverless)
- [Sandbox2 Deploy](#sandbox2-deploy)
- [Sandbox2 Test Package](#sandbox2-test-package)
- [Master Publish Release Package](#master-publish-release-package)
- [Deploy DEV](#deploy-dev)
- [Master Publish Test Release Package](#master-publish-test-release-package)
- [Deploy Tests to DEV](#deploy-tests-to-dev)
- [Verify](#verify)
- [Notify](#notify)

### Establish Required Work

The 'Establish Required Work' stage determines if this is a GitHub Pull Request (PR) or a Commit and sets true/false values that determine the next stage that will be executed. This stage is executed every time the Jenkinsfile is executed.

### Linting Git Secrets

The 'Linting Git Secrets' stage detects passwords and other sensitive information (such as AWS Secrets). If secrets are found then the pipeline is exited. This stage is executed every time the Jenkinsfile is executed. If you have committed sensitive data into your repository you will need to remove that data from the repository files including the commit history, see https://help.github.com/en/articles/removing-sensitive-data-from-a-repository. 

### Start Veracode Scan

The stage "Start Veracode Scan" will start the Veracode scan. To make "Start Veracode Scan" work for your project, you need to contact with the SAST team to onboard individual account and one non-human account (API user configured in the pipeline stage). This stage is triggered weekly on Monday at 7 AM UTC by the timer trigger. For details on how to integrate this stage into your pipeline,
refer to the [guide](https://github.dxc.com/Platform-DXC/SAST-demo/blob/master/Guides/SAST%20user%20guide%20v.1.pdf).

### Check Veracode Completion

The stage "Check Veracode Completion" will check the result of Veracode scan. To make "Check Veracode Completion" work for your project, you need to contact with the SAST team to onboard individual account and one non-human account (API user configured in the pipeline stage). When the Veracode scan is completed and scan report is available, its summary version will be saved to Jenkins artifacts. This stage is triggered weekly on Monday at 7 AM UTC by the timer trigger. For details on how to integrate this stage into your pipeline,
refer to the [guide](https://github.dxc.com/Platform-DXC/SAST-demo/blob/master/Guides/SAST%20user%20guide%20v.1.pdf).

### Build

The 'Build' stage contains assembly activities that chains source together. At this time there is no content in this stage, but it can be added if necessary for your project. This stage is executed every time the Jenkinsfile is executed.

### Sandbox2 Unit Test Serverless

Right now, The 'Sandbox2 Unit Test Serverless' stage using the Mocha to do unit test for the nodejs based lambda function for the Serverless Template.

### Sandbox2 Deploy

For the server based application setup by following the [UserGuideServer.md](./docs/UserGuideServer.md), the "Sandbox2 Deploy" stage executes the terraform plan to verify nothing will be destroyed, ask for input for the changes to be moved to sandbox2 and once you click "Apply" in Jenkins then the infrastructure will be deployed to sandbox2. If the changes are only docs file(s) then no deployment to sandbox2. Since the user needs to click "Apply" or "Abort" there is a 90 minute time limit for this script to execute.

For the serverless based application setup by following the [UserGuideServerless.md](./docs/UserGuideServerless.md), the "Sandbox2 Deploy" stage will deploy the serverless lamdba function sample application into sandbox2. If the changes are only docs file(s) then no deployment to sandbox2.

### Sandbox2 Test Package

For the server based application setup by following the [UserGuideServer.md](./docs/UserGuideServer.md), the "Sandbox2 Test Package" stage uses the Newman command-line runner to run and test the Postman Collection. This stage will verify if the EC2 instances that were created in stage "Sandbox2 Deploy" were created correctly by the terraform script. See User Guide - Server for [Automated Testing](./docs/UserGuideServer.md#automated-testing) directions.

For the serverless based application setup by following the [UserGuideServerless.md](./docs/UserGuideServerless.md), the "Sandbox2 Test Package" stage uses "serverlee invoke" command to call the lambda function created. This stage will verify if the lamdba function created in stage "Sandbox2 Deploy" is accesssable and created correctly by the serverless famework.

### Master Publish Release Package

The 'Master Publish Release Package' stage prepares the package and uploads it to JFrog Artifactory. This stage is executed when a github merge is done on the master branch and the release file (./track/release/) is added/updated (see steps below).

Steps to publish a release package:
1. Create a new branch in your repository (if necessary). 
1. Edit the [./CHANGELOG.md](./CHANGELOG.md) file, there are directions in the file for adding a release. The version number in ./CHANGELOG.md must match the version in the json file in the step below. (Note: The version number should be different than any exiting release version or test release version in the github Release Tab or the package will not be displayed in the github Release Tab.)
1. Create directory ./track/release.
1. Add a release file in ./track/release or copy a release file from the core-template repository, for an example see [release.json file](./track/release/release.json).

Example:

```json
{
    "release_tag": "1.0.0",
    "tag_name": "1.0.0",
    "target_commitish": "master",
    "name": "Core Template",
    "description": "Core Template",
    "body": "Release of Core Template for Serverless Infrastructure.",
    "draft": false,
    "prerelease": true,
    "release_file": "core-template.zip",
    "release_version": "1.0.0"
  }
  ```
Follow the additional steps below:

* replace 'core-template' to your repository name
* replace "Core Template" to the description for your project
* release_version of your json file must match the version in the CHANGELOG.md in the step above.
* set "prerelease = true" to set package to unstable or "prerelease = false" to set package to stable; the package should not be set to stable (ie. prerelease = false) until the release package has been deployed, once the package is deployed you have verified the release package so it can be set to stable to be moved to the upper environments (ie. DEV2, Staging, Prod)
    
5. Once you complete the Pull Request and Merge to the master branch the release will be packaged/published.
6. Look in the JFrog Artifactory for your package - https://artifactory.csc.com/artifactory/webapp/#/home -  click "artifact" then look in the ./utilities/release-package.sh and Jenkinsfile (variable ARTIFACTORY_PACKAGE_PATH) file for your artifactory tree structure.

Note: To mark the package as 'stable', you edit the JSON file in ./track/Release and set "prerelease = false", then create a Pull Request (PR) and Merge to the master branch. The package should not be set to 'stable' until the release package has been deployed, once the package is deployed you have verified the release package so it can be set to stable to be moved to the upper environments (ie. DEV2, Staging, Prod).  For more details on the release pipeline, see https://github.dxc.com/pages/platform-dxc/release-pipeline/.

### Deploy DEV

The 'Deploy DEV' stage takes the package from JFrog Artifactory and deploys it to the dev environment. This stage is executed when a github merge is done on the master branch and the json deploy file (./track/deploy/) is updated (see steps below).

Steps to deploy to dev environment:
1. Create a new branch in your repository (if necessary). 
1. Create directory ./track/deploy (if it does not exist).
1. Create/Update the Deploy.json file in ./track/deploy, for an example see [deploy.json](./track/deploy/deploy.json). 

    Example:

    ```json
    {
        "env": "DEV",
        "version": "1.1.0",
        "attempts": 1
    }
    ```

    Field definitions:

    | Field | Contents |
    | --- | --- |
    | env | The deploy environment, eg: DEV or Sandbox2 |
    | version | The package version to download from JFrog Artifactory (see the previous section for directions on finding the release in the JFrog Artifactory) |
    | attempts | An integer number in case deploy need to be executed more than once |

1. Once you complete the Pull Request and Merge to the master branch the deploy to the Dev environment will be completed.
1. To verify - log into the AWS Console using [Federation SSO](https://fedssoawuse2.clmgmt.entsvcs.com/adfs/ls/IdpInitiatedSignOn.aspx) and select the platformdxc-dev environment and verify that the deploy to dev was successful (ie. verify EC2 instances, RDS, Lambda Functions, CloudWatch alarms).

### Master Publish Test Release Package

The 'Master Publish Test Release Package' stage prepares the test package and uploads it to JFrog Artifactory. This stage is executed when a github merge is done on the master branch and the release test file (./track/testRelease/) is added/updated (see steps below).

1. Create a new branch in your repository (if necessary). 
1. If you followed the User Guide - Server for [Automated Testing](./docs/UserGuideServer.md#automated-testing), then the following will already exist.  If you did not, then you need to follow those directions before you continue or have your own tests to verify your project/application. 
    - directory ./testing/tests
    - Postman Collection json file in ./testing/tests
    - deploy.sh file in ./testing
1. Copy the [./testing/tests/CHANGELOG.md](./testing/tests/CHANGELOG.md) file from core-template repository to your repository (if you followed the Automated Testing guide in the previous step the file will already be there), there are directions in the file for adding a release. The version number in ./testing/tests/CHANGELOG.md must match the version in the json file in the step below. (Note: The version number should be different than any exiting release version or test release version in the github Release Tab or the package will not be displayed in the github Release Tab.)
1. Create directory ./track/testRelease.
1. Add a release file in ./track/testRelease or copy a release file from the core-template repository, for an example see [testrelease.json file](./track/testRelease/testrelease.json).

Example:

```json
{
    "release_tag": "1.0.0",
    "tag_name": "1.0.0",
    "target_commitish": "master",
    "name": "Core Template Test ",
    "description": "Tests Core Template",
    "body": "Release of Core Template Tests",
    "draft": false,
    "prerelease": true,
    "release_file": "tests-core-template.zip",
    "release_version": "1.0.0"
  }
   ```
Follow the additional steps below:

* replace 'core-template' to your repository name
* replace "Core Template" to the description for your project
* release_version of your json file must match the version in the CHANGELOG.md in the step above
* set "prerelease = true" to set package to unstable or "prerelease = false" to set package to stable; the package should not be set to stable (ie. prerelease = false) until the release package has been deployed, once the package is deployed you have verified the release package so it can be set to stable to be moved to the upper environments (ie. DEV2, Staging, Prod)

6. Once you complete the Pull Request and Merge to the master branch the release will be packaged.
7. Look in the JFrog Artifactory for your package - https://artifactory.csc.com/artifactory/webapp/#/home - click "artifact" then look in the ./utilities/release-test-package.sh and ./Jenkinsfile (variable ARTIFACTORY_TEST_PACKAGE_PATH) file for your artifactory tree structure. 

Note: To mark the package as 'stable', you edit the JSON file in ./track/testRelease and set "prerelease = false", then create a Pull Request (PR) and Merge to the master branch. The package should not be set to 'stable' until the release package has been deployed, once the package is deployed you have verified the release package so it can be set to stable to be moved to the upper environments (ie. DEV2, Staging, Prod). For more details on the release pipeline, see https://github.dxc.com/pages/platform-dxc/release-pipeline/.

### Deploy Tests to DEV

The 'Deploy Tests to DEV' stage takes the test package from JFrog Artifactory and deploys it to the dev environment.

This stage is executed when a github merge is done on the master branch and the json deploy file is added/updated (see steps below).

Steps to deploy to dev environment:
1. Create directory ./track/testDeploy (if it does not exist).
1. Create/Update the Deploy.json file in ./track/testdeploy, for an example see [testDeploy.json](./track/testdeploy/testDeploy.json). 
    Example:

    ```json
    {
        "env": "DEV",
        "version": "1.1.0",
        "attempts": 1
    }
    ```

    Field definitions:

    | Field | Contents |
    | --- | --- |
    | env | The deploy environment, eg: DEV or Sandbox2 |
    | version | The package version to download from JFrog Artifactory (see the previous section for directions on finding the release in the JFrog Artifactory) |
    | attempts | An integer number in case deploy need to be executed more than once |

1. Once you complete the Pull Request and Merge to the master branch the deploy to the Dev environment will be completed. 
1. Verify the tests were ran in the "Deploy Tests to DEV" stage by clicking the checkbox icon next to "cd chmod 777 ./utilities/deploy-test-dev.sh./utilities/deploy-test-dev.sh". For server based template, looking for the section "Executing Newman Tests". For serverless based template, looking for the section "Executing Serverless Invoke Tests".

### Verify

The 'Verify' stage can be used as your Policy/Compliance-as-code section. At this time there is no content in this stage, but it can be added if necessary for your project. This stage is executed everytime the Jenkinsfile is executed.

### Notify

The 'Notify' stage can be used on a failure or any other event you want to send a notification, you can send alerts to multiple targets using parallel condition – email, slack, teams, etc. At this time there is no content in this stage, but it can be added if necessary for your project. This stage is executed everytime the Jenkinsfile is executed.