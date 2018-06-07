Finally AWS EKS is generally available. If you are keen to give it a go you have 2 docs to start:

- [Getting Started Guide](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)
- [EKS blog](https://aws.amazon.com/blogs/aws/amazon-eks-now-generally-available/)

Unfortunately both have a lot of manual steps. I wanted to have an autoated way to create a
3 node EKS cluster.

## Usage

It is as simple as:
```
source ./all.sh 
eksCreateCluster
```

## Configuration

You can change all paramters, most notably: instanceType, min and max worker numbers:
```
export EKS_NODE_TYPE=t2.small
export EKS_NODE_MIN=3
export EKS_NODE_MAX=3

eksCreateCluster
```

## Cleanup

To delete every resources (VPC, Workers, EKS cluster)
```
eksCleanup
```

Note: the eksServiceRole and keyPair will be kept.

