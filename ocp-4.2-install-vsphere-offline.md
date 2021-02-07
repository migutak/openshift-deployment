# Openshift Container Platform V4.2 Offline Installation on Vsphere
## Table of Content
- [Cluster Information](#Cluster-Information)
- [Retrieve Red Hat registered account for your clients with Cloud Paks entitlement](#Retrieve-Red-Hat-registered-account-for-your-clients-with-Cloud-Paks-entitlement)
- [Prepare the necessary infrastructure](#Prepare-the-necessary-infrastructure)
- [Prepare the installer virtual machine](#Prepare-the-installer-virtual-machine)
- [Mirror Openshift images to a local registry](#Mirror-Openshift-images-to-a-local-registry)
- [Prepare cluster ignition files](#Prepare-cluster-ignition-files)
- [Create the cluster VMs](#Create-the-cluster-VMs)
- [Install and configure dnsmasq](#Install-and-configure-dnsmasq)
- [Prepare loadbalancing server](#Prepare-loadbalancing-server)
- [Start bootstrap process](#Start-bootstrap-process)
- [Post installation configuration](#Post-installation-configuration)
- [Configure cluster authentication](#Configure-cluster-authentication)
- [Configuring Rook/Ceph storage](#Configuring-Rook/Ceph-storage)
- [Install Local image registry](#Install-Local-image-registry)
- [Complete and verify cluster installation](#Complete-and-verify-cluster-installation)
- [References](#References)

## Cluster Information:
* Control-plane/Compute vip: 10.100.8.54
* Installer VM: 10.100.8.55
* Bootstrap VM: 10.100.8.59
* Master nodes: 10.100.8.51/52/53
* Worker nodes: 10.100.8.61/62/63/64/65/69

## Prepare the necessary infrastructure:
Provision a new RHEL 8 virtual machine on vcenter with hostname "installer.cp-dev.tbc.sa" and assign it 2cores/16GB-Memory/50GB-disk. This machine will be used as a client to control the openshift installation, you can use any workstation with access to the environment.  
You can download RHEL 8.1 from the following URL: https://access.redhat.com/downloads/content/479/ver=/rhel---8/8.1/x86_64/product-software
## Retrieve Red Hat registered account for your clients with Cloud Paks entitlement
* The following technote provides information on how to secure registered account for your clients with Cloud Paks entitlement:
https://www.ibm.com/support/pages/node/1096000
* If the client PPA primary contact didn't receive the registration emails from Red Hat, you can raise a request on #ibm-rh-fulfillment-project-office Slack channel with ICN/Site-Number/agreement-number (can be retrieved from [fastpass](https://fastpass.w3cloud.ibm.com/sales/fastpass/fastpass.jsp)), they will provide Red Hat "Account #" and resend the registration emails to the client.
* if client still didn't receive the registration emails, send an email to "customerservice@redhat.com" with "Account #" and they will provide you with the contact person at client side that have received the emails, so that you can arrange with him/her. 
## Prepare the installer virtual machine:
1. login into "installer.cp-dev.tbc.sa" with root privileges.
2. Set the installer server hostname:
```shell
hostnamectl set-hostname installer.cp-dev.tbc.sa
```
3. Disable selinux/firewalld
```shell
systemctl disable --now firewalld
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
systemctl reboot
```
4. Configure Redhat subscription of the added server:
```shell
subscription-manager register --username='alaa-farrag-ibm' --password='xxxx'
```
5. Enable "Red Hat Developer Subscription":
```shell
subscription-manager list --available
subscription-manager attach --pool=8a85f99370a284d70170c3f21714711c
```
6. Install httpd server:
```shell
yum install -y httpd
```
7. create a new directory to host the cluster installation artifacts:
```shell
mkdir -p /workspace/cp-dev
```
8. Expose the created folder through httpd server:
```shell
ln -s /workspace/cp-dev /var/www/html/ocp-www
```
9. Start and enable httpd service:
```shell
systemctl enable --now httpd
```
10. download openshift client and installer for linux (can be downloaded from https://cloud.redhat.com/openshift/):
```shell
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.2.23/openshift-client-linux-4.2.23.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.2.23/openshift-install-linux-4.2.23.tar.gz
```
11. Install the downloaded clients:
```shell
tar xvfz openshift-client-linux-4.2.23.tar.gz
tar xvfz openshift-install-linux-4.2.23.tar.gz
mv kubectl oc openshift-install /usr/local/bin/
```
12. Configure "oc" bash auto-completion:
```shell
# execute the following then reopen your shell
yum -y install bash-completion
oc completion bash >>/etc/bash_completion.d/oc_completion
kubectl completion bash >>/etc/bash_completion.d/kubectl_completion
```
13. Generate a new ssh key file:
```shell
ssh-keygen -t rsa -b 4096 -N '' -f /workspace/cp-dev/sshkey
```
14. Start ssh-agent and load keyfile:
```shell
eval "$(ssh-agent -s )"
ssh-add /workspace/cp-dev/sshkey
```
## Mirror Openshift images to a local registry
Since the client don't have a stable internet connectivity, offline installation is required, In this case the installer machine "10.100.8.55" will be used as a bastion host which will mirror the Openshift images from then internet then it will be connected to the servers that will host the openshift and act as local image registry so that the Openshift VMs can retrieve the necessary images while they are disconnected from the internet. The process is explain very well in the [product documentation](https://docs.openshift.com/container-platform/4.2/installing/install_config/installing-restricted-networks-preparations.html#installing-restricted-networks-preparations)
1. Install "podman" and "htpassed":
```shell
yum -y install podman httpd-tools
```
2. 
```shell
mkdir -p /opt/registry/{auth,certs,data}
```
3. generate a self-signed certificate:
```shell
cd /opt/registry/certs
openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -out domain.crt
```
4. Generate a user name and a password for your registry that uses the bcrpt format:
```shell
htpasswd -bBc /opt/registry/auth/htpasswd regadmin Oliya.20
```
5. Create the mirror-registry container to host your registry:
```shell
podman run --name mirror-registry -p 5000:5000  -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key -d docker.io/library/registry:2
```
6. Add the self-signed certificate to your list of trusted certificates:
```shell
cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust
```
7. Confirm that the registry is available:
```shell
curl -u regadmin:Oliya.20 -k https://installer.cp-dev.tbc.sa:5000/v2/_catalog 
{"repositories":[]}
```
If the command output displays an empty repository, your registry is available.
8. Download your registry.redhat.io pull secret from the [Pull Secret page](https://cloud.redhat.com/openshift/install/pull-secret) on the Red Hat OpenShift Cluster Manager site and save it to file "/workspace/cp-dev/pull-secret-raw.json"
9. Convert the pull secret to a more readable format:
```shell
$ cat /workspace/cp-dev/pull-secret-raw.json | jq .  > /workspace/cp-dev/pull-secret.json
```
10. Generate the base64-encoded user name and password or token for your mirror registry:
```shell
echo -n 'regadmin:Oliya.20' | base64 -w0 
cmVnYWRtaW46T2xpeWEuMjA=
```
11. Edit the pull secret file "/workspace/cp-dev/pull-secret.json" and add a section that describes your local registry to it:
```json
  "auths": {
...
    "installer.cp-dev.tbc.sa:5000": {
      "auth": "cmVnYWRtaW46VGJjYWRtaW4uMjA=",
      "email": "h.alhamed@tbc.sa"
    }
...
```
Complete file:
```json
{
  "auths": {
    "cloud.openshift.com": {
      "auth": "b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K2Jhc3NhbWFsaHVtYWlkYW4xeXlqZDE0dGtwajluaDl5bzF2dmNncG00ZW86SjlSRDhPQVMyUEU3VkVROEhPVElPRjlWSzg5Q1A0UllOSTBQTE9TODZZU1o0NENIRVZGNEo2RllFSDJVM0tJVw==",
      "email": "bassam.alhumaidan@tbc.sa"
    },
    "quay.io": {
      "auth": "b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K2Jhc3NhbWFsaHVtYWlkYW4xeXlqZDE0dGtwajluaDl5bzF2dmNncG00ZW86SjlSRDhPQVMyUEU3VkVROEhPVElPRjlWSzg5Q1A0UllOSTBQTE9TODZZU1o0NENIRVZGNEo2RllFSDJVM0tJVw==",
      "email": "bassam.alhumaidan@tbc.sa"
    },
    "registry.connect.redhat.com": {
      "auth": "NTMyNTExNDB8dWhjLTFZeUpEMTRUS1BKOU5oOXlPMVZWQ2dwbTRFbzpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSXlaRGhtT1RNME1UZGhaalkwWmpneE9XUXpaR0l4T0RNeU9UZ3dOMlE1WXlKOS52VTZMUEJJb0ljcEkwZDMxRzhTcUhVMlBKZW4zMzRHalV2THlfdUYzaVo2ZnZXV2RpT2xVT3lBZU5Ia21vR2tpX2hVUGhHRjNJc1lIa2dlXzAtU25JNTJva3lRLWlaUzRORmtiM0NKaFN3QmZJZWdvcXotdFpWb1RaSDFzR3RPU01PT2RacEozUDh2c2ZncHFxdjV0bXo3OFJxSnktUWRnZE56TmFNN0JwQUtjLV8tekcxSkdjUzdSQVNYR1BxbGcwQUEyU3psQlNBYkJ6cDdDQV9VMmlVRkhiWUJfNkRUVjZiQU1UQVNZZ2ZtLWxrWUdub3QxWGpSbjNGNFRIUGdVWlRqTUxxVGd2aWQ3MVZUanhJU1BRalFGTVRzT3ZwRVI3bUwtTVQyWHhGM1BxdVhLRE1jT1RLazBYMlpCWEFSenRId3pqMDVDREoxY1hRM01yZWhmc1FtYi1kMm5SWmF0cHFhNU0tQlpNZ0IwUEpPSkNfYWhVa1BhOC10V3lmZ01wdkZocHctUl8wNjR3Tnl1QkttS0VrcFpPOUhMeEl0RnBCbkJPZE9ORnFqdTcwVzh2cHdWSll2dl9yNzM1aE5nV2x0bXNOTVZja0h5cjlwV3BtUkFiVzA3VmljVE1OV0Q4c20tWkxua1RLcmgzMnBIQ2p4TGFfTHJsQTIyZUJxNlBYci1EclpRcnpiOWhCZjlnenpZZ2dTbk1BZ0pBU1otMDdUeGFzZmFkV2E0SzVGUy1JMzkwRzlYaV8yaFYzUTVqZTB0bHZ2VVhMbHlrMUtwRmpiR2ZTNzgyN0dfanlrYTZrdVo2T0FrY1h1VUlYREFjZktoWWNJUzEwbHFZWGo3cUxOZlMyREFxSjdETGVuLS1pZjJxRGI0YU1YRm1yT2JLX0RadG5mTWZ0MA==",
      "email": "bassam.alhumaidan@tbc.sa"
    },
    "registry.redhat.io": {
      "auth": "NTMyNTExNDB8dWhjLTFZeUpEMTRUS1BKOU5oOXlPMVZWQ2dwbTRFbzpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSXlaRGhtT1RNME1UZGhaalkwWmpneE9XUXpaR0l4T0RNeU9UZ3dOMlE1WXlKOS52VTZMUEJJb0ljcEkwZDMxRzhTcUhVMlBKZW4zMzRHalV2THlfdUYzaVo2ZnZXV2RpT2xVT3lBZU5Ia21vR2tpX2hVUGhHRjNJc1lIa2dlXzAtU25JNTJva3lRLWlaUzRORmtiM0NKaFN3QmZJZWdvcXotdFpWb1RaSDFzR3RPU01PT2RacEozUDh2c2ZncHFxdjV0bXo3OFJxSnktUWRnZE56TmFNN0JwQUtjLV8tekcxSkdjUzdSQVNYR1BxbGcwQUEyU3psQlNBYkJ6cDdDQV9VMmlVRkhiWUJfNkRUVjZiQU1UQVNZZ2ZtLWxrWUdub3QxWGpSbjNGNFRIUGdVWlRqTUxxVGd2aWQ3MVZUanhJU1BRalFGTVRzT3ZwRVI3bUwtTVQyWHhGM1BxdVhLRE1jT1RLazBYMlpCWEFSenRId3pqMDVDREoxY1hRM01yZWhmc1FtYi1kMm5SWmF0cHFhNU0tQlpNZ0IwUEpPSkNfYWhVa1BhOC10V3lmZ01wdkZocHctUl8wNjR3Tnl1QkttS0VrcFpPOUhMeEl0RnBCbkJPZE9ORnFqdTcwVzh2cHdWSll2dl9yNzM1aE5nV2x0bXNOTVZja0h5cjlwV3BtUkFiVzA3VmljVE1OV0Q4c20tWkxua1RLcmgzMnBIQ2p4TGFfTHJsQTIyZUJxNlBYci1EclpRcnpiOWhCZjlnenpZZ2dTbk1BZ0pBU1otMDdUeGFzZmFkV2E0SzVGUy1JMzkwRzlYaV8yaFYzUTVqZTB0bHZ2VVhMbHlrMUtwRmpiR2ZTNzgyN0dfanlrYTZrdVo2T0FrY1h1VUlYREFjZktoWWNJUzEwbHFZWGo3cUxOZlMyREFxSjdETGVuLS1pZjJxRGI0YU1YRm1yT2JLX0RadG5mTWZ0MA==",
      "email": "bassam.alhumaidan@tbc.sa"
    },
    "installer.cp-dev.tbc.sa:5000": {
      "auth": "cmVnYWRtaW46VGJjYWRtaW4uMjA=",
      "email": "h.alhamed@tbc.sa"
    }
  }
}
```
12. Set the required environment variables needed to mirror Openshift images
```shell
{
export OCP_RELEASE='4.2.23-x86_64'
export LOCAL_REGISTRY='installer.cp-dev.tbc.sa:5000' 
export LOCAL_REPOSITORY='ocp4/openshift4' 
export PRODUCT_REPO='openshift-release-dev' 
export LOCAL_SECRET_JSON='/workspace/pull-secret.json' 
export RELEASE_NAME="ocp-release"
}
```
13. Mirror Openshift images, (this step might take a while based on your internet bandwidth):
```shell
oc adm -a ${LOCAL_SECRET_JSON} release mirror --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}
```
14. Record the entire imageContentSources section from the output of the previous command. The information about your mirrors is unique to your mirrored repository, and you must add the imageContentSources section to the install-config.yaml file during installation.
```yaml
imageContentSources:
- mirrors:
  - installer.cp-dev.tbc.sa:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - installer.cp-dev.tbc.sa:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```
15. Extract and install openshift-install binary updated for this environment:
```shell
oc adm -a ${LOCAL_SECRET_JSON} release extract --command=openshift-install "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}"
cp openshift-install /usr/local/bin
```
16. Ensure that "openshift-install" is referencing your local registry (not the online registry):
```shell
openshift-install version
openshift-install v4.2.23
built from commit 8465c322cdd805ed5e43c3fc52a485ca63d305c7
release image installer.cp-dev.tbc.sa:5000/ocp4/openshift4@sha256:405077bc32c7228b403643cc5b47678c6b4fce98bc236e043169f784e325547c
```
## Prepare cluster ignition files:
1. From [Redhat Openshift cluster manager website](https://cloud.redhat.com/openshift/install/vsphere/user-provisioned), retrieve a pull secret needed to pull the necessary OCP images. Save the secret in "/workspace/cp-dev/pull-secret.json"
2. Create an installation configuration file called "/workspace/cp-dev/install-config.yaml" as per the following. You need to include in this file the following
* The content of the image pull secret created in the above section (content of file "/workspace/cp-dev/pull-secret.json")
* The generated ssh public key "/workspace/cp-dev/sshkey.pub".
* The "imageContentSources" generated in the above section.
* The self-signed certificate of the local registry (content of file "/opt/registry/certs/domain.crt") under "additionalTrustBundle" section to be trusted: 
The file should look like:
```yaml
apiVersion: v1
baseDomain: tbc.sa
compute:
- hyperthreading: Enabled   
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled   
  name: master
  replicas: 3
metadata:
  name: cp-dev
platform:
  vsphere:
    vcenter: tat-vcs.tbc.com
    username: openshift@vsphere.local
    password: zR#JFiz9@Qd%
    datacenter: VxRail-Datacenter
    defaultDatastore: G-410-VxRail-vSAN-Datastore-02
pullSecret: '{
  "auths": {
    "cloud.openshift.com": {
      "auth": "b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K2Jhc3NhbWFsaHVtYWlkYW4xeXlqZDE0dGtwajluaDl5bzF2dmNncG00ZW86SjlSRDhPQVMyUEU3VkVROEhPVElPRjlWSzg5Q1A0UllOSTBQTE9TODZZU1o0NENIRVZGNEo2RllFSDJVM0tJVw==",
      "email": "bassam.alhumaidan@tbc.sa"
    },
    "quay.io": {
      "auth": "b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K2Jhc3NhbWFsaHVtYWlkYW4xeXlqZDE0dGtwajluaDl5bzF2dmNncG00ZW86SjlSRDhPQVMyUEU3VkVROEhPVElPRjlWSzg5Q1A0UllOSTBQTE9TODZZU1o0NENIRVZGNEo2RllFSDJVM0tJVw==",
      "email": "bassam.alhumaidan@tbc.sa"
    },
    "registry.connect.redhat.com": {
      "auth": "NTMyNTExNDB8dWhjLTFZeUpEMTRUS1BKOU5oOXlPMVZWQ2dwbTRFbzpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSXlaRGhtT1RNME1UZGhaalkwWmpneE9XUXpaR0l4T0RNeU9UZ3dOMlE1WXlKOS52VTZMUEJJb0ljcEkwZDMxRzhTcUhVMlBKZW4zMzRHalV2THlfdUYzaVo2ZnZXV2RpT2xVT3lBZU5Ia21vR2tpX2hVUGhHRjNJc1lIa2dlXzAtU25JNTJva3lRLWlaUzRORmtiM0NKaFN3QmZJZWdvcXotdFpWb1RaSDFzR3RPU01PT2RacEozUDh2c2ZncHFxdjV0bXo3OFJxSnktUWRnZE56TmFNN0JwQUtjLV8tekcxSkdjUzdSQVNYR1BxbGcwQUEyU3psQlNBYkJ6cDdDQV9VMmlVRkhiWUJfNkRUVjZiQU1UQVNZZ2ZtLWxrWUdub3QxWGpSbjNGNFRIUGdVWlRqTUxxVGd2aWQ3MVZUanhJU1BRalFGTVRzT3ZwRVI3bUwtTVQyWHhGM1BxdVhLRE1jT1RLazBYMlpCWEFSenRId3pqMDVDREoxY1hRM01yZWhmc1FtYi1kMm5SWmF0cHFhNU0tQlpNZ0IwUEpPSkNfYWhVa1BhOC10V3lmZ01wdkZocHctUl8wNjR3Tnl1QkttS0VrcFpPOUhMeEl0RnBCbkJPZE9ORnFqdTcwVzh2cHdWSll2dl9yNzM1aE5nV2x0bXNOTVZja0h5cjlwV3BtUkFiVzA3VmljVE1OV0Q4c20tWkxua1RLcmgzMnBIQ2p4TGFfTHJsQTIyZUJxNlBYci1EclpRcnpiOWhCZjlnenpZZ2dTbk1BZ0pBU1otMDdUeGFzZmFkV2E0SzVGUy1JMzkwRzlYaV8yaFYzUTVqZTB0bHZ2VVhMbHlrMUtwRmpiR2ZTNzgyN0dfanlrYTZrdVo2T0FrY1h1VUlYREFjZktoWWNJUzEwbHFZWGo3cUxOZlMyREFxSjdETGVuLS1pZjJxRGI0YU1YRm1yT2JLX0RadG5mTWZ0MA==",
      "email": "bassam.alhumaidan@tbc.sa"
    },
    "registry.redhat.io": {
      "auth": "NTMyNTExNDB8dWhjLTFZeUpEMTRUS1BKOU5oOXlPMVZWQ2dwbTRFbzpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSXlaRGhtT1RNME1UZGhaalkwWmpneE9XUXpaR0l4T0RNeU9UZ3dOMlE1WXlKOS52VTZMUEJJb0ljcEkwZDMxRzhTcUhVMlBKZW4zMzRHalV2THlfdUYzaVo2ZnZXV2RpT2xVT3lBZU5Ia21vR2tpX2hVUGhHRjNJc1lIa2dlXzAtU25JNTJva3lRLWlaUzRORmtiM0NKaFN3QmZJZWdvcXotdFpWb1RaSDFzR3RPU01PT2RacEozUDh2c2ZncHFxdjV0bXo3OFJxSnktUWRnZE56TmFNN0JwQUtjLV8tekcxSkdjUzdSQVNYR1BxbGcwQUEyU3psQlNBYkJ6cDdDQV9VMmlVRkhiWUJfNkRUVjZiQU1UQVNZZ2ZtLWxrWUdub3QxWGpSbjNGNFRIUGdVWlRqTUxxVGd2aWQ3MVZUanhJU1BRalFGTVRzT3ZwRVI3bUwtTVQyWHhGM1BxdVhLRE1jT1RLazBYMlpCWEFSenRId3pqMDVDREoxY1hRM01yZWhmc1FtYi1kMm5SWmF0cHFhNU0tQlpNZ0IwUEpPSkNfYWhVa1BhOC10V3lmZ01wdkZocHctUl8wNjR3Tnl1QkttS0VrcFpPOUhMeEl0RnBCbkJPZE9ORnFqdTcwVzh2cHdWSll2dl9yNzM1aE5nV2x0bXNOTVZja0h5cjlwV3BtUkFiVzA3VmljVE1OV0Q4c20tWkxua1RLcmgzMnBIQ2p4TGFfTHJsQTIyZUJxNlBYci1EclpRcnpiOWhCZjlnenpZZ2dTbk1BZ0pBU1otMDdUeGFzZmFkV2E0SzVGUy1JMzkwRzlYaV8yaFYzUTVqZTB0bHZ2VVhMbHlrMUtwRmpiR2ZTNzgyN0dfanlrYTZrdVo2T0FrY1h1VUlYREFjZktoWWNJUzEwbHFZWGo3cUxOZlMyREFxSjdETGVuLS1pZjJxRGI0YU1YRm1yT2JLX0RadG5mTWZ0MA==",
      "email": "bassam.alhumaidan@tbc.sa"
    },
    "installer.cp-dev.tbc.sa:5000": {
      "auth": "cmVnYWRtaW46VGJjYWRtaW4uMjA=",
      "email": "h.alhamed@tbc.sa"
    }
  }
}'
sshKey: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCqNnR8Tq2Gx5hJXcnsg/qpxVKcqm5N04VJ4kihukwAPEvLEuBBUnAZNkNHtuF3WtHsCW+n2/cyU0mO4b0c69Js14PuhhLCtIf8RiF2hdD9F0FfJvJx/ONkQE4EChZDOvc+PyJiuD+vBAIr5D+J94nyhFzGIh80aa84b6cVxipdGpZ11TBD9Fa1b1v69/6+rpM6YoXSEP7/1OAD0IUVAhVufm1xHKPnHgDCpYttgMzwPACh+e9duBcHETFwWKYRawZsvNy7WtoS7mbMm96OnLvA6CffERucI60VLOqeskrMmQVEf//E28YOLAuBndajfxHVp8eSh7gBbETbfqari1tLOdSQ/y7CEyfPofhTTb/2bRzDU/v0qZIaRBEbwKzGIPv1Y8YFNrN5a0/4r7+VqsbMCXIZA8Wp46oyjmTugcd3FKB8MIgpWS5DXE/vfjZ3UgXsld8C4mMBWMjELNGZdni9KcB48hGrDo6zn5tlzgudR2pFX/BDesJKec22jxieLt5P5IHFKtEuZB247XIzEaLJXRk/8789V/zw3a77ocBjMj7xbFXd7IK+fxQmtyykF09C3McEysLUsQgVt3vi+4LJ1T4s+Zq/R6N+hb00Gl58FA5txg/k09CnGQ6ShLOai9nMJ3+hHSqhArg95WJ+FWTd7wd0nOSnBP/eoiHjAGVq0w== root@installer.cp-dev.tbc.sa'
additionalTrustBundle: |
  -----BEGIN CERTIFICATE-----
  MIIF/zCCA+egAwIBAgIUOV9R5jd6XfwlHenqgiuRUG9ZW/4wDQYJKoZIhvcNAQEL
  BQAwgY4xCzAJBgNVBAYTAlNBMQ8wDQYDVQQIDAZSaXlhZGgxDzANBgNVBAcMBlJp
  eWFkaDEMMAoGA1UECgwDVEJDMQwwCgYDVQQLDANUQkMxIDAeBgNVBAMMF2luc3Rh
  bGxlci5jcC1kZXYudGJjLnNhMR8wHQYJKoZIhvcNAQkBFhBoLmFsaGFtZWRAdGJj
  LnNhMB4XDTIwMDMxOTA4NTQzN1oXDTIxMDMxOTA4NTQzN1owgY4xCzAJBgNVBAYT
  AlNBMQ8wDQYDVQQIDAZSaXlhZGgxDzANBgNVBAcMBlJpeWFkaDEMMAoGA1UECgwD
  VEJDMQwwCgYDVQQLDANUQkMxIDAeBgNVBAMMF2luc3RhbGxlci5jcC1kZXYudGJj
  LnNhMR8wHQYJKoZIhvcNAQkBFhBoLmFsaGFtZWRAdGJjLnNhMIICIjANBgkqhkiG
  9w0BAQEFAAOCAg8AMIICCgKCAgEA20KwhTjyC0RVorn4spQd5+lYDLngLFSAB6fb
  Uu8Tf/Z1GLjICOisRi8C9nZ89eTxaRrMzTxFbt0AgImHAGZ6E9eO7jwRKj9Xuch/
  evodjp3YL17V9KoXYqXV2Sfyl7hX9fudzkm3ppQtIp8s+58myzroS9qhZIpN8Zgr
  PwQsvQ2u0UCuwIOsGHPS3Je75/McDhMss33ix8WWegyppU8zk9+5jejo4Kwez0iL
  WbX9V8Lko4K1Yh506kh68wYw01D2kUgouSwQ0UgDqViDFUFYLNu7JHFn8vBhstkZ
  RVZKMsmPMhsgdat/DDjSnhJbAfq/dMLuVL6cFgqjxs9f9sboL3YH2kS2pHGrpiXh
  wMypYfPFnDybAsbOnQLDivncgp4E6+2iiZlieeimmHsvL+DneUbLhN/xUpSjtSVO
  5zBSkjtkqAB6OqTYDpBN4xazBuuQiyegR0Zlt+gU1laGTNPsIX8JQ0hcHrt6w/0R
  oJ4jeJ+gtk8DGNYr0pB7eggQk6MJ3pcd1dRSawPkIP5fZZNrtKIvaNdSFWAgez31
  ooZTmDZQLKPH7YgH/9tEA7iZeg8KIY54BNVHxOvvjIe4/Wt9oYWtLp1gGsFxDoFF
  JakC9XQGJ03zYYRspOLtpdTz7z9lpESnakiUUgBMSjDnrz9YBUfK/IJshGl6wr1M
  AmKwHRsCAwEAAaNTMFEwHQYDVR0OBBYEFBpKR58CklPkG2DyPzepoJ+8rwY1MB8G
  A1UdIwQYMBaAFBpKR58CklPkG2DyPzepoJ+8rwY1MA8GA1UdEwEB/wQFMAMBAf8w
  DQYJKoZIhvcNAQELBQADggIBAFymCGhqNbBg4E8sNi91wUpg/WaNxuKnDpL3JnZK
  XWUZsUONQ49/5e5CH5brhkaILISTqH+NSKUhJYMzJEbjZWygbgbKHkweN4lYo4CB
  edDC+KjiI8XRU9v4GoPvLpyubRKxLG/ibJ9AmLjeb43xIyAvWyHsqrbV/p13tFaq
  vxtJ4p1ru/LVIesv/bNSBpyztcrhtS2FnPEmJrfmU7X6akasDzYEgZqoEPsB3cke
  SLZH77uIjgD50quOvL7xiG5IU6vg1UbhFpODMTjgs5okO4gRVc5Of4rz8JIvQlJg
  RnI5fvXEDGmCSfq8IgmCIZoBt7dXJzMxKPSqjK1BeylVPxDQribIuJO1tLsY3Fre
  wXscKNZ6bDNsZvwUUkFMxp6gO3yOHNoM9qHl+y7efLk8F1OI2IYf5oM6Ye/l3CR5
  5RDhT8uYYYj0yRQJb7AQ6KLh5yuOETjBPVQms5X/wc0ihDzAwaN+2EuPtrMUXeTv
  ZWWj0dB6CnMSQR0TIR43oNUbQtR9sfnCd9+mLTleh8FPxGI5EDRQ9CojlkWmTBln
  FvqfHJInqNsISMuz6yStW72dPjVSJ8/cS3sbDzFjGjrgLTmjv3SNBqVb+XSI84+6
  ajiFymTCGt3maEMAlAKRdR/w7ei0bBL5CMW7oNJLSXfQPVi+PeyyRaHWdT5eCQIl
  Dxwn
  -----END CERTIFICATE-----
imageContentSources:
- mirrors:
  - installer.cp-dev.tbc.sa:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - installer.cp-dev.tbc.sa:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```
3. take a backup of the "/workspace/cp-dev/install-config.yaml" as it will be deleted after generating the cluster manifest files:
```shell
cp /workspace/cp-dev/install-config.yaml /workspace/cp-dev/install-config.yaml.bkp
```
4. create the cluster installation manifest files, these files will be saved in "/workspace/cp-dev/manifests":
```shell
openshift-install create manifests --dir /workspace/cp-dev
```
5. if you want to pervent master nodes from hosting workload pods, change the "spec.mastersSchedulable" property to false in "cluster-scheduler-02-config.yml" manifest file.
6. Create ignition files:
```shell
openshift-install create ignition-configs --dir /workspace/cp-dev
```
7. Set read only access for bootstrap ignition file:
```shell
chmod 544 /workspace/cp-dev/bootstrap.ign
```
8. Create "/workspace/cp-dev/append-bootstrap.ign" file with the following content:
```shell
cat << EOF > /workspace/cp-dev/append-bootstrap.ign
{
  "ignition": {
    "config": {
      "append": [
        {
          "source": "http://10.100.8.55/ocp-www/bootstrap.ign", 
          "verification": {}
        }
      ]
    },
    "timeouts": {},
    "version": "2.1.0"
  },
  "networkd": {},
  "passwd": {},
  "storage": {},
  "systemd": {}
}
EOF
```
9. Convert the master, worker, and secondary bootstrap Ignition config files to Base64 encoding:
```shell
{
base64 -w0 /workspace/cp-dev/master.ign > /workspace/cp-dev/master.64
base64 -w0 /workspace/cp-dev/worker.ign > /workspace/cp-dev/worker.64
base64 -w0 /workspace/cp-dev/append-bootstrap.ign > /workspace/cp-dev/append-bootstrap.64
}
```
## Create the cluster VMs
1. Download coreos OVA image from redhat download site "https://cloud.redhat.com/openshift/install/vsphere/user-provisioned" and save it:
```shell
cd /workspace/cp-dev
wget "https://access.cdn.redhat.com/content/origin/files/sha256/29/29b98763bc538ec0b7ad39774b643ef69dc0c0fdad25bd0da3078e54ab86253b/rhcos-4.2.0-x86_64-vmware.ova?user=0ee308253ebee28f2d97c752f33124b3&_auth_=1580897789_f7a965b43070fd32de3e42872d0814fb" -O rhcos-4.2.0-x86_64-vmware.ova
```
2. From vmware vCenter UI "https://tat-vcs.tbc.com/ui", Create a new VM folder and give it a name that matches the cluster name that you specified in the install-config.yaml file which is "cp-dev". Folder name should match the cluster name defined by "metadata.name" property in "install-config.yaml" config file. It will also be part of the cluster FQDN (".<metadata.name>.<baseDomain>"). Below screen captures are provided for guidence if you are not familier with vCenter, they are not completely matching this environment:  
<kbd><img src="./resources/i01.png" /></kbd>
<kbd><img src="./resources/i02.png" /></kbd>
3. Create a VM template from RHCOS OVA image as per the following:
<kbd><img src="./resources/i03.png" /></kbd>
<kbd><img src="./resources/i04.png" /></kbd>
<kbd><img src="./resources/i05.png" /></kbd>
<kbd><img src="./resources/i06.png" /></kbd>
<kbd><img src="./resources/i07.png" /></kbd>
<kbd><img src="./resources/i08.png" /></kbd>
<kbd><img src="./resources/i09.png" /></kbd>
<kbd><img src="./resources/i10.png" /></kbd>
<kbd><img src="./resources/i11.png" /></kbd>

4. Create a new VM from the created template to host the bootstrap node:
<kbd><img src="./resources/i12.png" /></kbd>
<kbd><img src="./resources/i13.png" /></kbd>
<kbd><img src="./resources/i14.png" /></kbd>
<kbd><img src="./resources/i15.png" /></kbd>
<kbd><img src="./resources/i16.png" /></kbd>
<kbd><img src="./resources/i17.png" /></kbd>
<kbd><img src="./resources/i18.png" /></kbd>
<kbd><img src="./resources/i19.png" /></kbd>
  
Add the following properties:
* Name: "guestinfo.ignition.config.data"  
  Value: content of file "/workspace/cp-dev/append-bootstrap.64"  
* Name: "guestinfo.ignition.config.data.encoding"  
  Value: "base64"
* Name: "disk.EnableUUID"  
  Value: "TRUE"  

<kbd><img src="./resources/i20.png" /></kbd>
<kbd><img src="./resources/i21.png" /></kbd>  
5. Repeat the same process to create other cluster nodes (master & compute), just make sure you are using the correct amount of CPU/RAM/Disk for each type of nodes and also update the properties with the ignition file suitable for the node type you are creating as per the following:
  #### Master nodes:
  * Name: "guestinfo.ignition.config.data"  
  Value: content of file "/workspace/cp-dev/master.64" 
  #### Compute nodes:
  * Name: "guestinfo.ignition.config.data"  
  Value: content of file "/workspace/cp-dev/worker.64"
  #### Minimum resources requirements:
  <kbd><img src="./resources/requirements.png" /></kbd> 
6. For the storage nodes, they will use the same configuration as worker nodes however you need to add extra disks to be used for the persistent storage provider that will be used:
<kbd><img src="./resources/i27.png" /></kbd>

## Install and configure dnsmasq:
1. Install dnsmasq on the installer VM:
```shell
yum install -y dnsmasq
```
2. Retrieve the MAC addressess of the created VM from the vCenter then update the DNS/DHCP configuration ensure the IP assignment for all the created virtual machines.
<kbd><img src="./resources/i30.png" /></kbd>
3. Apply dnsmasq configuration as per the following:
```shell
cat << EOF > /etc/dnsmasq.d/ocp.conf
# Common Config
bind-interfaces
interface=lo,ens192
dhcp-option=option:router,10.100.8.1
dhcp-option=option:dns-server,10.100.8.55
#dhcp-range=10.100.8.55,10.100.8.55
resolv-file=/etc/resolv.dnsmasq.conf

#vcenter endpoint
address=/tat-vcs.tbc.com/10.1.202.61

# Cluster end-points:
# Master api server DNS record
address=/api-int.cp-dev.tbc.sa/10.100.8.54
address=/api-ext.cp-dev.tbc.sa/10.100.8.54
address=/api.cp-dev.tbc.sa/10.100.8.54

# ETCD DNS records
address=/etcd-0.cp-dev.tbc.sa/10.100.8.51
srv-host=_etcd-server-ssl._tcp.cp-dev.tbc.sa,etcd-0.cp-dev.tbc.sa,2380
address=/etcd-1.cp-dev.tbc.sa/10.100.8.52
srv-host=_etcd-server-ssl._tcp.cp-dev.tbc.sa,etcd-1.cp-dev.tbc.sa,2380
address=/etcd-2.cp-dev.tbc.sa/10.100.8.53
srv-host=_etcd-server-ssl._tcp.cp-dev.tbc.sa,etcd-2.cp-dev.tbc.sa,2380

# Router wildcard DNS record
address=/.apps.cp-dev.tbc.sa/10.100.8.54

# Node specific config
# Bootstrap
dhcp-host=00:50:56:a7:aa:66,10.100.8.59
address=/bootstrap.cp-dev.tbc.sa/10.100.8.59
ptr-record=59.8.100.10.in-addr.arpa,bootstrap.cp-dev.tbc.sa

# master1
dhcp-host=00:50:56:a7:ae:84:4b,10.100.8.51
address=/master01.cp-dev.tbc.sa/10.100.8.51
ptr-record=51.8.100.10.in-addr.arpa,master01.cp-dev.tbc.sa

# master2
dhcp-host=00:50:56:a7:55:fd,10.100.8.52
address=/master02.cp-dev.tbc.sa/10.100.8.52
ptr-record=52.8.100.10.in-addr.arpa,master02.cp-dev.tbc.sa

# master3
dhcp-host=00:50:56:a7:84:7c,10.100.8.53
address=/master03.cp-dev.tbc.sa/10.100.8.53
ptr-record=53.8.100.10.in-addr.arpa,master03.cp-dev.tbc.sa

# worker1
dhcp-host=00:50:56:a7:b8:ee,10.100.8.61
address=/worker01.cp-dev.tbc.sa/10.100.8.61
ptr-record=61.8.100.10.in-addr.arpa,worker01.cp-dev.tbc.sa

# worker2
dhcp-host=00:50:56:a7:3a:8b,10.100.8.62
address=/worker02.cp-dev.tbc.sa/10.100.8.62
ptr-record=62.8.100.10.in-addr.arpa,worker02.cp-dev.tbc.sa

# worker3
dhcp-host=00:50:56:a7:d6:69,10.100.8.63
address=/worker03.cp-dev.tbc.sa/10.100.8.63
ptr-record=63.8.100.10.in-addr.arpa,worker03.cp-dev.tbc.sa

# worker4
dhcp-host=00:50:56:a7:78:aa,10.100.8.64
address=/worker04.cp-dev.tbc.sa/10.100.8.64
ptr-record=64.8.100.10.in-addr.arpa,worker04.cp-dev.tbc.sa

# worker5
dhcp-host=00:50:56:a7:89:c8,10.100.8.65
address=/worker05.cp-dev.tbc.sa/10.100.8.65
ptr-record=65.8.100.10.in-addr.arpa,worker05.cp-dev.tbc.sa

# worker6
dhcp-host=00:50:56:a7:9f:db,10.100.8.69
address=/worker06.cp-dev.tbc.sa/10.100.8.69
ptr-record=69.8.100.10.in-addr.arpa,worker06.cp-dev.tbc.sa
EOF
```
4. Configure your dnsmasq to upsteam to your environment external DNS server
```shell
cat << EOF > /etc/resolv.dnsmasq.conf
search cp-dev.tbc.sa
nameserver 10.215.226.132
nameserver 10.215.226.133
EOF
```
5. update the installer server to resolve from its dns server:
```shell
mv /etc/resolv.conf  /etc/resolv.conf.orig
nmcli con mod ens192 ipv4.dns "10.100.8.55"
systemctl restart NetworkManager.service
```
6. Start and enable DNS Masq server
```shell
systemctl enable --now dnsmasq.service
```

## Prepare loadbalancing server
1. add the control plane LB IP "10.100.8.54" as secondry IPs for the installer vm that will host the load-balancing software haproxy.
2. install haproxy loadbalancer on the installer vm:
```shell
yum install -y haproxy
```
3. Configure haproxy to loadbalance both the control and compute traffic by adding the followng lines to haproxy configuration file "/etc/haproxy/haproxy.cfg":
```shell
cat << EOF > /etc/haproxy/haproxy.cfg
#---------------------------------------------------------------------
# Example configuration for a possible web application.  See the
# full configuration options online.
#
#   https://www.haproxy.org/download/1.8/doc/configuration.txt
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    # to have these messages end up in /var/log/haproxy.log you will
    # need to:
    #
    # 1) configure syslog to accept network log events.  This is done
    #    by adding the '-r' option to the SYSLOGD_OPTIONS in
    #    /etc/sysconfig/syslog
    #
    # 2) configure local2 events to go to the /var/log/haproxy.log
    #   file. A line like the following can be added to
    #   /etc/sysconfig/syslog
    #
    #    local2.*                       /var/log/haproxy.log
    #
    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

    # utilize system-wide crypto-policies
    ssl-default-bind-ciphers PROFILE=SYSTEM
    ssl-default-server-ciphers PROFILE=SYSTEM

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

# Control Plane config
frontend api
    bind 10.100.8.54:6443
    mode tcp
    default_backend             api

frontend machine-config
    bind 10.100.8.54:22623
    mode tcp
    default_backend             machine-config

backend api
    mode tcp
    balance     roundrobin
    server  bootstrap 10.100.8.59:6443 check
    server  master01 10.100.8.51:6443 check
    server  master02 10.100.8.52:6443 check
    server  master03 10.100.8.53:6443 check

backend machine-config
    mode tcp
    balance     roundrobin
    server  bootstrap 10.100.8.59:22623 check
    server  master01 10.100.8.51:22623 check
    server  master02 10.100.8.52:22623 check
    server  master03 10.100.8.53:22623 check

# apps config
frontend https
    mode tcp
    bind 10.100.8.54:443
    default_backend             https

frontend http
    mode tcp
    bind 10.100.8.54:80
    default_backend             http

backend https
    mode tcp
    balance     roundrobin
    server  worker01 10.100.8.61:443 check
    server  worker02 10.100.8.62:443 check
    server  worker03 10.100.8.63:443 check
    server  worker04 10.100.8.64:443 check
    server  worker05 10.100.8.65:443 check
    server  worker06 10.100.8.69:443 check

backend http
    mode tcp
    balance     roundrobin
    server  worker01 10.100.8.61:80 check
    server  worker02 10.100.8.62:80 check
    server  worker03 10.100.8.63:80 check
    server  worker04 10.100.8.64:80 check
    server  worker05 10.100.8.65:80 check
    server  worker06 10.100.8.69:80 check
EOF
```
4. Update the httpd server to only listen on the installer IP address (not the LA IP address) by applying the following configuration:
```
use the "Listen" config to assign specific IP address in "/etc/httpd/conf/httpd.conf" config file
Listen 10.100.8.55:80

use the "Listen" config to assign specific IP address in "/etc/httpd/conf.d/ssl.conf" config file
Listen 10.100.8.55:443 https
```
5. Restart the httpd service:
```shell
systemctl restart httpd
```
## Start bootstrap process
Note: It is recommended to take a snapshot of all the created vms before starting them so that easier to rerun the installation if it fails.
1. From the vcenter UI, start all the created OCP VMs.
2. Check the content of dnsmasq lease file "/var/lib/dnsmasq/dnsmasq.leases" to ensure that the VMs has been assigned the correct IPs.
3. You can use the following command to check if the bootstap process is completed or still in progress.
```shell
openshift-install --dir /workspace/cp-dev wait-for bootstrap-complete --log-level debug
DEBUG OpenShift Installer v4.2.23                  
DEBUG Built from commit 8465c322cdd805ed5e43c3fc52a485ca63d305c7 
INFO Waiting up to 30m0s for the Kubernetes API at https://api.cp-dev.tbc.sa:6443... 
INFO API v1.14.6-152-g117ba1f up                  
INFO Waiting up to 30m0s for bootstrapping to complete... 
DEBUG Bootstrap status: complete                   
INFO It is now safe to remove the bootstrap resources
```
4. It took about 10mins to bootstrap the cluster, if it is taking more time, you can further investigate by ssh to the bootstrap node and get the logs of the bootkube service as per the following:
```shell
ssh -i /workspace/cp-dev/sshkey core@10.100.8.59
journalctl -b -f -u bootkube.service
```
5. You can also gather the bootstrap process logs using the following command:
```shell
openshift-install --dir /workspace/cp-dev gather bootstrap --bootstrap 10.100.8.59 --master 10.100.8.51
```
6. If you have a configuration issue and you want to regenerate the ignition files, it is important to delete and recreate the VMs using the new ignition configuration. If you are doing so, remember to update the dnsmasq DHCP configuration with the new VMs MAC addresses and clear the content of the lease file "/var/lib/dnsmasq/dnsmasq.leases" then restart the dnsmasq service. After this you can start the new VMs.
7. If you will regenerate the ignition files in the same folder ensure to delete the following files before regeneration:
```shell
rm -rf *.64 *.ign auth .openshift_install_state.json .openshift_install.log
```
8. After the bootstrap process is complete, remove the bootstrap node from the control plane load balancing in the haproxy configuration then restart it.

## Configure cluster authentication
1. Login to the cluster using kubeconfig file:
```shell
export KUBECONFIG=/workspace/cp-dev/auth/kubeconfig
```
2. From the installation VM, install htpasswd tool to generate an encrypted password file:
```shell
yum -y install httpd-tools
htpasswd -c -B -b htpasswd.txt ocpadmin Oliya.20
```
3. Create a k8s secrete with the htpasswd file content:
```shell
oc create secret generic htpass-secret --from-file=htpasswd=htpasswd.txt -n openshift-config
```
4. Create k8s identity provider custom resource pointing to the created htpasswd secret 
```shell
cat << EOF > htpasswd.yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: my_htpasswd_provider 
    mappingMethod: claim 
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret
EOF
```
5. Assign the necessary roles to the created users:
```shell
oc apply -f htpasswd.yaml
oc adm policy add-cluster-role-to-user cluster-admin ocpadmin
```
6. Unset the kubeconfig env variable (other wise you will get certificate issue when trying to login "error: x509: certificate signed by unknown authority"):
```shell
unset KUBECONFIG
```
7. Login to your cluster:
```shell
oc login https://api.cp-dev.tbc.sa:6443 --insecure-skip-tls-verify=true -u ocpadmin
```
## Configuring Rook/Ceph storage:
Follow rook/ceph installation instructions available [here](./rook-ceph-install.md).
## Install Local image registry:
1. Create a RWX pvc using Cephfs (rook-cephfs) storage class:
```shell
cat << EOF > image-registry-storage.yaml 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: image-registry-storage
  namespace: openshift-image-registry
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: rook-cephfs
EOF
oc create -f image-registry-storage.yaml
```
2. Update the image registry operator configuration to use the created PVC:
```shell
oc edit configs.imageregistry.operator.openshift.io
```
```yaml
  storage:
    pvc:
      claim: image-registry-storage
```

## Complete and verify cluster installation:
1- Login to your cluster:
```shell
oc login https://api.cp-dev.tbc.sa:6443 --insecure-skip-tls-verify=true -u ocpadmin
```
2- Ensure all the nodes are in ready state:
```shell
[CLI]# oc get nodes
NAME                     STATUS   ROLES    AGE   VERSION
master01.cp-dev.tbc.sa   Ready    master   25h   v1.14.6+8fc50dea9
master02.cp-dev.tbc.sa   Ready    master   25h   v1.14.6+8fc50dea9
master03.cp-dev.tbc.sa   Ready    master   25h   v1.14.6+8fc50dea9
worker01.cp-dev.tbc.sa   Ready    worker   25h   v1.14.6+8fc50dea9
worker02.cp-dev.tbc.sa   Ready    worker   25h   v1.14.6+8fc50dea9
worker03.cp-dev.tbc.sa   Ready    worker   25h   v1.14.6+8fc50dea9
worker04.cp-dev.tbc.sa   Ready    worker   25h   v1.14.6+8fc50dea9
worker05.cp-dev.tbc.sa   Ready    worker   25h   v1.14.6+8fc50dea9
worker06.cp-dev.tbc.sa   Ready    worker   25h   v1.14.6+8fc50dea9
```
3- Ensure all the cluster operaters are in ready state:
```shell
[root@installer ~]# oc get clusteroperators
NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
authentication                             4.2.23    True        False         False      2d8h
cloud-credential                           4.2.23    True        False         False      2d8h
cluster-autoscaler                         4.2.23    True        False         False      2d8h
console                                    4.2.23    True        False         False      43h
dns                                        4.2.23    True        True          False      43h
image-registry                             4.2.23    True        False         False      26h
ingress                                    4.2.23    True        False         False      43h
insights                                   4.2.23    True        False         False      2d8h
kube-apiserver                             4.2.23    True        False         False      2d8h
kube-controller-manager                    4.2.23    True        False         False      2d8h
kube-scheduler                             4.2.23    True        False         False      2d8h
machine-api                                4.2.23    True        False         False      2d8h
machine-config                             4.2.23    True        False         False      16m
marketplace                                4.2.23    True        False         False      2d8h
monitoring                                 4.2.23    True        False         False      33s
network                                    4.2.23    True        True          False      2d8h
node-tuning                                4.2.23    True        False         False      43h
openshift-apiserver                        4.2.23    True        False         False      43h
openshift-controller-manager               4.2.23    True        False         False      43h
openshift-samples                          4.2.23    True        False         False      2d8h
operator-lifecycle-manager                 4.2.23    True        False         False      2d8h
operator-lifecycle-manager-catalog         4.2.23    True        False         False      2d8h
operator-lifecycle-manager-packageserver   4.2.23    True        False         False      37h
service-ca                                 4.2.23    True        False         False      2d8h
service-catalog-apiserver                  4.2.23    True        False         False      2d8h
service-catalog-controller-manager         4.2.23    True        False         False      2d8h
storage                                    4.2.23    True        False         False      2d8h
```
4- Complete the cluster installation:
```shell
[CLI]# openshift-install --dir /workspace/cp-dev wait-for install-complete --log-level debug
DEBUG OpenShift Installer v4.2.23                  
DEBUG Built from commit 8465c322cdd805ed5e43c3fc52a485ca63d305c7 
INFO Waiting up to 30m0s for the cluster at https://api.cp-dev.tbc.sa:6443 to initialize... 
DEBUG Still waiting for the cluster to initialize: Working towards 4.2.23: 100% complete 
DEBUG Cluster is initialized                       
INFO Waiting up to 10m0s for the openshift-console route to be created... 
DEBUG Route found in openshift-console namespace: console 
DEBUG Route found in openshift-console namespace: downloads 
DEBUG OpenShift console route is created           
INFO Install complete!                            
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/workspace/cp-dev/auth/kubeconfig' 
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.cp-dev.tbc.sa 
INFO Login to the console with user: kubeadmin, password: gCVV4-oyWnh-hFmTB-TuSay  
```
## References:
* [Red Hat Openshift documentation](https://docs.openshift.com/container-platform/4.2/installing/installing_vsphere/installing-restricted-networks-vsphere.html)
* [Red Hat Download](https://access.redhat.com/downloads)
* [Openshift Port requirements](https://docs.openshift.com/container-platform/4.2/installing/installing_bare_metal/installing-bare-metal.html#installation-network-user-infra_installing-bare-metal)
