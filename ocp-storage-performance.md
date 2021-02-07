#
## Air-Gapped environment
### Build and copy tools image
1. Using you bastion host with internet access, build your tools image:
```
cat << EOF > Dockerfile
FROM fedora:latest
RUN yum update -y && \
    yum install -y --nodocs fio tcpdump bind-utils rsync net-tools wget git && \
    yum clean all -y
EOF
podman build -t ibm-tools:v0.1 ./

skopeo copy containers-storage:localhost/ibm-tools:v0.1 docker://svcesbregistry.ruh.911.gov.sa:5000/ibm-toools:latest
```
3. ssh to the concerned node and start  the tools container:
```
GODEBUG=x509ignoreCN=0 podman run -it --name=mytools -v /root:/root --privileged --rm --env TERM="$TERM" --hostname "$HOSTNAME" svcesbregistry.ruh.911.gov.sa:5000/ibm-tools:latest
``` 