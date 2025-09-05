<h2>Introduction:</h2>
The repository contains the deliveries for the home task <br/>
The Environment is designed to be deployed on AWS and contains the following components:<br/>
Kubernetes cluster with a guestbook application (as attached to the task), Ingress controller with Cert-manager, ArgoCD and Prometheus.<br/>
The whole environment will be deployed by a single run of Terraform code.<br/>
The following folders are located in the repository:<br/>
- phonebook : contains the helm chart with the application yaml templates that is handled by ArgoCD<br/>
- Terraform : Contains the terraform code to be downloaded and run using Terraform CLI<br/>

 <br/>
<h2>Assumptions:</h2>
<li>Since it's a demo, the cheapest chipset was chosen, without considering redudency or stability</li>
<li>For the same reason, the self sign certificates were installed (instead of real DNS). The access to the website will trigger a <br/>&nbsp;&nbsp;&nbsp&nbsp;&nbsp;&nbspvalidation error, 
	but checking the certificate detail will provide the DNS name</li>
<li>For simplicity, the deplyment is done by a user with permissions and not by assume role</li>
<li>The deployment should be done with admin access (sorry, but I didn't find a convenient way to narrow permissions)</li>
<li>Password encrytption is not handled in this task</li>
<br/>
<br/>
<h2>Prerquisites:</h2>
<li>An AWS user with the admin access.</li>
<li>Terraform CLI installed locally</li>
<li>AWS CLI installed locally</li>
<li>kubectl component installed locally</li>

<br/>
<h2>Running instructions:</h2>
<ol>
<li>Download the Terraform folder</li>
<li>Open terminal</li>
<li>Run command <b>aws configure</b>  and insert user credtentials</li>
<li>Run command <b> terraform init</b> </li>
<li>Run command <b> terraform plan</b> and verify there are no errors</li>
<li>Run command <b> terraform apply -auto-approve </b></li>
<li>Wait until the execution is completed</li>
</ol>
<br/>
 <h4>To enable access to the websites, the following actions need to be done:</h4>
 <ol>
 <li>To adjust context, run command <b> aws eks --region us-east-1 update-kubeconfig --name Mars-task-cluster </b></li>
 <li>To receive the cluster URL run command</li>
	 <b> kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0]}' </b>
 <li>Copy the URL from the result and use it in the command  <b>nslookup { result_url }</b></li>
 <li>The output should contain 2 public IPs (under "Adresses" section)</li>
 <li>Copy one of the public IPs to a new line in your hosts file on your computer as follows:</li>
   <b> {copied public ip} &nbsp;&nbsp;&nbsp   guestbook.local &nbsp;&nbsp;&nbsp argocd.local  &nbsp;&nbsp;&nbsp prometheus.local  &nbsp;&nbsp;&nbsp  grafana.local </b>
 <li>Save the file</li>
</ol>


<h2>Environment access:</h2>
<li><b>Guestbook application</b>- Browse to URL <b>https://guestbook.local</b> and test the UI</li>
<li><b>ArgoCD:</b> </li>
<ol>
<li>Browse to URL <b>https://argocd.local</b></li>
<li>Enter credentials: admin / ArgoCD_pass!</li>
<li>Inspect details</li>
</ol>
<li><b>Prometheus</b> - Browse to URL <b>https://prometheus.local</b> and test the UI</li>

<li><b>Grafana:</b></li>
<ol>
<li>Browse to URL <b>https://grafana.local</b></li>
<li>Enter credentials: admin / Grafana_pass!</li>
<li>Inspect details </li>
</ol>
