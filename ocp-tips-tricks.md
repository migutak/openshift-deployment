# Openshift tips and Tricks
### Get list of pods that are not ready:
```
kubectl get pods -owide --all-namespaces|grep -v "Completed"|awk -F'[ /]+' '{if($3 != $4){print $0}}'
```
### Get pods sorted by number of restarts
```
kubectl get pods -owide --all-namespaces|grep -v "Completed"|grep -v RESTARTS|awk -F'[ /]+' '{if($6 > 0){print $0}}'|sort -n -k 5 -r
```
### List all resources including rsources associated with CRDs:
```
kubectl api-resources --verbs=list --namespaced -o name |xargs -n 1 kubectl get --show-kind --ignore-not-found -n ecorp
```
### Trust OCP registry by podman:
```
mkdir /etc/containers/certs.d/default-route-openshift-image-registry.apps.cp-dev.alrajhi.bank
openssl s_client -connect default-route-openshift-image-registry.apps.cp-dev.alrajhi.bank:443 -showcerts </dev/null 2>/dev/null |openssl x509 -outform PEM|tee /etc/containers/certs.d/default-route-openshift-image-registry.apps.cp-dev.alrajhi.bank/registry.crt
podman login default-route-openshift-image-registry.apps.cp-dev.alrajhi.bank -u ocpadmin -p $(oc whoami -t)
```
### Access a container namespace to excute troubleshoting commands like netstat or fix files/directory permissions
```
# Get the nodename and container ID of the required pod:
oc get po ecorp-1-p6n7k -o yaml|egrep "containerID|nodeName"
  nodeName: worker4.cp.ibm.local
  - containerID: cri-o://d6ef72000f6b39bcd4142dca609c60e061ba51a7ad077ab70a9da75d38114bfe

# ssh to the node
ssh core@worker4.cp.ibm.local

# get the process id of the container:
crictl inspect d6ef72000f6b39bcd4142dca609c60e061ba51a7ad077ab70a9da75d38114bfe|grep pid
  "pid": 3048558,

# enter the container namespace and execute netstat inside it to get listening ports
nsenter -t 3048558 -a netstat -anlp

# You can also access the container namespace cli (as if you logged in to the container as root) which allows you to fix filesystem permissions in some cases (use with caution):
nsenter -t 3048558 -a
[root@ecorp-1-p6n7k /]# df -hT
Filesystem                           Type     Size  Used Avail Use% Mounted on
overlay                              overlay  120G   30G   91G  25% /
tmpfs                                tmpfs     64M     0   64M   0% /dev
tmpfs                                tmpfs     16G     0   16G   0% /sys/fs/cgroup
shm                                  tmpfs     64M     0   64M   0% /dev/shm
tmpfs                                tmpfs     16G  7.7M   16G   1% /etc/hostname
/dev/mapper/coreos-luks-root-nocrypt xfs      120G   30G   91G  25% /etc/hosts
tmpfs                                tmpfs     16G   24K   16G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                                tmpfs     16G     0   16G   0% /proc/acpi
tmpfs                                tmpfs     16G     0   16G   0% /proc/scsi
tmpfs                                tmpfs     16G     0   16G   0% /sys/firmware
```
References: 
* https://access.redhat.com/solutions/4539631
* https://stackoverflow.com/questions/40350456/docker-any-way-to-list-open-sockets-inside-a-running-docker-container

## Trust self-signed certificates by openshift nodes:
* References: https://access.redhat.com/solutions/4796701
Example of configuration script:
```
cat mc.sh 
#!/usr/bin/bash
cat<<EOF>ca-trust-master.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: ca-trust-master
  labels:
    machineconfiguration.openshift.io/role: master
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,$(cat /root/registry-ca.crt | base64 -w 0)
        filesystem: root
        mode: 0644
        path: /etc/pki/ca-trust/source/anchors/registry-ca.crt
EOF
cat<<EOF>ca-trust-worker.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: ca-trust-worker
  labels:
    machineconfiguration.openshift.io/role: worker
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,$(cat /root/registry-ca.crt | base64 -w 0)
        filesystem: root
        mode: 0644
        path: /etc/pki/ca-trust/source/anchors/registry-ca.crt
EOF
```
## Identify nodes with ungraceful shutdown:

```
# OCP
for i in $( oc get no|awk '{print $1}'|grep -v NAME); do echo $i;ssh -i /vendor/ocpcluster1/sshkey -t core@$i "sudo ausearch -i -m system_boot,system_shutdown | tail -4";done

#ICP
for i in $( kubectl get no|awk '{print $1}'|grep -v NAME); do echo $i;ssh -t $i "sudo ausearch -i -m system_boot,system_shutdown | tail -4";done
```