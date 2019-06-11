# Deploy an OpenFlight Hub

## Launch Hub

### AWS AMI

Available AMIs
```
RegionMap:
  eu-west-2:
    "AMI": "ami-05643cc2a1cdd43c0"
  eu-north-1:
    "AMI": "ami-0cea4271128756572"
  ap-south-1:
    "AMI": "ami-0df6f0a44e0ff8bd0"
  eu-west-3:
    "AMI": "ami-09131c03adc180926"
  eu-west-1:
    "AMI": "ami-07641bd3bbc0b6d18"
  ap-northeast-2:
    "AMI": "ami-0866bde9a302b60af"
  ap-northeast-1:
    "AMI": "ami-050097901f2845e6f"
  sa-east-1:
    "AMI": "ami-01d1c49a1988bb40c"
  ca-central-1:
    "AMI": "ami-01231995b2bc24bcf"
  ap-southeast-1:
    "AMI": "ami-0379400334aef6a3a"
  ap-southeast-2:
    "AMI": "ami-07af90628c7d0154b"
  eu-central-1:
    "AMI": "ami-0c305bf1107d4e3b8"
  us-east-1:
    "AMI": "ami-0261b6cb3767d87f7"
  us-east-2:
    "AMI": "ami-0b40588f014210c59"
  us-west-1:
    "AMI": "ami-015893737acbf783a"
  us-west-2:
    "AMI": "ami-05782ce9b7d1d6642"
```

- Launch OpenFlight AMI

    ![Launch AMI](pictures/ami-01.png)

- Select instance type

    ![Instance Type](pictures/ami-02.png)

- Configure instance details (ensuring that a public IP is assigned)

    ![Public IP](pictures/ami-03.png)

- Configure storage space

    ![Storage Space](pictures/ami-04.png)

- Name the instance

    ![Name Tag](pictures/ami-05.png)

- Configure Security Group to include the following

    ![Security Group](pictures/ami-06.png)

- Launch instance

    ![Launch Instance](pictures/ami-06.png)

## Hub Configuration

- Login to hub

    ```
    [user@myhost ~]$ ssh centos@HUB-IP
    ```

- On first login, there will be some configuration questions

    ```
                                       __ _ _       _     _  ==>
       ==>                            / _| (_)     | |   | |  ==>
      ==>   ___   _ __    ___  _ __  | |_| |_  __ _| |__ | |_  ==>
     ==>   / _ \ | '_ \  / _ \| '_ \ |  _| | |/ _` | '_ \| __|  ==>
    ==>   | (_) || |_) ||  __/| | | || | | | | (_| | | | | |_    ==>
     ==>   \___/ | .__/  \___||_| |_||_| |_|_|\__, |_| |_|\__|  ==>
      ==>        |_|                           __/ |           ==>
       ==>                                    |___/           ==>
        ==>


    Deploying cloud resources requires at least one of either AWS or Azure credentials.

    For information on locating your cloud credentials, see:

        https://github.com/openflighthpc/flight-cloud#configuring-cloud-authentication

    At least one cloud provider must be configured

    Configure AWS Access Credentials? [y/n] y
    AWS Default Region: eu-west-1
    AWS Access Key ID: MyAWSaccessKeyID
    AWS Secret Access Key: MyAWSsecretAccessKey
    Configure Azure Access Credentials? [y/n] n


    Name for the cluster: mycluster
    Finishing cluster configuration...
    Generating Templates
    aws: |================================================================================================================================|
    azure: |==============================================================================================================================|

    OpenFlight Hub Configuration Complete!

    To deploy your cluster:

    1. Deploy the domain

        flight cloud aws deploy mycluster-domain domain

    2. Deploy the gateway

        flight cloud aws deploy gateway1 node/gateway1 -p "securitygroup,network1SubnetID=*mycluster-domain"

    3. Copy the SSH key to the gateway

        scp /root/.ssh/id_rsa root@GATEWAY-IP:/root/.ssh/

    4. Deploy the nodes (example given: node01)

        flight cloud aws deploy node01 node/node01 -p "securitygroup,network1SubnetID=*mycluster-domain"

    ```

- The default cluster has now been configured and is ready for deployment

## Deploy Cluster 

### To AWS

- Deploy the domain

    ```
    flight cloud aws deploy mycluster-domain domain
    ```

- Deploy the gateway

    ```
    flight cloud aws deploy gateway1 node/gateway1 -p "securitygroup,network1SubnetID=*mycluster-domain"
    ```

- Copy the SSH key to the gateway (GATEWAY-IP can be found via `flight cloud aws list machines`)

    ```
    scp /root/.ssh/id_rsa root@GATEWAY-IP:/root/.ssh/
    ```

- Deploy the nodes (example given: node01)

    ```
    flight cloud [aws/azure] deploy node01 node/node01 -p "securitygroup,network1SubnetID=*mycluster-domain"
    ```

### To Azure

- Deploy the domain

    ```
    flight cloud azure deploy mycluster-domain domain
    ```

- Deploy the gateway

    ```
    flight cloud azure deploy gateway1 node/gateway1 -p "securitygroup,network1SubnetID=*mycluster-domain"
    ```

- Copy the SSH key to the gateway (GATEWAY-IP can be found via `flight cloud azure list machines`)

    ```
    scp /root/.ssh/id_rsa root@GATEWAY-IP:/root/.ssh/
    ```

- Deploy the nodes (example given: node01)

    ```
    flight cloud azure deploy node01 node/node01 -p "securitygroup,network1SubnetID=*mycluster-domain"
    ```
