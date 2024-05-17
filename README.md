# Application regional disaster recovery using ROSA (OpenShift on AWS) and AWS EFS - An unpopular yet effective approach


## Introduction

Disaster ranges from mistakenly deleting data to an entire cloud region or critical service within that region being down. There are many commercial and freemium solutions offerings around this business need.

In the event of a disaster, one question customers often ask is “How do I make sure business can resume as quickly as possible with the least amount of downtime and data loss?”.
This article attempts to demonstrate an approach to solving this problem in a manner that is low-cost yet effective; using static volume provisioning with RedHat OpenShift on AWS (ROSA) and AWS EFS.

In the grand scheme of disaster recovery, replication of persistent volumes alone is not enough when we take a holistic view of all other services applications need to interact with to fully function. For example, one application may need to communicate with a third-party vendor API, a data store service such as AWS RDS, an application running on a VM…etc. Some if not all of the other critical dependencies need to be taken into account when designing a regional DR plan.

The solution works best for workloads with storage performance requirements that can be satisfied with NFS.

This solution may be applied to any of the following scenarios:

A&WapySjHT4S@0n4WS8
- Data protection
- Application migration
- Data proximity, exposing read-only data to workloads deployed in other regions
- Regional failover due to a region or critical service within that region being down
- Protection from accidental data deletion. For example, a mistake causes the entire storage service or persistent volume to be deleted
- Business continuity wargaming


