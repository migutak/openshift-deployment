# TLS Certificates Management Tips
### Export X509 certificate from a keystore:
```
keytool -exportcert -keystore truststore.jks  -alias apicdev -file apic01.cer -rfc
```
### List the content of a key store
```
keytool -v -list -keystore truststore.jks
```
### Export root certificate from URL:
The last certificate in the list returned by the following command will be the root certificate:
```
openssl s_client -connect icp-cluster.qiwa.info:8443 -verify 5 -showcerts </dev/null 2>/dev/null|sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p'
```
### Export certificate from a certain URL:
```
openssl s_client -connect dev.apicapi-gateway.10.85.234.203.nip.io:443 -showcerts </dev/null 2>/dev/null | openssl x509 -outform PEM | tee ./icp_ingress.crt
```
### Export certificate from a certain URL with servername option (to set the certificate subject):
```
openssl s_client -servername dev.apicapi-gateway.10.85.234.203.nip.io -connect dev.apicapi-gateway.10.85.234.203.nip.io:443 -showcerts </dev/null 2>/dev/null | openssl x509 -outform PEM | tee ./icp_ingress.crt
SRV-AD3
ldapsearch -H "ldaps://SRV-AD3.cnra.local:636" -d 1 -b "ou=ICP,dc=cnra,dc=local" -D "" -s base "(objectClass=*)"

openssl s_client -servername srv-ad3.cnra.local -connect srv-ad3.cnra.local:636 -showcerts </dev/null 2>/dev/null | openssl x509 -outform PEM
```
### Generate a new self-signed certificate and private key:
```
[root@masternode1 ~]# openssl req -x509 -newkey rsa:2048 -keyout key04.pem -out cert04.pem -days 3000 -nodes -subj '/CN=*.10.85.234.203.nip.io'
```
### Export certification and public key from a java keystore:
Export to p12 format:
```
keytool -v -importkeystore -srckeystore keystore.jks -srcalias my_alias -destkeystore mfp.p12 -deststoretype PKCS12
```
Then use openssl to export the public and private keys:
```
openssl pkcs12 -in mfp.p12  -nodes
```
Export certificate from a keystore and import it in to a truststore:
```
keytool -exportcert -keystore keystore.jks  -alias my_alias -file mfp.cer -rfc
keytool -import -file ./mfp.cer -alias mfpserver -keystore truststore.jks
```
### Generate a self-signed certificate and create a kubernetes secret including it:
```
[root@masternode1 ~]# openssl req -x509 -newkey rsa:2048 -keyout mfp_ingress_key.pem -out mfp_ingress_crt.pem -days 3000 -nodes -subj '/CN=mfp.fabdc.local'
Generating a 2048 bit RSA private key
....+++
...+++
writing new private key to 'mfp_ingress_key.pem'
-----
[root@masternode1 ~]# kubectl create secret generic mfp-ingress-cert-02 --from-file=tls.crt=./mfp_ingress_crt.pem --from-file=tls.key=./mfp_ingress_key.pem 
```
### Rebuild MFP keystore/truststore:
```
[CLI]# openssl s_client -connect prod.apicapi-gateway.fabdc.local:443 -showcerts </dev/null 2>/dev/null | openssl x509 -outform PEM | tee ./icp_ingress.crt
[CLI]# kubectl cp mfpserver02-ibm-mfpf-server-prod-78fd45ff9c-d4sg4:/opt/ibm/wlp/usr/servers/mfp/resources/security/truststore.jks .
[CLI]# kubectl cp mfpserver02-ibm-mfpf-server-prod-78fd45ff9c-d4sg4:/opt/ibm/wlp/usr/servers/mfp/resources/security/keystore.jks .
[CLI]# keytool -import -file ./icp_ingress.crt -alias icp_ingress -keystore truststore.jks
[CLI]# echo "mfp2ibm" > keystore-password.txt
[CLI]# echo "mfp2ibm" > truststore-password.txt
[CLI]# kubectl delete secret mfpf-cert-secret-dev
[CLI]# kubectl create secret generic mfpf-cert-secret-dev --from-file keystore-password.txt --from-file truststore-password.txt --from-file keystore.jks --from-file truststore.jks
Restart MFP server pod
```
### Create TLS Ingress:
```
cat << EOF > mfpingress-https.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    ingress.kubernetes.io/ssl-passthrough: "true"
  labels:
    app: mfpserver02-ibm-mfpf-server-prod
  name: mfp-ingress-https
  namespace: default
spec:
  rules:
  - host: mfp2.fabdc.local
    http:
        paths:
        - backend:
            serviceName: mfpserver02-ibm-mfpf-server-prod
            servicePort: 9443
          path: /mfpconsole
        - backend:
            serviceName: mfpserver02-ibm-mfpf-server-prod
            servicePort: 9443
          path: /
  tls:
  - hosts:
    - mfp2.fabdc.local
    secretName: mfp-ingress-cert-02
EOF
```
### Create self-signed certificate using keytool:
```
keytool -keystore keystore1.jks -genkeypair -keyalg rsa -keysize 2048 -alias apicmgr -validity 730 -storepass apic2ibm -keypass apic2ibm -dname "CN=prod.apicmanager.fabdc.local,OU=Digital,O=First Abu Dhabi Bank,L=Abu Dhabi,S=Abu Dhabi,C=AE"
```
### Generate CSR of the self-signed certificate using keytool:
```
keytool -certreq -alias apicmgr -keyalg RSA -file apic-mgr.csr -keystore keystore1.jks
```
### Automation Generating CSR:
```
cat ./hostlist|awk -F. '{print $1}'|xargs -I arg keytool -keystore fabnewdev.jks -genkeypair -keyalg rsa -keysize 2048 -alias arg -validity 730 -storepass fab2ibm -keypass fab2ibm -dname "CN=arg.fabdc.local,OU=Digital,O=First Abu Dhabi Bank,L=Abu Dhabi,S=Abu Dhabi,C=AE"

cat ./hostlist|awk -F. '{print $1}'|xargs -I arg keytool -certreq -alias arg -keyalg RSA -file arg.csr -keystore fabnewdev.jks -storepass fab2ibm
```

