# OCP Upgrade Troubleshooting
## Important before upgrade
1. Take a backup of etcd database and other important cluster configuration:
```
# ssh to one of the master nodes:
ssh -i /workspace/cp/sshkey core@master1.cp.ibm.local

# For OCP 4.4+:
sudo /usr/local/bin/cluster-backup.sh /home/core/assets/backup

# For OCP 4.3:
sudo /usr/local/bin/etcd-snapshot-backup.sh /home/core/assets/backup

# Backup will be saved on the selected master node, copy it to safe location:
[core@master1 ~]$ ls -lh /home/core/assets/backup
total 300M
-rw-------. 1 root root 300M Nov 12 00:07 snapshot_2020-11-12_000756.db
-rw-------. 1 root root  68K Nov 12 00:07 static_kuberesources_2020-11-12_000756.tar.gz
```
More info is provided at https://docs.openshift.com/container-platform/4.4/backup_and_restore/backing-up-etcd.html
<br><br>
2. Take snapshots of all the OCP VMs in case unrecoverable issues are encountered.
<br><br>
3. If you are doiing restricted network upgrade (usiing the CLI), Pleaase don't use --force option unless you are sure you are upgrading using a supported upgrade path as expalined here (https://access.redhat.com/solutions/4606811) otherwise you are risking having your cluster in unrecoverable state.
## Identifing where the upgrade process is stuck
1. Check the status of the cluster operators and describe any cluster operator that is not in available state.
2. Check cluster version operator logs:
```
oc logs cluster-version-operator-7958bc7845-pm9hp -n openshift-cluster-version|grep error
```
3. Navigate to the operator project and display the logs of the operator pod. For example:
```
oc logs kube-storage-version-migrator-operator-5848c5f955-gfj5t -n openshift-kube-storage-version-migrator-operator
```
## Upgrade might be stuck due to using an alpha version of storage snapshot CRDs
If you have upstream rook/ceph installed, you might need to delete the alpha versions of the snapshot CRDs as per the following (check https://access.redhat.com/solutions/5069531):
```
oc delete crd volumesnapshotclasses.snapshot.storage.k8s.io volumesnapshotcontents.snapshot.storage.k8s.io volumesnapshots.snapshot.storage.k8s.io
```
## Upgrade might be stuck due to an SCC error with the kube-storage-version-migrator-operator pod
Upgrade might be stuck due to an SCC error with the kube-storage-version-migrator-operator pod as per the following (check https://access.redhat.com/solutions/5475171):
```
oc describe po kube-storage-version-migrator-operator-5848c5f955-xtqx8 -n openshift-kube-storage-version-migrator-operator 
  Warning  Failed     5m50s (x12 over 7m58s)  kubelet, master2.cp.ibm.local  Error: container has runAsNonRoot and image will run as root
```
The resolution is to delete the pod.
## Failure due to default SCC have been altered
If you are getting error "failed because of "DefaultSecurityContextConstraints_Mutated" in the cluster version operator logs, then most propably you (or an installed application) have made changes in the default SCC. you have two options to proceed:
1. restore the default SCC as explained here https://access.redhat.com/solutions/4972291 (some of your installed apps might be impacted).
2. Run the upgrade with --force flag as explained in the above technote. Dependant on the changes done in SCC you might be facing issues with upgrade process.
## Upgrade might stuck with machine-config operator trying to update RHCOS of some nodes:
when executing "oc get mcp" it will show some nodes in degraded state and when execcuting "oc get nodes" you will see these nodes still using the old Kubernetes version. 
When getting the logs of the machine-config pod running on this node you will see the following error:
```
oc project openshift-machine-config-operator
oc get po -o wide
oc logs machine-config-daemon-fgnzq --all-containers
E1116 08:02:37.981963    2777 writer.go:135] Marking Degraded due to: unexpected on-disk state validating against rendered-master-c394c9563d3d38faa128be4214211ebb
I1116 08:03:37.997923    2777 daemon.go:766] Current config: rendered-master-27789dee3627083013c089b890fb1f8c
I1116 08:03:37.997947    2777 daemon.go:767] Desired config: rendered-master-c394c9563d3d38faa128be4214211ebb
I1116 08:03:38.005673    2777 update.go:1419] Disk currentConfig rendered-master-c394c9563d3d38faa128be4214211ebb overrides node annotation rendered-master-27789dee3627083013c089b890fb1f8c
I1116 08:03:38.008408    2777 daemon.go:1013] Validating against pending config rendered-master-c394c9563d3d38faa128be4214211ebb
E1116 08:03:38.008484    2777 daemon.go:1243] expected target osImageURL quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:1ab07d20e1504b4cc4267ed17b5ec425c677562c7736de22fd8d64996a1c4706
```
To resolve the issue, ssh to the impacted node, sudo -i and execcute the following using the image name (osImageURL) displayed in the above log message to force the installation of the required RHCOS version:
```
echo "quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:1ab07d20e1504b4cc4267ed17b5ec425c677562c7736de22fd8d64996a1c4706" > /etc/pivot/image-pullspec
systemctl start machine-config-daemon-host.service
reboot
```
https://access.redhat.com/solutions/4466631