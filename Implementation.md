# Implementation

> [!NOTE]
> AWS EFS does not support cross-account replication. To solve this use case, you would need to rely on EFS Backups or DataSync.

Two regions, primary (`us-east-1`) and secondary (`us-west-2`) are used for the demonstration. 

## Setting up the PRIMARY Region (us-east-1)


## 1. VPC and Subnets

A VPC and 3 private subnets to setup a regional EFS instance. The bastion host can be deployed in one of the subnets; or on any other subnets as long EFS-Primary and Secondary DNS resolution would work from that host.  In this demo, I used `10.90.0.0/16`  for the primary VPC CIDR and `10.91.0.0/16` for the secondary one.

## 2. Deploy the OpenShift-Primary cluster

There are multiple options available:

- rosa cli
- terraform rhcs provider
- Ansible.

You may use the [rosa-create.sh](.ci/rosa-create.sh) bash script to provision the rosa-primary cluster.

## 3. SecurityGroup for NFS traffic (efs-primary)

Create the efs-primary SecurityGroup and set proper inbound/outbound rules. For inbound, I allowed NFS traffic from the OpenShift-Primary VPC. Since the bastion host is deployed within that VPC, one rule sufficed. Add more inbound/outbound rules based on your situation.

![efs-sg-inbound](assets/efs-sg-inbound.png)

![efs-sg-outbound](assets/efs-sg-outbound.png)

## 4. EFS-Primary

> [!IMPORTANT]
> File system protection should be enabled for EFS-Primary and disabled for EFS-Secondary. This is a requirement to turn on replication.

1. Specify general settings.

    ![efs-create](assets/efs-primary-create.png)

2. Specify the mount targets. You should select the OpenShift-Primary VPC and private subnets, and use efs-primary SecurityGroup.

    ![efs-mount-targets](assets/efs-mount-targets.png)

3. Configure the EFS default access point

    > [!IMPORTANT]
    > `POSIX User` and `Root directory creation permissions` should match what's in the screenshot below for apps running on OpenShift to be able to read/write to EFS. You may apply more restrictions by setting UID and GID to specific numbers other than zero (0), apps accessing the share will have to be configured to run as these UIDs and GIDs.

    For enforcing even more data access boundaries, one could add the logic to create an EFS AccessPoint for each distinct business unit; which is preferred in my opinion.

    ![efs-access-point](assets/efs-primary-ap.png)


4. Specify the file system [access policy](scripts/access-policy-primary.json). The `aws:SourceIp` must contain at least the CIDR of the OpenShift cluster; and any other IP ranges from which the EFS instance will be accessed from.

    ![efs-access-policy](assets/efs-access-policy.png)

5. Review the values provided and create the EFS.


## Setting up the SECONDARY Region (us-west-2)

