# Installing Cloud Pak for Applications V4.1
1. Get IBM key to access IBM image registry through [this link](https://myibm.ibm.com/products-services/containerlibrary)
2. If you are installing from RHEL 8.1, you need to [install docker](https://www.linuxtechi.com/install-docker-ce-centos-8-rhel-8/) instead of podman:
```shell
yum remove podman
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf list docker-ce
dnf install docker-ce --nobest -y
systemctl enable --now docker
```
3. (Only if you have firewalld enabled) Add the docker0 network interface to firewalld internal zone:
```
nmcli c mod docker0 connection.zone internal
```
4. Set the following environment variables:
```
{
export ENTITLED_REGISTRY=cp.icr.io
export ENTITLED_REGISTRY_USER=cp
export ENTITLED_REGISTRY_KEY=eyJhbGcixxxx
}
```
5. Log into IBM image registry:
```
docker login "$ENTITLED_REGISTRY" -u "$ENTITLED_REGISTRY_USER" -p "$ENTITLED_REGISTRY_KEY"
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```
6. Extract the installation files: 
```
mkdir -p /workspace/cp4app/
cd /workspace/cp4app/
docker run -v $PWD/data:/data:z -u 0 -e LICENSE=accept "$ENTITLED_REGISTRY/cp/icpa/icpa-installer:4.1.0" cp -r "data/*" /data
```
7. (Optional) Update the config.yaml file with your github enterprise information as per the following:
```
cd data
vi config.yaml
....
  github:
    url: "https://github.ibm.com"
    organization: "code-zone"
    teams: ["core-squad"]
    token: "00b...."
....
```
8. Update transformation advisor configuration with the storage class to be used:
```
vi transadv.yaml
...
storageClassName: "rook-cephfs"
...
```
9. Run Cloud Pak for application prerequisites validation:
```
cd ..
docker run -v ~/.kube:/root/.kube:z -u 0 -t -v $PWD/data:/installer/data:z -e LICENSE=accept -e ENTITLED_REGISTRY -e ENTITLED_REGISTRY_USER -e ENTITLED_REGISTRY_KEY "$ENTITLED_REGISTRY/cp/icpa/icpa-installer:4.1.0" check
```
10. Start Cloud pak for application installation using the following:
```
docker run -v ~/.kube:/root/.kube:z -u 0 -t -v $PWD/data:/installer/data:z -e LICENSE=accept -e ENTITLED_REGISTRY -e ENTITLED_REGISTRY_USER -e ENTITLED_REGISTRY_KEY "$ENTITLED_REGISTRY/cp/icpa/icpa-installer:4.1.0" install

Mark Installation Complete...
done

Install successful ************************************************************************************************************************************************************************************************

Installation complete.

Please see https://ibm-cp-applications.apps.cp.ibm.local to get started and learn more about IBM Cloud Pak for Applications 4.1.0.

The pipelines dashboard is available at: https://tekton-dashboard-tekton-pipelines.apps.cp.ibm.local

The IBM Transformation Advisor UI is available at: https://ta-apps.apps.cp.ibm.local

The IBM Application Navigator UI is available at: https://kappnav-ui-service-kappnav.apps.cp.ibm.local
```
11. If you will access the Cloud Pak for Appliactions from a workstation without access to the DNS, add the following to your /etc/hosts file:
```
169.60.247.102 console-openshift-console.apps.cp.ibm.local oauth-openshift.apps.cp.ibm.local ibm-cp-applications.apps.cp.ibm.local ta-apps.apps.cp.ibm.local tekton-dashboard-tekton-pipelines.apps.cp.ibm.local kappnav-ui-service-kappnav.apps.cp.ibm.local
```