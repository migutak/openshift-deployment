# OCP Operators Troubleshooting
### Checking catalog operator pod logs if installation failed and no resources created in the concerned project
This is a good starting point to better understand why a certain operator is not starting the installation process. Below is an example that shows the operator is missing some of its prereqs (ResolutionFailed in this case because there is no internet connection):
```
oc logs catalog-operator-8457d68cb8-jfp8q -n openshift-operator-lifecycle-manager
I1214 06:56:32.752878       1 event.go:278] Event(v1.ObjectReference{Kind:"Namespace", Namespace:"", Name:"cp4i-apic", UID:"4ef6ab15-c03e-479c-a1f0-7171eae65afe", APIVersion:"v1", ResourceVersion:"14466170", FieldPath:""}): type: 'Warning' reason: 'ResolutionFailed' constraints not satisfiable: ibm-apiconnect has a dependency without any candidates to satisfy it, ibm-apiconnect is mandatory
E1214 06:56:33.152295       1 queueinformer_operator.go:290] sync {"update" "cp4i-apic"} failed: constraints not satisfiable: ibm-apiconnect has a dependency without any candidates to satisfy it, ibm-apiconnect is mandatory

```