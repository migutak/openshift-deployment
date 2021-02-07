# Configure NAT on Firewalld to allow internet access on VMs with private IPs (on IBM Cloud)
The Purpose of this configuration is to avail internet access on VMs provisioned on vSphere/IBM cloud without assigning public IPs to them. This makes your openshift deployment more secured and less exposed.

## Architecture
One RHEL 8.1 VM (router.cp.ibm.local) with one public interface (ens192 (169.60.247.101)) and one private interface (ens224 (10.171.57.98)) will be used as a virtual router.
<br>
|Internal interface ens224 (10.171.57.98)| => |Router VM| => |External interface ens192 (169.60.247.101)| => |Internet|

## Configuration
1. Create a new RHEL 8.1 VM with two network interfaces:
* public ens192/169.60.247.101 => default gateway
* private ens224/10.171.57.98
2. Enable routing on RHEL:
```
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
```
3. Ensure firewalld is up and enabled:
```
systemctl enable firewalld --now
```
4. Assign each interface to a different zone:
```
nmcli c mod ens224 connection.zone internal
nmcli c mod ens192 connection.zone external
firewall-cmd --get-active-zone 
```
5. enable masquerade on the internal zone
```
firewall-cmd --zone=internal --add-masquerade --permanent
firewall-cmd --zone=external --add-masquerade --permanent
firewall-cmd --reload
firewall-cmd --zone=internal --query-masquerade
firewall-cmd --zone=external --query-masquerade
```
6. Add rules to allow DNS communication:
```
firewall-cmd --zone=internal --add-port=53/tcp --permanent
firewall-cmd --zone=internal --add-port=53/udp --permanent
firewall-cmd --reload
```