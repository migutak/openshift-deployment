# Creating Infrastructure Nodes machineset in vSphere IPI installation
## Example yaml definition
```yaml
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  labels:
    machine.openshift.io/cluster-api-cluster: cp-tcprk
  name: cp-tcprk-infra
  namespace: openshift-machine-api
spec:
  replicas: 3
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: cp-tcprk
      machine.openshift.io/cluster-api-machineset: cp-tcprk-infra
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: cp-tcprk
        machine.openshift.io/cluster-api-machine-role: infra
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: cp-tcprk-infra
    spec:
      metadata:
        labels:
          node-role.kubernetes.io/infra: ""
      providerSpec:
        value:
          apiVersion: vsphereprovider.openshift.io/v1beta1
          kind: VSphereMachineProviderSpec
          numCoresPerSocket: 1
          numCPUs: 4
          memoryMiB: 16384
          diskGiB: 120
          credentialsSecret:
            name: vsphere-cloud-credentials
          network:
            devices:
            - networkName: VM Network
          snapshot: ""
          template: cp-tcprk-rhcos
          userDataSecret:
            name: worker-user-data
          workspace:
            datacenter: openshift
            datastore: ocp-iscsi-01
            folder: /openshift/vm/cp-tcprk
            resourcePool: /openshift/host/ocp/Resources
            server: vcenter.ibmlab.local
``` 