### Convert certification and key to p12 certification store:
```
openssl pkcs12 -export -out fab-am.p12 -inkey dev2.apicmanager.10.85.234.203.nip.io.key -in dev2.apicmanager.10.85.234.203.nip.io.cer -certfile fabca.cer
```
### Encode a certificate using base64:
```
cat FABPRDCerts/apicapi-gateway.fabdc.local.cer |base64 -w0
```
### Encode and decode certificate using base 64:
```
cat FABPRDCerts/apicmanager.fabdc.local.cer |base64 -w0|base64 -d
```
### Combined certificate chain
When creating a combined certificate, put first the app certificate then the intermediate certificate then the root certificate as per the following example (if the application accepts also a ca certificate, combine the intermediate and root certificate on one file as shown below and load it as the ca certificate):
```
-----BEGIN CERTIFICATE----- < app certificate
MIIGtTCCBJ2gAwIBAgITbQAAAAK40WOvwP48owAAAAAAAjANBgkqhkiG9w0BAQsF
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE----- < intermediate certificate
MIIFNzCCAx+gAwIBAgIQe8m6fBAAmJtNce8o6SOGhDANBgkqhkiG9w0BAQsFADAu
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE----- < Root certificate
MIIFNzCCAx+gAwIBAgIQe8m6fBAAmJtNce8o6SOGhDANBgkqhkiG9w0BAQsFADAu
-----END CERTIFICATE-----
```
### Print certificate content:
```
openssl x509 -in /etc/kubernetes/pki/apiserver-etcd-client.crt -text -noout
```
### Print CSR content:
```
openssl req -in /etc/kubernetes/pki/apiserver-etcd-client.csr -text -noout
```