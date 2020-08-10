# Start from Alpine with NodeJs preinstalled
FROM node:10.6-alpine

ENV LANG C.UTF-8

# add a simple script that can auto-detect the appropriate JAVA_HOME value
# based on whether the JDK or only the JRE is installed
RUN { \
		echo '#!/bin/sh'; \
		echo 'set -e'; \
		echo; \
		echo 'dirname "$(dirname "$(readlink -f "$(which javac || which java)")")"'; \
	} > /usr/local/bin/docker-java-home \
	&& chmod +x /usr/local/bin/docker-java-home
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk
ENV PATH $PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin

ENV JAVA_VERSION 8u171
ENV JAVA_ALPINE_VERSION 8.222.10-r0

RUN set -x \
	&& apk add --no-cache \
		openjdk8="$JAVA_ALPINE_VERSION" \
	&& [ "$JAVA_HOME" = "$(docker-java-home)" ]

# RUN apk add --no-cache openjdk8

ENV TERRAFORM_VERSION=0.12.24
ENV TERRAFORM_SHA256SUM=602d2529aafdaa0f605c06adb7c72cfb585d8aa19b3f4d8d189b42589e27bf11
ENV TERRAFORM_DOWNLOAD_URL=https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip

RUN apk add --no-cache curl jq git bash zip unzip
RUN apk update && apk add openssh-client bash make ncurses grep

RUN curl -o /tmp/terraform.zip -L "${TERRAFORM_DOWNLOAD_URL}" \
        && echo "${TERRAFORM_SHA256SUM}  /tmp/terraform.zip" > /tmp/terraform.sha256sum \
        && sha256sum -cs /tmp/terraform.sha256sum \
        && unzip /tmp/terraform.zip \
        && mv terraform /bin \
        && rm /tmp/terraform.*

# And install all tools required to deploy and test applications
RUN apk add --no-cache \
    bash \
    python \
    py-pip \
  && pip install --upgrade pip \
  && pip install awscli --upgrade \
  && pip install docutils==0.14

# Install npm package dependencies, skipping devDependencies for packages w/ --production
# TODO: Periodically remove unsafe-perm commands to see if missing alpine image uid/gid error has resolved itself
RUN npm config set unsafe-perm true
RUN npm install --global --production \
    newman \
    serverless@1.50.1 \
    serverless-plugin-aws-alerts@1.4.0 \
    mocha@6.2.0 \
    chai@4.2.0 \
    mocha-junit-reporter@1.17.0
RUN npm config set unsafe-perm false

# Install git-secrets for scanning
RUN cd /tmp && git clone https://github.com/awslabs/git-secrets && cd git-secrets && make install


#Install Kubectl for AWS-EKS control

#RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
RUN curl -o kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl && export PATH=$PATH:/usr/local/bin
RUN echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
RUN kubectl version --client

#Install Eksctl
RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
RUN mv /tmp/eksctl /usr/local/bin
RUN eksctl version

#Install IAM Authenticator
RUN curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/amd64/aws-iam-authenticator
RUN chmod +x ./aws-iam-authenticator
RUN mv ./aws-iam-authenticator /usr/local/bin/aws-iam-authenticator && export PATH=$PATH:/usr/local/bin
RUN echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
RUN aws-iam-authenticator help