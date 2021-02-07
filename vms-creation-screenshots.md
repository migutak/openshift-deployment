# Openshift VMs creation screen captures
## Create the cluster VMs
1. Download coreos OVA image from redhat download site "https://cloud.redhat.com/openshift/install/vsphere/user-provisioned" and save it:
```shell
cd /workspace/cp
wget "https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/rhcos-4.3.8-x86_64-vmware.x86_64.ova" -O rhcos-4.3.8-x86_64-vmware.x86_64.ova
```
2. From vmware vCenter UI "vcenter.ibmlab.local", Create a new folder as shown below. give it a name that matches the cluster name that you specified in the install-config.yaml file which is "ocp4". Folder name should match the cluster name defined by "metadata.name" property in "install-config.yaml" config file. It will also be part of the cluster FQDN (".<metadata.name>.<baseDomain>") :  
<kbd><img src="./content/i01.png" /></kbd>
<kbd><img src="./content/i02.png" /></kbd>
3. Create a VM template from RHCOS OVA image as per the following:
<kbd><img src="./content/i03.png" /></kbd>
<kbd><img src="./content/i04.png" /></kbd>
<kbd><img src="./content/i05.png" /></kbd>
<kbd><img src="./content/i06.png" /></kbd>
<kbd><img src="./content/i07.png" /></kbd>
<kbd><img src="./content/i08.png" /></kbd>
<kbd><img src="./content/i09.png" /></kbd>
<kbd><img src="./content/i10.png" /></kbd>
<kbd><img src="./content/i11.png" /></kbd>

4. Create a new VM from the created template to host the bootstrap node:
<kbd><img src="./content/i12.png" /></kbd>
<kbd><img src="./content/i13.png" /></kbd>
<kbd><img src="./content/i14.png" /></kbd>
<kbd><img src="./content/i15.png" /></kbd>
<kbd><img src="./content/i16.png" /></kbd>
<kbd><img src="./content/i17.png" /></kbd>
<kbd><img src="./content/i18.png" /></kbd>
<kbd><img src="./content/i19.png" /></kbd>
  
Add the following properties:
* Name: "guestinfo.ignition.config.data"  
  Value: content of file "/workspace/ocp42/append-bootstrap.64"  
* Name: "guestinfo.ignition.config.data.encoding"  
  Value: "base64"
* Name: "disk.EnableUUID"  
  Value: "TRUE"  

<kbd><img src="./content/i20.png" /></kbd>
<kbd><img src="./content/i21.png" /></kbd>  
5. Repeat the same process to create other cluster nodes (master & compute), just make sure you are using the correct amount of CPU/RAM/Disk for each type of nodes and also update the properties with the ignition file suitable for the node type you are creating as per the following:
  #### Master nodes:
  * Name: "guestinfo.ignition.config.data"  
  Value: content of file "/workspace/ocp42/master.64" 
  #### Compute nodes:
  * Name: "guestinfo.ignition.config.data"  
  Value: content of file "/workspace/ocp42/worker.64"
  #### Minimum resources requirements:
  <kbd><img src="./content/requirements.png" /></kbd> 
6. For the storage nodes, they will use the same configuration as worker nodes however you might need to add extra disks to be used for the persistent storage provider that will be used:
<kbd><img src="./content/i27.png" /></kbd>