If you need a refresher on the topic of "Disaster Recovery" in the cloud, I suggest you read [this article](https://aws.amazon.com/what-is/disaster-recovery/) from AWS.


## Security Best Practices

AWS EFS is a shared storage service (NFS); hence it is imperative that best security practices such as [File Permissions](https://docs.aws.amazon.com/efs/latest/ug/accessing-fs-nfs-permissions.html) and [Access Policies](https://docs.aws.amazon.com/efs/latest/ug/security-iam.html) be applied to the EFS instance to ensure application teams are able to access their assigned directories; and only team members with elevated privileges can access the entire EFS directory tree. For example, we could limit specific types of access to certain IP ranges, AWS Principals, Roles..etc. 

In the implementation section of this article, I used slightly relaxed policies; however, in a production environment, one should apply even more restrictive policies while ensuring data access by application teams is not hindered.


## Solution Overview

![regional-dr-efs-architecture.jpg](assets/regional-dr-efs-architecture-v4.jpg)

We'll discuss the solution in two phases, before and after the disaster.

### Phase I: Pre-Disaster (Disaster Readiness)

During the readiness phase, in conjunction with our RPO and RTO objectives, we develop the fall-back plan that will be executed in the event of a disaster. Keep in mind that such a plan should be periodically tested to identify any cracks that may have been introduced over time due to technology maturity, and life cycle. 

Moreover, in this phase most if not all application deployments and network traffic will be directed at the Primary region.

At a higher level, the procedure would look like this:

1. Provision the primary OpenShift cluster in region A.
2. Provision the secondary OpenShift cluster in region B.
     - This step can wait until a disaster occurs if RPO and RTO allow for the time it takes to provision a new ROSA cluster. 
       - 45 to 60 mins for OpenShift self-managed and ROSA Classic;
       - 15 to 30 mins for ROSA Hosted Control Planes (HCP).
3. Provision EFS Primary in Region A.
     - Apply appropriate SecurityGroup rules to allow NFS traffic from OpenShift-Primary cluster and the bastion/CICD host.
4. Provision EFS Secondary in Region B.
     - Apply appropriate SecurityGroup rules to allow NFS traffic from OpenShift-Secondary cluster and the bastion/CICD host.
5. Enable replication from EFS-Primary to EFS-Secondary.
6. If you intend to enable dynamic volume provisioning as well, [configure](https://cloud.redhat.com/experts/rosa/aws-efs/) the AWS EFS CSI Driver Operator. Keep in mind that dynamic volumes are not supported by this solution.
7. Implement the automation process (ie: Ansible...etc) for tenants (app teams) to request static persistent volumes on OpenShift-Primary.

    The [volume-create.yaml](./volume-create.yaml) playbook works as follows:
    - Take in required user inputs: AWS credentials, Git credentials, efs_primary_hostname, business_unit, ocp_primary_cluster_name, application_name, pvc_name, pvc_size, namespace, ocp_login_command
    - Validate user inputs for character lengths, OpenShift cluster-admin permission, ...etc.
    - Create the volume directory tree as: `/<prefix>/<business_unit>/<ocp_primary_cluster_name>/<application_name>/<namespace>/<pvc_name>`.
    - Using the predefined PV/PVC template, replace parameters such as <volume_name>, <volume_namespace>, <volume_nfs_server>, <volume_nfs_path>, and save the output manifest to a directory local to the repository.
    - Apply the PV/PVC manifest to OpenShift-Primary; the namespace will be created if it does not exist.
    - Commit and push the PV/PVC manifest to a git SCM.
      - PV/PVC manifest file path: `<playbook-dir>/PV-PVCs/primary/<business_unit>/<ocp_primary_cluster_name>/<application_name>/<namespace>/pv-pvc_<pvc_name>.yaml`
    - Wrap the [volume-create.sh](.ci/volume-create.sh) process into a proper CI pipeline with user inputs provided in the form of job parameters.
8. Implement the automation process (ie: Ansible..etc) for restoring the static volumes on OpenShift-Secondary.

    The [volume-restore.yaml](./volume-restore.yaml) playbook works as follows:

     - Take in required user inputs: AWS credentials, Git credentials, efs_primary_hostname, dest_efs_hostname, ocp_login_command
     - Stop the EFS replication and wait until EFS-Secondary is write-enabled.
     - Recursively scan the PV-PVCs directory, and list all volume manifests used for OpenShift-Primary; for each persistent-volume manifest, replace the EFS-Primary hostname with that of EFS-Secondary.
     - Apply the secondary PV/PVC manifests on OpenShit-Secondary.
     - Commit the secondary PV/PVC manifests to git SCM.
       - PV/PVC manifest file path: `<playbook-dir>/PV-PVCs/secondary/<business_unit>/<ocp_primary_cluster_name>/<application_name>/<namespace>/pv-pvc_<pvc_name>.yaml`
     - Wrap the [volume-restore.sh](.ci/volume-restore.sh) process into a proper CI pipeline with user inputs provided as job parameters.

9. Run [volume-create.sh](.ci/volume-create.sh) pipeline to provision a few persistent volumes on OpenShift-Primary.
10. Deploy a few [sample stateful](./sample-apps/) (with static volumes) on OpenShift-Primary.

### Phase II: Post-Disaster (Disaster Recovery)

In contrast, the recovery phase is when the Secondary region takes over and becomes Primary, applications are redeployed (if not already) and network traffic is rerouted.

At a higher level, the procedure would look like this:

1. Provision OpenShift-Secondary in Region B - If not provisioned already.
2. Integrate OpenShift-Secondary with the EFS-Secondary instance - if not done already.

  - Network connectivity verification
  - Dynamic volume provisioning can be [enabled](https://cloud.redhat.com/experts/rosa/aws-efs/) as well. However, they should be used for non-critical workloads that do not require regional disaster recovery.
3. Run the [volume-restore](.ci/volume-restore.sh) pipeline to restore static volumes onto OpenShift-Secondary.

    This process will scan the `<playbook-dir>/PV-PVCs/primary/<ocp_primary_cluster_name>/*` directory, create a corresponding PV/PVC for each manifest found; and save the resulting volume manifests in `<playbook-dir>/PV-PVCs/secondary/<ocp_primary_cluster_name>*`. `ocp_primary_cluster_name` is the name of the primary cluster. `ocp_primary_cluster_name` is the name of the primary cluster.

4. Redeploy your applications onto OpenShift-Secondary.
5. Reroute network traffic to the Secondary region.

## Implementation

### Pre-requisites
- Basic understanding of NFS, AWS, OpenShift.
- AWS Account
- Permission to create and replicate EFS services
- Two ROSA clusters, primary and secondary
- Bastion host(s) with software packages: python3.11, python3.11-pip, ansible, aws-cli-v2, nfs-utils, nmap, unzip, openshift-cli. 

### Procedure

TL;DR; implementation steps are covered in more detail [here](./Implementation.md).

## Conclusion

We've demonstrated, in the Kubernetes world, how one can achieve regional failover of application state using ROSA, AWS EFS, Static volume provisioning, and Ansible automation. This approach can be taken even further by leveraging Event-Driven Ansible to the mix to remove the need for human intervention in the `volume-create --> volume-restore` cycle.