# Required URLs to be allowed by the client firewall/proxy for Openshift installation
The following URLs (including all their sub-domains or URIs) need to be accessible from all cluster nodes in case of online openshift installation (or from the bastion host in case of restricted network installation):
## Mandatory URLs for OCP & OCS installation:
* registry.redhat.io
* quay.io
* sso.redhat.com
* openshift.org
* cert-api.access.redhat.com
* api.access.redhat.com
* infogw.api.openshift.com
* cloud.redhat.com/api/ingress
* mirror.openshift.com
* storage.googleapis.com/openshift-release
* quay-registry.s3.amazonaws.com
* art-rhcos-ci.s3.amazonaws.com
* cloud.redhat.com/openshift
* registry.access.redhat.com
## IBM Cloud Paks
* cp.icr.io
* docker.io
* github.com
* *.github.com
* download.ceph.com
* *.ibm.com
## Rook/Ceph
* download.ceph.com
## references
* https://docs.openshift.com/container-platform/4.6/installing/install_config/configuring-firewall.html
