#!/bin/bash

createRole() {
    aws cloudformation create-stack \
	--stack-name eks-service-role \
	--template-body file://amazon-eks-service-role.yaml \
	--capabilities CAPABILITY_NAMED_IAM
}


getStackOutput() {
    declare desc=""
    declare stack=${1:?required stackName} outputKey=${2:? required outputKey}

    aws cloudformation describe-stacks \
	--stack-name $stack \
	--query 'Stacks[].Outputs[? OutputKey==`'$outputKey'`].OutputValue' \
	--out text
    
}

createCluster() {
   aws eks create-cluster \
       --name $EKS_CLUSTER_NAME \
       --role-arn $EKS_SERVICE_ROLE \
       --resources-vpc-config subnetIds=$EKS_SUBNET_IDS,securityGroupIds=$EKS_SECURITY_GROUPS

   #wait for "ACTIVE"
   aws eks describe-cluster --name $EKS_CLUSTER_NAME  --query cluster.status --out text

}
createVPC() {
  aws cloudformation create-stack \
    --stack-name ${VPC_STACK_NAME} \
    --template-body file://amazon-eks-vpc-sample.yaml \
    --region us-east-1
}


installAwsEksCli() {
    curl -LO https://s3-us-west-2.amazonaws.com/amazon-eks/1.10.3/2018-06-05/eks-2017-11-01.normal.json
    mkdir -p $HOME/.aws/models/eks/2017-11-01/
    cp eks-2017-11-01.normal.json $HOME/.aws/models/eks/2017-11-01/
    aws configure add-model  --service-name eks --service-model file://$HOME/.aws/models/eks/2017-11-01/eks-2017-11-01.normal.json
}

createKubeConfig() {
  curl -LO https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/darwin/amd64/kubectl
  chmod +x kubectl
  export PATH=$PWD:$PATH

  cat >  ~/.kube/config-eks <<EOF
apiVersion: v1
clusters:
- cluster:
    server: ${EKS_ENDPOINT}
    certificate-authority-data: ${EKS_CERT}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: heptio-authenticator-aws
      args:
        - "token"
        - "-i"
        - "${EKS_CLUSTER_NAME}"
EOF

 export KUBECONFIG=$KUBECONFIG:~/.kube/config-eks
}

createWorkers() {

    aws ec2 create-key-pair --key-name ${WORKER_STACK_NAME} --query 'KeyMaterial' --output text > $HOME/.ssh/id-eks.pem
    chmod 0400 $HOME/.ssh/id-eks.pem

    aws cloudformation create-stack \
	--stack-name $WORKER_STACK_NAME  \
	--template-body file://amazon-eks-nodegroup.yaml \
        --capabilities CAPABILITY_IAM \
        --parameters \
	    ParameterKey=NodeInstanceType,ParameterValue=${EKS_NODE_TYPE} \
	    ParameterKey=NodeImageId,ParameterValue=${EKS_WORKER_AMI} \
	    ParameterKey=NodeGroupName,ParameterValue=${EKS_NODE_GROUP_NAME} \
	    ParameterKey=NodeAutoScalingGroupMinSize,ParameterValue=${EKS_NODE_MIN} \
	    ParameterKey=NodeAutoScalingGroupMaxSize,ParameterValue=${EKS_NODE_MAX} \
	    ParameterKey=ClusterControlPlaneSecurityGroup,ParameterValue=${EKS_SECURITY_GROUPS} \
	    ParameterKey=ClusterName,ParameterValue=${EKS_CLUSTER_NAME} \
	    ParameterKey=Subnets,ParameterValue=${EKS_SUBNET_IDS//,/\\,} \
	    ParameterKey=VpcId,ParameterValue=${EKS_VPC_ID} \
	    ParameterKey=KeyName,ParameterValue=${WORKER_STACK_NAME}

}

authWorkers() {
    cat > aws-auth-cm.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${EKS_INSTANCE_ROLE}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF

    kubectl apply -f aws-auth-cm.yaml
}

main() {

  export AWS_DEFAULT_REGION=us-east-1
  export EKS_WORKER_AMI=ami-dea4d5a1
  export VPC_STACK_NAME=eks-service-vpc
  export WORKER_STACK_NAME=eks-service-worker-nodes
  export EKS_CLUSTER_NAME=eks-devel
  export EKS_SERVICE_ROLE_NAME=eksServiceRole
  
  export EKS_NODE_GROUP_NAME=eks-worker-group
  export EKS_NODE_TYPE=t2.small
  export EKS_NODE_MIN=3
  export EKS_NODE_MAX=3
  
  
  if ! aws iam get-role --role-name $EKS_SERVICE_ROLE_NAME > /dev/null ; then
      createRole
  fi
  
  EKS_SERVICE_ROLE=$(aws iam list-roles --query 'Roles[?contains(RoleName, `eksService`) ].Arn' --out text)
  
  createVPC
  
  EKS_SECURITY_GROUPS=$(getStackOutput $VPC_STACK_NAME SecurityGroups)
  EKS_VPC_ID=$(getStackOutput $VPC_STACK_NAME VpcId)
  EKS_SUBNET_IDS=$(getStackOutput $VPC_STACK_NAME SubnetIds)
  
  createCluster
  
  EKS_ENDPOINT=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --query cluster.endpoint)
  EKS_CERT=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --query cluster.certificateAuthority.data)
  
}
