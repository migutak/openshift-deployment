# Enable DataPower WebGUI for containerized deployment
```shell
cd /Install/apic/projects/apic41
apicup subsys get gwy|grep extra
cat << EOF > /Install/apic/projects/dp-extra.yaml
datapower:
  # Gateway MGMT variables
  # This value should either be 'enabled' or 'dislabled'. Default is disabled
  webGuiManagementState: "enabled"
  webGuiManagementPort: 9090
  webGuiManagementLocalAddress: 0.0.0.0
  # This value should either be 'enabled' or 'dislabled'. Default is disabled
  gatewaySshState: "enabled"
  gatewaySshPort: 9022
  gatewaySshLocalAddress: 0.0.0.0
  # This value should either be 'enabled' or 'dislabled'. Default is disabled
  restManagementState: "enabled"
  restManagementPort: 5554
  restManagementLocalAddress: 0.0.0.0
EOF

apicup subsys set gwy extra-values-file=/Install/apic/projects/dp-extra.yaml

cat << EOF > installSubsys.sh
#!/usr/bin/bash
#
# UPDATE VARIABLES TO MATCH THE ENVIRONMENT
#
export PATH=\$PWD:\$PATH

# Global Parameters
PROJECT_NAME=apic41

cd ./$PROJECT_NAME

echo installing \$1 subsystem
apicup subsys install \$1
EOF

cat << EOF > webgui.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    ingress.kubernetes.io/ssl-passthrough: "true"
    ingress.kubernetes.io/ssl-redirect: "true"
  labels:
    app: r90f95d4ec5-dynamic-gateway-service-gw-webgui-0
    chart: dynamic-gateway-service-1.0.56
    component: dynamic-gateway-service-gw
    heritage: Tiller
    release: r90f95d4ec5
  name: r90f95d4ec5-dynamic-gateway-service-gw-webgui-0
  namespace: apic-dmz
spec:
  rules:
  - host: webgui-0-apic-prod.riyadbank.com
    http:
      paths:
      - backend:
          serviceName: r90f95d4ec5-dynamic-gateway-service-ingress-webgui-0
          servicePort: 9090
        path: /
  tls:
  - hosts:
    - webgui-0-apic-prod.riyadbank.com
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: dynamic-gateway-service-webgui-0
  name: r90f95d4ec5-dynamic-gateway-service-ingress-webgui-0
  namespace: apic-dmz
spec:
  ports:
  - name: api-gw-webgui
    port: 9090
    protocol: TCP
    targetPort: 9090
  selector:
    statefulset.kubernetes.io/pod-name: r90f95d4ec5-dynamic-gateway-service-0
    release: r90f95d4ec5
  type: ClusterIP
---

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    ingress.kubernetes.io/ssl-passthrough: "true"
    ingress.kubernetes.io/ssl-redirect: "true"
  labels:
    app: r90f95d4ec5-dynamic-gateway-service-gw-webgui-1
    chart: dynamic-gateway-service-1.0.56
    component: dynamic-gateway-service-gw
    heritage: Tiller
    release: r90f95d4ec5
  name: r90f95d4ec5-dynamic-gateway-service-gw-webgui-1
  namespace: apic-dmz
spec:
  rules:
  - host: webgui-1-apic-prod.riyadbank.com
    http:
      paths:
      - backend:
          serviceName: r90f95d4ec5-dynamic-gateway-service-ingress-webgui-1
          servicePort: 9090
        path: /
  tls:
  - hosts:
    - webgui-1-apic-prod.riyadbank.com
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: dynamic-gateway-service-webgui-1
  name: r90f95d4ec5-dynamic-gateway-service-ingress-webgui-1
  namespace: apic-dmz
spec:
  ports:
  - name: api-gw-webgui
    port: 9090
    protocol: TCP
    targetPort: 9090
  selector:
    statefulset.kubernetes.io/pod-name: r90f95d4ec5-dynamic-gateway-service-1
    release: r90f95d4ec5
  type: ClusterIP
---

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    ingress.kubernetes.io/ssl-passthrough: "true"
    ingress.kubernetes.io/ssl-redirect: "true"
  labels:
    app: r90f95d4ec5-dynamic-gateway-service-gw-webgui-2
    chart: dynamic-gateway-service-1.0.56
    component: dynamic-gateway-service-gw
    heritage: Tiller
    release: r90f95d4ec5
  name: r90f95d4ec5-dynamic-gateway-service-gw-webgui-2
  namespace: apic-dmz
spec:
  rules:
  - host: webgui-2-apic-prod.riyadbank.com
    http:
      paths:
      - backend:
          serviceName: r90f95d4ec5-dynamic-gateway-service-ingress-webgui-2
          servicePort: 9090
        path: /
  tls:
  - hosts:
    - webgui-2-apic-prod.riyadbank.com
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: dynamic-gateway-service-webgui-2
  name: r90f95d4ec5-dynamic-gateway-service-ingress-webgui-2
  namespace: apic-dmz
spec:
  ports:
  - name: api-gw-webgui
    port: 9090
    protocol: TCP
    targetPort: 9090
  selector:
    statefulset.kubernetes.io/pod-name: r90f95d4ec5-dynamic-gateway-service-2
    release: r90f95d4ec5
  type: ClusterIP
EOF
```