Repeat the same setup done for the [PRIMARY Region](#setting-up-the-primary-region-us-east-1) in the SECONDARY Region; changing the word "primary" to "secondary".

## 1. VPC and Subnets

To avoid IP conflicts, the CIDR of VPC-Secondary should be different from that of the primary.

## 2. Deploy the OpenShift-Secondary cluster

There are multiple options available:

- rosa cli
- terraform rhcs provider
- Ansible.

You may use the [rosa-create.sh](.ci/rosa-create.sh) bash script to provision the rosa-secondary cluster.

Based on RPO, RTO and cost constraints, one may choose to hold off the provisioning of OpenShift-Secondary until after a disaster has occurred.

For the purpose of being able to follow the guide, both OpenShift-Primary and OpenShift-Secondary need to be created before moving on.

## 3. SecurityGroup for NFS traffic (efs-secondary)

Create the efs-secondary SecurityGroup and set proper inbound/outbound rules. For inbound, I allowed NFS traffic from OpenShift-Secondary VPC. Since the bastion host is deployed within the VPC, one rule sufficed. Add more inbound/outbound rules based on your situation.

![efs-sg-inbound](assets/efs-sg-inbound-secondary.png)

![efs-sg-outbound](assets/efs-sg-outbound.png)

## 4. EFS-Secondary

> [!IMPORTANT]
> File system protection should be enabled for EFS-Primary and disabled for EFS-Secondary. This is a requirement to turn on replication.

1. Specify the general settings, similar to EFS-Primary.

2. Specify the mount targets. You should select the OpenShift-Secondary VPC and private subnets. Use efs-secondary for SecurityGroup.

    ![efs-mount-targets](assets/efs-mount-targets-secondary.png)

3. Configure the EFS default access point

    > [!IMPORTANT]
    > `POSIX User` and `Root directory creation permissions` should match what's in the screenshot below for apps running on OpenShift to be able to read/write to EFS. You may apply more restrictions by setting UID and GID to specific numbers other than zero (0), apps accessing the share will have to be configured to run as these UIDs and GIDs.

    For enforcing even more data access boundaries, one could add the logic to create an EFS AccessPoint for each distinct business unit; which is preferred in my opinion.

    ![efs-access-point](assets/efs-secondary-ap.png)


4. Specify the file system [access policy](scripts/efs-policy-secondary.json). The `aws:SourceIp` must contain at least the CIDR of OpenShift-Secondary; and any other IP ranges from which the EFS instance will be accessed from.

    ![efs-access-policy](assets/efs-access-policy-secondary.png)

5. Review the values provided and create the EFS.


## Enable EFS-Primary to EFS-Secondary data replication

1. Open the EFS-Primary instance and click on the **Replication** tab.

    ![efs-primary-replication](assets/efs-primary-replication.png)

2. Provide details of the EFS-Secondary instance

    ![efs-replication-selection](assets/efs-replication-selection.png)

3. Once replication enabled, replication tab should look like below:

    ![efs-replication-enabled](assets/efs-replication-enabled.png)


## Bastion/CICD Hosts

Two pipelines are needed to complete the automation of [volume-create](.ci/volume-create.sh) which runs on Bastion-Primary (`us-east-1`); and [volume-recovery](.ci/volume-restore.sh) which runs on Bastion-Secondary (`us-west-2`). However, the need to have two bastion hosts can be avoided if VPC-to-VPC DNS resolution is configured.

For the sake of simplicity of the demo, we'll use two bastion hosts; one for each region.

### Bastion Primary

1. Select the AMI

    ![bastion-ami](assets/bastion-ami.png)

2. Select VPC and subnet details, I chose public subnets since I need to access the host from the [public] internet (laptop).

    ![bastion-details](assets/bastion-details.png)

3. Set user data to install required programs

    All required software packages are specified in the [bastion-setup.sh](scripts/bastion-setup.sh) script, let's use it. The `OCP_CLUSTER_DOMAIN` environment variable must be updated to match a valid OpenShift cluster domain or use different means of installing the openshift-client.

    ![bastion-user-data](assets/bastion-user-data.png)

4. Assign an Elastic IP to the host

    If the bastion need to be accessed from the public internet, such as my workstation, create an elastic IP instance and assign it to the EC2 instance; this allow us to have a sticky public IP address that does not change between EC2 reboots.

    ![bastion-elastic-ip-search](assets/bastion-elastic-ip-search.png)

    ![bastion-elastic-ip](assets/bastion-elastic-ip.png)

5. Verify the bastion host has all required programs

    To login, use the ec2 key-pair you downloaded during the EC2 launch step.

    ```sh
    chmod 400 /path/to/bastion-primary.pem
    ssh -i /path/to/bastion-primary.pem ec2-user@x.x.x.x
    ```

    ![bastion-programs-check](assets/bastion-programs-check.png)

6. Confirm the EFS instance can be reached from the bastion host

    ![bastion-efs-mount-check](assets/bastion-efs-mount-check.png)

7. Verify network connectivity between Bastion-Primary, OpenShift-Primary and EFS-Primary

    Verify the network paths are open:

      - OpenShift-Primary (from node terminal) to EFS-Primary

        ```sh
        ncat -z -v fs-xxxxxxxxxxxxx.efs.us-east-1.amazonaws.com 2049
        ```

      - Bastion-Primary to EFS-Primary

        ```sh
        ncat -z -v fs-xxxxxxxxxxxxx.efs.us-east-1.amazonaws.com 2049
        ```

### Bastion Secondary

The Bastion-Secondary is launched within the OpenShift-Secondary VPC.

Repeat the same steps as described for in [Bastion-Primary](#bastion-primary)


## Git Repository Setup

> [!NOTE]
> These steps are unnecessary in proper CI/CD platforms such as Jenkins, GitLab CI, GitHub Action..etc. The repository is expected to be cloned during job execution. 

Before proceeding further, fork this repository into your own personal github/gitlab account.

1. Generate a Personal Access Token for the repository. The PAT needs to have read/write access.

2. Clone the repository onto the bastion host

    ```sh
    # Note the url will change in your case
    git clone https://github.com/luqmanbarry/regional-dr-with-aws-efs.git
    # You will be prompted for username and password.
    > username: <git>
    > password: <PAT>
    ```

# Volume Provisioning

## Overview

Let's say a business unit wants to deploy a set of stateful applications that require persistent volumes. The application teams will submit a **PV/PVC provision** request for these new PV/PVCs to be made available on the OpenShift cluster, in their respective namespaces.

To see the volume provisioning pipeline in action, we will take as example 3 micro-services, all parts of the same application and business_unit; each micro-service is deployed in a separate namespace.

The [volume-create](.ci/volume-create.sh) script is provided to demonstrate how this automation would look like in a CI/CD pipeline.

Since the process handles one volume (PV-PVC) provisioning per run, we'll need one run for each of the three volumes.

> [!IMPORTANT]
> Unless specified otherwise, the repository root directory is the default location from which all scripts will run from.

1. Set user inputs in the form of environment variables

    ```sh
    # AWS AuthN
    export AWS_ACCESS_KEY_ID="<value>"
    export AWS_SECRET_ACCESS_KEY="<value>"
    export AWS_REGION='<value>'

    # EFS-Primary
    export src_efs_hostname="fs-xxxxxxxxxxxxxxx.efs.us-east-1.amazonaws.com"
    # EFS-Secondary
    export dest_efs_hostname="fs-xxxxxxxxxxxxxxx.efs.us-west-2.amazonaws.com"

    ## Git Repository
    export pv_git_commit_token="<value>"
    export pv_git_commit_repository="<value>"

    # OpenShift-Primary Login Command
    export ocp_login_command='oc login --token=<value> --server=<value>'

    # BU & App & PV Info
    export business_unit="sales"
    export application_name="shipping"
    export namespace="shipping-dev"
    export pvc_name="shipping-dev2"
    export pvc_size=10
    export pv_enable_multi_mount=true # Set to false if you want single mount (1pod/pvc)
    ```

2. Run the CI pipeline

    ```sh
    .ci/volume-create.sh
    ```
Repeat steps `#1` and `#2` to the number of volumes you want to provision; 3 in the case of this demo.

## Execution

> Randomly generated values will be used to show what they should look like. 

> All commands will run from Bastion-Primary.

### Application: warehouse

1. Login to Bastion-Primary

    ```sh
    ssh -i .ssh/bastion-primary.pem ec2-user@52.21.22.18
    ```

2. Set user inputs

    ```sh
    # AWS AuthN
    export AWS_ACCESS_KEY_ID="AKIAZL2555555FVBJPEFR"
    export AWS_SECRET_ACCESS_KEY="F2TrALPHMuuhuxOmS8fQsoLSrd4E57TD8AAAnilt"
    export AWS_REGION='us-east-1'

    # AWS EFS-Primary
    export src_efs_hostname="fs-00747965416d5a91d.efs.us-east-1.amazonaws.com"

    ## Git Repository
    export pv_git_commit_token="github_pat_88888888PQ0xYEukOhVw9U9_k111111tkHKE5Gg8CaDqPH2EVFCEv000000eKEnytDv6U6KNX2NSrtKvJkv"
    export pv_git_commit_repository="https://github.com/luqmanbarry/regional-dr-with-aws-efs.git"

    # OpenShift-Primary Login Command
    export ocp_login_command='oc login --token=sha256~bWHzY9YGoSDH4Xj0123456789du3mh0xQv4IsvEEAsU --server=https://api.rosa-primary.x1x2x.p1.openshiftapps.com:6443'

    # BU & App & PV Info
    export business_unit="sales"
    export application_name="warehouse"
    export namespace="warehouse-dev"
    export pvc_name="warehouse-store"
    export pvc_size=200
    export pv_enable_multi_mount=true # Set to false if you want single mount (1pod/pvc)

    ```

3. Run the volume provisioning job

    ```sh
    .ci/volume-create.sh
    ```

    After job execution, the persistent volumes should show up in the OpenShift-Primary cluster.

    ![warehouse-pvc](assets/warehouse-pvc.png)

### Application: point-of-sale

1. Login to Bastion-Primary

    ```sh
    ssh -i .ssh/bastion-primary.pem ec2-user@52.21.22.18
    ```

2. Set user inputs

    ```sh
    # AWS AuthN
    export AWS_ACCESS_KEY_ID="AKIAZL2555555FVBJPEFR"
    export AWS_SECRET_ACCESS_KEY="F2TrALPHMuuhuxOmS8fQsoLSrd4E57TD8AAAnilt"
    export AWS_REGION='us-east-1'

    # AWS EFS-Primary
    export src_efs_hostname="fs-00747965416d5a91d.efs.us-east-1.amazonaws.com"

    ## Git Repository
    export pv_git_commit_token="github_pat_88888888PQ0xYEukOhVw9U9_k111111tkHKE5Gg8CaDqPH2EVFCEv000000eKEnytDv6U6KNX2NSrtKvJkv"
    export pv_git_commit_repository="https://github.com/luqmanbarry/regional-dr-with-aws-efs.git"

    # OpenShift-Primary Login Command
    export ocp_login_command='oc login --token=sha256~bWHzY9YGoSDH4Xj0123456789du3mh0xQv4IsvEEAsU --server=https://api.rosa-primary.x1x2x.p1.openshiftapps.com:6443'

    # BU & App & PV Info
    export business_unit="sales"
    export application_name="point-of-sale"
    export namespace="point-of-sale"
    export pvc_name="point-of-sale"
    export pvc_size=100
    export pv_enable_multi_mount=true # Set to false if you want single mount (1pod/pvc)

    ```

3. Run the volume provisioning job

    ```sh
    .ci/volume-create.sh
    ```
    After job execution, the persistent volumes should show up in the OpenShift-Primary cluster.

    ![point-of-sale-pvc](assets/point-of-sale-pvc.png)

### Application: shipping

1. Login to Bastion-Primary

    ```sh
    ssh -i .ssh/bastion-primary.pem ec2-user@52.21.22.18
    ```

2. Set user inputs

    ```sh
    # AWS AuthN
    export AWS_ACCESS_KEY_ID="AKIAZL2555555FVBJPEFR"
    export AWS_SECRET_ACCESS_KEY="F2TrALPHMuuhuxOmS8fQsoLSrd4E57TD8AAAnilt"
    export AWS_REGION='us-east-1'

    # AWS EFS-Primary
    export src_efs_hostname="fs-00747965416d5a91d.efs.us-east-1.amazonaws.com"

    ## Git Repository
    export pv_git_commit_token="github_pat_88888888PQ0xYEukOhVw9U9_k111111tkHKE5Gg8CaDqPH2EVFCEv000000eKEnytDv6U6KNX2NSrtKvJkv"
    export pv_git_commit_repository="https://github.com/luqmanbarry/regional-dr-with-aws-efs.git"

    # OpenShift-Primary Login Command
    export ocp_login_command='oc login --token=sha256~bWHzY9YGoSDH4Xj0123456789du3mh0xQv4IsvEEAsU --server=https://api.rosa-primary.x1x2x.p1.openshiftapps.com:6443'

    # BU & App & PV Info
    export business_unit="sales"
    export application_name="shipping"
    export namespace="shipping-dev"
    export pvc_name="shipping-dev"
    export pvc_size=75
    export pv_enable_multi_mount=true # Set to false if you want single mount (1pod/pvc)
    ```

3. Run the volume provisioning job

    ```sh
    .ci/volume-create.sh
    ```

    After job execution, the persistent volumes should show up in the OpenShift-Primary cluster.

    ![shipping-pvc](assets/shipping-pvc.png)

### Verify volumes directory tree

From the Bastion-Primary, mount the EFS instance at `./efs` directory and list its content. Notice the playbook added the `k8s-static-volumes` as prefix for all statically provisioned volumes. You may change this to something else from the [inputs.yaml](vars/inputs.yaml) file.

```sh
# Bastion-Primary Login
ssh -i .ssh/bastion-primary.pem ec2-user@x.x.x.x
```

```sh
# Mount EFS-Primary
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-007479643b6d5a91d.efs.us-east-1.amazonaws.com:/ efs
```

```sh
# List directories in business_unit dir
sudo ls -ltrhs efs/k8s-static-volumes/sales

# OUTPUT
total 12K
4.0K drwxrwx---. 3 root root 6.0K May  6 18:32 shipping
4.0K drwxrwx---. 3 root root 6.0K May  6 18:49 warehouse
4.0K drwxrwx---. 3 root root 6.0K May  6 18:55 point-of-sale
```

Run the tree command to view the volumes directory tree.

```sh
sudo tree efs/
efs/
└── k8s-static-volumes
    ├── sales
    │   ├── point-of-sale
    │   │   └── point-of-sale
    │   │       └── point-of-sale
    │   ├── shipping
    │   │   └── shipping-dev
    │   │       └── shipping-dev
    │   └── warehouse
    │       └── warehouse-dev
    │           └── warehouse-store
    └── volumes-report.csv

11 directories, 1 file
```
Up to this point we've provisioned three persistent volumes in different namespaces on the OpenShift-Primary cluster. Next, let's deploy the three (3) sample applications to verify that they can indeed mount these volumes and write to them.

### Demo applications

1. Deploy the 3 applications

    A helm chart is provided to help with the deployment of sample applications. These apps each mount one of the volumes created earlier. Every 15 minutes, each app generate random binary files to the tune of 1.25 Gi.

    ```sh
    # Sign-in to OpenShift-Primary
    oc login --token=sha256~bWHzY9YGoSDH4Xj0123456789du3mh0xQv4IsvEEAsU --server=https://api.rosa-primary.x1x2x.p1.openshiftapps.com:6443

    # Deploy 3 microservices
    helm template volumes-dr-demo ./sample-apps | oc apply -f -
    ```

2. Summary of the amount data written to EFS-Primary so far

    I have left the apps running for 24 hours and here's the amount of data written to EFS-Primary so far.

    ![efs-primary-data-size](assets/efs-primary-data-size.png)

3. Amount of data written by individual applications

    ![warehouse-data](assets/warehouse-data.png)

    ![point-of-sale-data](assets/point-of-sale-data.png)

    ![shipping-data](assets/shipping-data.png)

---

# Volume Recovery - Regional Failover

## Overview

To recap, based on RPO and RTO one should decide on whether to provision OpenShift-Secondary and let it be on standby, or wait until disaster occurs.

For the purpose of this demo, both OpenShift-Primary and OpenShift-Secondary are active.

## Environment Setup

As the failover will take place in the secondary region (`us-west-2`), in a different VPC, we have two options: (1) enable cross VPC DNS resolution and configure SecurityGroups to allow traffic from VPC Primary, this makes it possible to reuse the same bastion host to run the automation scripts; (2) keep the VPCs separated and provision another bastion host within the secondary VPC. I prefer the latter from a network segmentation standpoint.

1. Provision the OpenShift-Secondary cluster if there isn't one active already.

2. Reproduce in VPC Secondary all configurations done in VPC-Primary; configs such as:
   - EFS Security Group
   - EFS-Secondary in terms of: VPC & Subnets, Mount Targets, File Access Policy, Access Point 

3. Verify network connectivity between Bastion-Secondary, OpenShift-Secondary and EFS-Secondary

    Verify the network paths are open:

      - OpenShift-Secondary (from nodes terminal) to EFS-Secondary

        ```sh
        ncat -z -v fs-xxxxxxxxxxxxx.efs.us-east-1.amazonaws.com 2049
        ```

      - Bastion-Secondary to EFS-Secondary

        ```sh
        ncat -z -v fs-xxxxxxxxxxxxx.efs.us-east-1.amazonaws.com 2049
        ``` 

## Execution

> [!NOTE]
> Randomly generated values will be used to show what they should look like. 
> All commands will run from Bastion-Secondary. 

1. Login to Bastion-Secondary

    ```sh
    ssh -i .ssh/bastion-secondary.pem ec2-user@44.241.70.113
    ```

2. Set user inputs in the form of environment variables

    Notice no application information is provided as user inputs; this is because the [volume-restore][.ci/volume-restore.sh] job traverse the created volumes directories, find all persistent volume manifests, update just the `pv.spec.nfs.server` value and then apply the manifest on the OpenShift-Secondary. 

    Because of static volume provisioning and EFS replication, the volumes directories trees will remain the same between EFS-Primary and EFS-Secondary; hence we only need to update the hostname of the NFS server.

    ```sh
    # AWS AuthN
    export AWS_ACCESS_KEY_ID="AKIAZL2555555FVBJPEFR"
    export AWS_SECRET_ACCESS_KEY="F2TrALPHMuuhuxOmS8fQsoLSrd4E57TD8AAAnilt"
    export AWS_REGION='us-east-1'

    # EFS-Primary
    export src_efs_hostname="fs-00747965416d5a91d.efs.us-east-1.amazonaws.com"
    # EFS-Secondary
    export dest_efs_hostname="fs-03847965416d5a91d.efs.us-east-1.amazonaws.com"

    ## Git Repository
    export pv_git_commit_token="github_pat_88888888PQ0xYEukOhVw9U9_k111111tkHKE5Gg8CaDqPH2EVFCEv000000eKEnytDv6U6KNX2NSrtKvJkv"
    export pv_git_commit_repository="https://github.com/luqmanbarry/regional-dr-with-aws-efs.git"

    # OpenShift-Secondary Login Command
    export ocp_login_command='oc login --token=sha256~bWHzY9YGoSDH4Xj0123456789du3mh0xQv4IsvEEAsU --server=https://api.rosa-secondary.x1x2x.p1.openshiftapps.com:6443'
    ```

3. Run the volume restore job

    ```sh
    .ci/volume-restore.sh
    ```


## Deploy Applications


We'll use the same helm chart as before; the only difference is this time they get deployed on OpenShift-Secondary.

```sh
# Sign-in to OpenShift-Secondary
ooc login --token=sha256~bWHzY9YGoSDH4Xj0123456789du3mh0xQv4IsvEEAsU --server=https://api.rosa-secondary.x1x2x.p1.openshiftapps.com:6443

# Deploy 3 microservices
helm template volumes-dr-demo ./sample-apps | oc apply -f -
```

If all goes well (it should), the pods should be able to mount the restored volumes and writing to them.













 
















