# Installing Rook/Ceph 1.4.7 on Openshift 4.6 in airgapped environment
It is recommended to use dedicated compute nodes to host rook/ceph components, these nodes needs to be tainted so that they don't run any other work loads. Each storage node needs to have one or more dedicated raw disks. In the below example, we will be using the follow nodes/disks:
* svcesbstor01.ruh.911.gov.sa - /dev/sdb
* svcesbstor02.ruh.911.gov.sa - /dev/sdb
* svcesbstor03.ruh.911.gov.sa - /dev/sdb
## Clone rook/ceph github repo 
Please use a release branch instead of the master branch, below is using v1.3.2:
```shell
git clone --branch v1.4.7 https://github.com/rook/rook
```
## Ensure your mirror registry supports v1 schema 
You can start your mirror registry using "-e REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true" to ensure compatibility with v1:
```
 podman run --name mirror-registry -p 5000:5000 -v /workspace/registry/data:/var/lib/registry:z -v /workspace/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /workspace/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key -e REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true -d docker.io/library/registry:2
 ```

## Mirror the required images to your mirror registry
```
{
skopeo copy docker://docker.io/rook/ceph:v1.4.7 docker://svcesbregistry.ruh.911.gov.sa:5000/rook/ceph:v1.4.7
skopeo copy docker://docker.io/ceph/ceph:v15.2.4 docker://svcesbregistry.ruh.911.gov.sa:5000/ceph/ceph:v15.2.4
skopeo copy docker://quay.io/cephcsi/cephcsi:v3.1.1 docker://svcesbregistry.ruh.911.gov.sa:5000/cephcsi/cephcsi:v3.1.1
skopeo copy docker://quay.io/k8scsi/csi-node-driver-registrar:v1.2.0 docker://svcesbregistry.ruh.911.gov.sa:5000/k8scsi/csi-node-driver-registrar:v1.2.0
skopeo copy docker://quay.io/k8scsi/csi-provisioner:v1.6.0 docker://svcesbregistry.ruh.911.gov.sa:5000/k8scsi/csi-provisioner:v1.6.0
skopeo copy docker://quay.io/k8scsi/csi-snapshotter:v2.1.1 docker://svcesbregistry.ruh.911.gov.sa:5000/k8scsi/csi-snapshotter:v2.1.1
skopeo copy docker://quay.io/k8scsi/csi-attacher:v2.1.0 docker://svcesbregistry.ruh.911.gov.sa:5000/k8scsi/csi-attacher:v2.1.0
skopeo copy docker://quay.io/k8scsi/csi-resizer:v0.4.0 docker://svcesbregistry.ruh.911.gov.sa:5000/k8scsi/csi-resizer:v0.4.0
}
```
## Installing Rook/Ceph
1. (Optional) In case you want to use dedicated nodes for storage, you can taint and label your storage compute nodes as shown below:
```shell
{
oc adm taint nodes svcesbstor01.ruh.911.gov.sa storage-node=yes:NoSchedule
oc adm taint nodes svcesbstor02.ruh.911.gov.sa storage-node=yes:NoSchedule
oc adm taint nodes svcesbstor03.ruh.911.gov.sa storage-node=yes:NoSchedule
oc label nodes svcesbstor01.ruh.911.gov.sa storage-node=yes
oc label nodes svcesbstor02.ruh.911.gov.sa storage-node=yes
oc label nodes svcesbstor03.ruh.911.gov.sa storage-node=yes
}
```
2. Copy the required configuration files from the cloned rook/ceph github repo in a working directory:
```shell
{
mkdir /workspace/rook-install/rook-ceph
cd /workspace/rook-install/rook-ceph
cp /workspace/rook-install/rook/cluster/examples/kubernetes/ceph/common.yaml ./
cp /workspace/rook-install/rook/cluster/examples/kubernetes/ceph/cluster.yaml ./
cp /workspace/rook-install/rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml ./
cp /workspace/rook-install/rook/cluster/examples/kubernetes/ceph/csi/rbd/storageclass.yaml ./
cp /workspace/rook-install/rook/cluster/examples/kubernetes/ceph/csi/cephfs/storageclass.yaml ./storageclass-fs.yaml
cp /workspace/rook-install/rook/cluster/examples/kubernetes/ceph/filesystem.yaml ./
cp /workspace/rook-install/rook/cluster/examples/kubernetes/ceph/toolbox.yaml ./
}
```
3. Update resources definition yaml files to use your mirror registry "svcesbregistry.ruh.911.gov.sa:5000" as per the following:
```
cluster.yaml:    image: svcesbregistry.ruh.911.gov.sa:5000/ceph/ceph:v15.2.4
operator-openshift.yaml:  ROOK_CSI_CEPH_IMAGE: "svcesbregistry.ruh.911.gov.sa:5000/cephcsi/cephcsi:v3.1.1"
operator-openshift.yaml:  ROOK_CSI_REGISTRAR_IMAGE: "svcesbregistry.ruh.911.gov.sa:5000/k8scsi/csi-node-driver-registrar:v1.2.0"
operator-openshift.yaml:  ROOK_CSI_RESIZER_IMAGE: "svcesbregistry.ruh.911.gov.sa:5000/k8scsi/csi-resizer:v0.4.0"
operator-openshift.yaml:  ROOK_CSI_PROVISIONER_IMAGE: "svcesbregistry.ruh.911.gov.sa:5000/k8scsi/csi-provisioner:v1.6.0"
operator-openshift.yaml:  ROOK_CSI_SNAPSHOTTER_IMAGE: "svcesbregistry.ruh.911.gov.sa:5000/k8scsi/csi-snapshotter:v2.1.1"
operator-openshift.yaml:  ROOK_CSI_ATTACHER_IMAGE: "svcesbregistry.ruh.911.gov.sa:5000/k8scsi/csi-attacher:v2.1.0"
operator-openshift.yaml:        image: svcesbregistry.ruh.911.gov.sa:5000/rook/ceph:v1.4.7
test-app.yaml:      - image: svcesbregistry.ruh.911.gov.sa:5000/bitnami/nginx
toolbox.yaml:        image: svcesbregistry.ruh.911.gov.sa:5000/rook/ceph:v1.4.7
```
4. Set the following configuration in cluster.yaml file:
* Tolerate the configured storage taint:
```yaml
  placement:
    all:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: storage-node
              operator: In
              values:
              - "yes"
      podAffinity:
      podAntiAffinity:
      tolerations:
      - key: storage-node
        operator: Exists
```
* Configure ceph cluster to use specific nodes/disks:
```yaml
  storage: # cluster level storage configuration and selection
    useAllNodes: false
    useAllDevices: false
```
* Set the nodes/disks that need to be used by the ceph cluster. We have assigned the storage nodes an extra 500GB raw disk to be used by ceph (/dev/sdb). Make sure to follow correct indentation otherwise the cluster will not be provisioned with no indecative error. "nodes:" section is under the "storage:" section so you need to indent it by 4 spaces.
```yaml
    nodes:
    - name: "svcesbstor01.ruh.911.gov.sa"
      devices: # specific devices to use for storage can be specified for each node
      - name: "sdb"
    - name: "svcesbstor02.ruh.911.gov.sa"
      devices: # specific devices to use for storage can be specified for each node
      - name: "sdb"
    - name: "svcesbstor03.ruh.911.gov.sa"
      devices: # specific devices to use for storage can be specified for each node
      - name: "sdb"
```
* Leave the rest as default.
5. configure rook/ceph prereqs and install operator, this will create "rook-ceph" project:
```shell
{
oc create -f common.yaml
oc create -f operator-openshift.yaml
}
```
Wait till the operator and discovery pods are in running and ready state before proceeding with the next steps. Shell you face any issue, review the operator pod logs to better understand the issue.<br>
6. Create the rook/ceph cluster:
```shell
oc create -f cluster.yaml
```
Wait till the mon and osd pods are in running and ready state before proceeding with the next steps. Shell you face any issue, review the operator pod logs to better understand the issue.<br>
7. Create cephfs filesystem:
```shell
oc create -f filesystem.yaml 
```
Wait till the mds pods are in running and ready state before proceeding with the next steps.<br>
8. Create the 2 storage classess, one for the ceph RBD (block storage) and the other for cephfs:
```shell
{
oc create -f storageclass.yaml
oc create -f storageclass-fs.yaml
}
```
9. Create the toolbox deployment that can be used to ensure the ceph cluster health and perform troubleshooting (optional):
```shell
oc create -f toolbox.yaml 
``` 
## Verify the deployment of the rook/ceph cluster
* Ensure that the pods in rook-ceph project are up and running as shown below:
```shell
oc get po -n rook-ceph
NAME                                                              READY   STATUS      RESTARTS   AGE
csi-cephfsplugin-47dxj                                            3/3     Running     0          13d
csi-cephfsplugin-4wdqv                                            3/3     Running     0          13d
csi-cephfsplugin-8crx6                                            3/3     Running     0          13d
csi-cephfsplugin-9wgsz                                            3/3     Running     0          13d
csi-cephfsplugin-m256q                                            3/3     Running     0          13d
csi-cephfsplugin-provisioner-8566845b54-jxbgz                     6/6     Running     0          11d
csi-cephfsplugin-provisioner-8566845b54-r4dgc                     6/6     Running     0          11d
csi-cephfsplugin-rvk4w                                            3/3     Running     0          13d
csi-cephfsplugin-xmn7f                                            3/3     Running     0          13d
csi-cephfsplugin-zwjrg                                            3/3     Running     0          13d
csi-rbdplugin-b4nsc                                               3/3     Running     0          13d
csi-rbdplugin-cmzdp                                               3/3     Running     0          13d
csi-rbdplugin-dhp9s                                               3/3     Running     0          13d
csi-rbdplugin-gr2z6                                               3/3     Running     0          13d
csi-rbdplugin-lv8wv                                               3/3     Running     0          13d
csi-rbdplugin-n7qj2                                               3/3     Running     0          13d
csi-rbdplugin-provisioner-858c556566-jbhk2                        6/6     Running     0          11d
csi-rbdplugin-provisioner-858c556566-k6g4f                        6/6     Running     0          4d15h
csi-rbdplugin-rg58l                                               3/3     Running     0          13d
csi-rbdplugin-vmq26                                               3/3     Running     0          13d
rook-ceph-crashcollector-svcesbbwrk04.ruh.911.gov.sa-5cc8b9vhf7   1/1     Running     0          4d10h
rook-ceph-crashcollector-svcesbbwrk05.ruh.911.gov.sa-554dd9tkm2   1/1     Running     0          11d
rook-ceph-crashcollector-svcesbbwrk06.ruh.911.gov.sa-bfcfbsk2jp   1/1     Running     0          4d15h
rook-ceph-crashcollector-svcesbbwrk07.ruh.911.gov.sa-86768xm85x   1/1     Running     0          4d14h
rook-ceph-crashcollector-svcesbstor01.ruh.911.gov.sa-7f9644db7z   1/1     Running     0          11d
rook-ceph-crashcollector-svcesbstor02.ruh.911.gov.sa-76454ws5jm   1/1     Running     0          11d
rook-ceph-crashcollector-svcesbstor03.ruh.911.gov.sa-78d57nmp7d   1/1     Running     0          11d
rook-ceph-mds-myfs-a-6f9cffbb8-xpt5f                              1/1     Running     1          4d15h
rook-ceph-mds-myfs-b-f6564f4-6jrpw                                1/1     Running     1          11d
rook-ceph-mgr-a-5bb445469f-6x2ld                                  1/1     Running     1          11d
rook-ceph-mon-b-698546c6f-r7xxh                                   1/1     Running     0          11d
rook-ceph-mon-c-858b97b567-zg2n9                                  1/1     Running     0          11d
rook-ceph-mon-d-545ff5c698-gxw69                                  1/1     Running     0          3d17h
rook-ceph-operator-8477ddb86b-2t6j5                               1/1     Running     0          4d15h
rook-ceph-osd-0-5d8458b8f-rjn4c                                   1/1     Running     0          11d
rook-ceph-osd-1-7b44fbc877-c62bw                                  1/1     Running     0          11d
rook-ceph-osd-2-78bf4d5b8b-ldz9z                                  1/1     Running     0          11d
rook-ceph-osd-prepare-svcesbstor01.ruh.911.gov.sa-c4vcq           0/1     Completed   0          9h
rook-ceph-osd-prepare-svcesbstor02.ruh.911.gov.sa-2l79w           0/1     Completed   0          9h
rook-ceph-osd-prepare-svcesbstor03.ruh.911.gov.sa-n7km8           0/1     Completed   0          9h
rook-ceph-tools-9cf9b4bfd-p4thc                                   1/1     Running     0          11d
rook-discover-6crhg                                               1/1     Running     0          13d
rook-discover-8rxc8                                               1/1     Running     0          13d
rook-discover-ffx7f                                               1/1     Running     0          13d
rook-discover-k4mgn                                               1/1     Running     0          13d
rook-discover-tt9vz                                               1/1     Running     0          13d
rook-discover-x7mdh                                               1/1     Running     0          13d
rook-discover-xwp6v                                               1/1     Running     0          13d
rook-discover-zshxn                                               1/1     Running     0          13d
```
* Ensure storage class are created:
```shell
oc get sc
NAME              PROVISIONER                     AGE
rook-ceph-block   rook-ceph.rbd.csi.ceph.com      19m
rook-cephfs       rook-ceph.cephfs.csi.ceph.com   17m
sukrusc           kubernetes.io/vsphere-volume    4d16h
thin (default)    kubernetes.io/vsphere-volume    12d
```
## Verify the health of the ceph cluster
1. Check the ceph cluster health status using the toolbox pod:
```shell
oc exec -it rook-ceph-tools-7f96779fb9-wrt6w bash
bash-4.2$ ceph -s
  cluster:
    id:     c90f1d50-8ce5-453c-a4a5-48044031c2e7
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum a,b,c (age 28m)
    mgr: a(active, since 28m)
    osd: 3 osds: 3 up (since 27m), 3 in (since 27m)
 
  data:
    pools:   1 pools, 8 pgs
    objects: 0 objects, 0 B
    usage:   3.0 GiB used, 1.5 TiB / 1.5 TiB avail
    pgs:     8 active+clean
```
2. Check the OSD information
```shell
bash-4.2$ ceph osd status
+----+-------------------------+-------+-------+--------+---------+--------+---------+-----------+
| id |           host          |  used | avail | wr ops | wr data | rd ops | rd data |   state   |
+----+-------------------------+-------+-------+--------+---------+--------+---------+-----------+
| 0  | storage3.ocp4.ibm.local | 1025M |  497G |    0   |     0   |    0   |     0   | exists,up |
| 1  | storage1.ocp4.ibm.local | 1025M |  497G |    0   |     0   |    0   |     0   | exists,up |
| 2  | storage2.ocp4.ibm.local | 1025M |  497G |    0   |     0   |    0   |     0   | exists,up |
+----+-------------------------+-------+-------+--------+---------+--------+---------+-----------+
```
3. Check the cluster capacity utilization:
```shell
bash-4.2$ ceph df
RAW STORAGE:
    CLASS     SIZE        AVAIL       USED        RAW USED     %RAW USED 
    hdd       1.5 TiB     1.5 TiB     5.1 MiB      3.0 GiB          0.20 
    TOTAL     1.5 TiB     1.5 TiB     5.1 MiB      3.0 GiB          0.20 
 
POOLS:
    POOL            ID     STORED     OBJECTS     USED     %USED     MAX AVAIL 
    replicapool      1        0 B           0      0 B         0       473 GiB 
```
## Ensure successfull creation of PV using the created ceph storage classes
1. Provision RWO volume using Ceph RBD (rook-ceph-block)
```shell
cat << EOF > rwo-pvc.yaml 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rwo-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: rook-ceph-block
EOF
```
```shell
oc create -f rwo-pvc.yaml 
persistentvolumeclaim/rwo-pvc created
```
Ensure the a pvc & a pv has been created and bounded:
```shell
oc get pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
rwo-pvc   Bound    pvc-75aec8fd-6230-419d-97a8-9c7fe31e4390   1Gi        RWO            rook-ceph-block   5s
``` 
Delete the created pvc:
```shell
oc delete -f rwo-pvc.yaml
```
2. Provision RWX volume using Cephfs (rook-cephfs)
```shell
cat << EOF > rwx-pvc.yaml 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rwx-pvc
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: rook-cephfs
EOF
```
```shell
oc create -f rwx-pvc.yaml 
persistentvolumeclaim/rwx-pvc created
```
Ensure the a pvc & a pv has been created and bounded:
```shell
oc get pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
rwx-pvc   Bound    pvc-688d66b3-707c-4e22-a968-d773211ed6d6   1Gi        RWX            rook-cephfs    5s
```
Create a test app deployment that mount the created pv:
```shell
skopeo copy docker://quay.io/bitnami/nginx docker://svcesbregistry.ruh.911.gov.sa:5000/bitnami/nginx
cat << EOF > test-app.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: fe-app
  name: fe-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: fe-app
  template:
    metadata:
      labels:
        app: fe-app
    spec:
      containers:
      - image: svcesbregistry.ruh.911.gov.sa:5000/bitnami/nginx
        name: fe-app
        ports:
          - containerPort: 80
            name: "http-server"
        volumeMounts:
          - mountPath: "/var/www/html"
            name: "fe-app-pv"
      volumes:
      - name: "fe-app-pv"
        persistentVolumeClaim:
          claimName: "rwx-pvc"
EOF
oc create -f test-app.yaml
```
Check the created pods:
```shell
oc get pods 
NAME                      READY   STATUS    RESTARTS   AGE
fe-app-58fc487956-f2vhd   1/1     Running   0          62s
fe-app-58fc487956-glmxh   1/1     Running   0          62s
fe-app-58fc487956-jfshf   1/1     Running   0          62s
```
Delete the created app deployment and pvc:
```shell
oc delete -f test-app.yaml
oc delete -f rwx-pvc.yaml
```
## Tear down
If at any point you faced an issue and want to start from scratch, you can tear down the cluster as the per the following:
```shell
{
oc delete storageclass rook-ceph-block
oc delete storageclass csi-cephfs
oc delete -f filesystem.yaml
oc delete -f toolbox.yaml
oc delete -n rook-ceph cephblockpool replicapool
oc delete -n rook-ceph cephcluster rook-ceph
oc delete -f cluster.yaml 
oc delete -f operator-openshift.yaml 
oc delete -f common.yaml 
oc adm taint nodes --all storage-node-
oc label nodes  --all storage-node-
oc get nodes|grep -v NAME|awk '{print $1}'|xargs -I arg ssh -i /workspace/cp/sshkey core@arg "sudo ls -lh /var/lib/rook"
}
```
Wipe the storage raw disks (warning: ensure you are using the correct device name maching your environment):
```shell
ssh -i /workspace/ocp4-project/sshkey core@storage1.ocp4.ibm.local "sudo wipefs -a /dev/sdb"
ssh -i /workspace/ocp4-project/sshkey core@storage2.ocp4.ibm.local "sudo wipefs -a /dev/sdb"
ssh -i /workspace/ocp4-project/sshkey core@storage3.ocp4.ibm.local "sudo wipefs -a /dev/sdb"
```
## References
* [Rook Documentation - Openshift prereqs](https://rook.io/docs/rook/v1.2/ceph-openshift.html)
* [Rook Documentation - RBD Block storage configuration](https://rook.io/docs/rook/v1.2/ceph-block.html)
* [Rook Documentation - cephfs configuration](https://rook.io/docs/rook/v1.2/ceph-filesystem.html)