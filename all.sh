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
       --name eks-devel \
       --role-arn $EKS_SERVICE_ROLE \
       --resources-vpc-config subnetIds=$EKS_SUBNET_IDS,securityGroupIds=$EKS_SECURITY_GROUPS
}
createVPC() {
  aws cloudformation create-stack \
    --stack-name ${STACK_NAME} \
    --template-body file://amazon-eks-vpc-sample.yaml \
    --region us-east-1
}


installAwsEksCli() {
    curl -LO https://s3-us-west-2.amazonaws.com/amazon-eks/1.10.3/2018-06-05/eks-2017-11-01.normal.json
    mkdir -p $HOME/.aws/models/eks/2017-11-01/
    cp eks-2017-11-01.normal.json $HOME/.aws/models/eks/2017-11-01/
    aws configure add-model  --service-name eks --service-model file://$HOME/.aws/models/eks/2017-11-01/eks-2017-11-01.normal.json
}

main() {

export AWS_DEFAULT_REGION=us-east-1
export STACK_NAME=eks-service

EKS_SERVICE_ROLE=$(aws iam list-roles --query 'Roles[?contains(RoleName, `eksService`) ].Arn' --out text)

EKS_SECURITY_GROUPS=$(getStackOutput $STACK_NAME SecurityGroups)
EKS_VPC_ID=$(getStackOutput $STACK_NAME VpcId)
EKS_SUBNET_IDS=$(getStackOutput $STACK_NAME SubnetIds)


}
