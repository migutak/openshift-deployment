# Machine Config Troubleshooting
## Check the status of machine pools:
```
[root@installer alrajhi-mvp-01]# oc get mcp
NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT
master   rendered-master-bafd3d6d10123eb64f1aed887b6061f3   True      False      False      3              3                   3                     0
worker   rendered-worker-cafaaf1559939887f7e73bba89558089   True      False      False      6              6                   6                     0
```
## If a node stuck in schedulingDisabled state after appling new machine config
Describe the node to see if the current config is different than the desired config and if so you can reboot the node to ensure all the pending configs are applied. If this issue is reoccuing, check the kubelet logs of the node to get better understanding why the machine config is stuck, most probably there is a running workload that is not reponsive to drain request. 
```
oc describe node worker2.cp.ibm.local|egrep "machineconfiguration.openshift.io/.*Config"
                    machineconfiguration.openshift.io/currentConfig: rendered-worker-cafaaf1559939887f7e73bba89558089
                    machineconfiguration.openshift.io/desiredConfig: rendered-worker-13121cbbafedde13131342d1313a1212
```
Example of pods that are not responsive to drain:
```
error when evicting pod "r307b84ffe1-analytics-mtls-gw-f94cf9977-wtk6d" (will retry after 5s): Cannot evict pod as it would violate the pod's disruption budget.
```
To know why a certain node is stuck in machine-config process, you can try to manually drain the node and see is your are getting an error
```
oc get no
NAME                                    STATUS                     ROLES                  AGE   VERSION
cloud-infra1.ocpcluster.secsmoc.local   Ready                      worker                 35d   v1.16.2+d6d3cff
cloud-infra2.ocpcluster.secsmoc.local   Ready                      worker                 35d   v1.16.2+d6d3cff
cloud-infra3.ocpcluster.secsmoc.local   Ready                      worker                 35d   v1.16.2+d6d3cff
cloud-mast1.ocpcluster.secsmoc.local    Ready                      master                 35d   v1.16.2+d6d3cff
cloud-mast2.ocpcluster.secsmoc.local    Ready                      master                 35d   v1.16.2+d6d3cff
cloud-mast3.ocpcluster.secsmoc.local    Ready                      master                 35d   v1.16.2+d6d3cff
cloud-ocs1.ocpcluster.secsmoc.local     Ready                      worker                 35d   v1.16.2+d6d3cff
cloud-ocs2.ocpcluster.secsmoc.local     Ready                      worker                 35d   v1.16.2+d6d3cff
cloud-ocs3.ocpcluster.secsmoc.local     Ready,SchedulingDisabled   worker                 35d   v1.16.2+d6d3cff
cloud-work1.ocpcluster.secsmoc.local    Ready                      cp-master,worker       35d   v1.16.2+d6d3cff
cloud-work10.ocpcluster.secsmoc.local   Ready                      worker                 35d   v1.16.2+d6d3cff
cloud-work11.ocpcluster.secsmoc.local   Ready                      worker                 35d   v1.16.2+d6d3cff
cloud-work12.ocpcluster.secsmoc.local   Ready                      worker                 35d   v1.16.2+d6d3cff
cloud-work13.ocpcluster.secsmoc.local   Ready                      worker                 35d   v1.16.2+d6d3cff
cloud-work2.ocpcluster.secsmoc.local    Ready                      cp-master,worker       35d   v1.16.2+d6d3cff
cloud-work3.ocpcluster.secsmoc.local    Ready                      cp-master,worker       35d   v1.16.2+d6d3cff
cloud-work4.ocpcluster.secsmoc.local    Ready                      cp-proxy,worker        35d   v1.16.2+d6d3cff
cloud-work5.ocpcluster.secsmoc.local    Ready                      cp-proxy,worker        35d   v1.16.2+d6d3cff
cloud-work6.ocpcluster.secsmoc.local    Ready                      worker                 35d   v1.16.2+d6d3cff
cloud-work7.ocpcluster.secsmoc.local    Ready                      cp-management,worker   35d   v1.16.2+d6d3cff
cloud-work8.ocpcluster.secsmoc.local    Ready                      cp-management,worker   35d   v1.16.2+d6d3cff
cloud-work9.ocpcluster.secsmoc.local    Ready                      cp-management,worker   35d   v1.16.2+d6d3cff

[root@cloud-inst ~]# oc adm drain cloud-ocs3.ocpcluster.secsmoc.local --ignore-daemonsets --delete-local-data
node/cloud-ocs3.ocpcluster.secsmoc.local already cordoned
WARNING: ignoring DaemonSet-managed Pods: kube-system/logging-elk-filebeat-ds-zchxd, kube-system/metering-reader-ggd26, kube-system/monitoring-prometheus-nodeexporter-p58zn, local-storage/local-block-local-diskmaker-dcqjk, local-storage/local-block-local-provisioner-hmswr, openshift-cluster-node-tuning-operator/tuned-kllsg, openshift-dns/dns-default-hrltb, openshift-image-registry/node-ca-7qnxr, openshift-machine-config-operator/machine-config-daemon-2d2hs, openshift-monitoring/node-exporter-qzzjj, openshift-multus/multus-wzv9t, openshift-sdn/ovs-pjxg5, openshift-sdn/sdn-2npl5, openshift-storage/csi-cephfsplugin-xbgf2, openshift-storage/csi-rbdplugin-txhvf
evicting pod "rook-ceph-osd-1-f6b696c8-9krr8"
error when evicting pod "rook-ceph-osd-1-f6b696c8-9krr8" (will retry after 5s): Cannot evict pod as it would violate the pod's disruption budget.
```
Delete the pending pod:
oc delete po rook-ceph-osd-1-f6b696c8-9krr8 -n openshift-storage
## Check if there are any machine-config updates pending on nodes:
```
for i in $(oc get no -o name); do echo $i;oc describe $i|egrep "machineconfiguration.openshift.io/.*Config";done
```
### MachineConfig daemon fails with Marking Degraded due to: unexpected on-disk state validating
If the machine config operator is degraded and you received "MachineConfig daemon fails with Marking Degraded due to: unexpected on-disk state validating , content mismatch for file" in the machine config pod logs, this means that the concerned file has been manually updated on the node. You can force the overwriting of the changed file by ssh to the concerened node and execute the following commands:
```
sudo touch /run/machine-config-daemon-force
```
Reference: https://access.redhat.com/solutions/5099331
### Cannot evict pod with pod disruption budget
Error: I1226 12:52:19.594508    8573 update.go:92] error when evicting pod "r14670bad6f-lur-v2-65cbdd644-mfnk6" (will retry after 5s): Cannot evict pod as it would violate the pod's disruption budget. To resolve this issue, manually delete these pods.
1. use the following command to list the pods that can't be evicted
```
oc logs machine-config-daemon-nwr7z --all-containers |grep "error when evicting pod"|awk -F\" '{print $2}'|sort|uniq
```
2. Manually delete them.    
## References
* Troubleshooting Machine-config Operator: https://access.redhat.com/articles/4550741
