$configFile = "$PWD\dev.xml"
$config=[XML](Get-Content $configFile)

$base_url=$config.config.base_url
$access_token=$config.config.access_token
$service_name=$config.config.service_name
$application_plan_name=$config.config.application_plan_name
$limits=$config.config.limits.limit

##paths
$path_metric_list=$config.SelectSingleNode('config/paths/path[name="path_metric_list"]/url').InnerText;
$path_service_list=$config.SelectSingleNode('config/paths/path[name="path_service_list"]/url').InnerText;
$path_method_list=$config.SelectSingleNode('config/paths/path[name="path_method_create"]/url').InnerText;
$path_limit_create=$config.SelectSingleNode('config/paths/path[name="path_limit_create"]/url').InnerText;
$path_application_plan=$config.SelectSingleNode('config/paths/path[name="path_application_plan"]/url').InnerText;

##paras
$content_type="application/x-www-form-urlencoded"
$access_token_para="?access_token="+$access_token

##ignore self sign certificate
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate,WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
$ErrorActionPreference="Stop"

#get service id
"get service id"
$full_url=$base_url + $path_service_list +$access_token_para
$reponse=Invoke-WebRequest -Method GET -Uri $full_url
$content=[xml]$reponse.Content
$service_id=$content.SelectSingleNode("services/service[name='$service_name']/id").InnerText

##get metric hits id
"get hits id"
$full_url=$base_url + $path_metric_list + $access_token_para -replace "{service_id}",$service_id
$reponse=Invoke-WebRequest -Method GET -Uri $full_url
$metric_id=([xml]$reponse.Content).metrics.metric.id
$metric_id

#get or create plan
"get or create plan" + $application_plan_name
$full_url=$base_url + $path_application_plan + $access_token_para -replace "{service_id}",$service_id
$reponse=Invoke-WebRequest -Method GET -Uri $full_url
$content=[xml]$reponse.Content
$application_plan_id=$content.SelectSingleNode("plans/plan[name='$application_plan_name']/id").InnerText

if($application_plan_id){
    "application plan exist"
}else{
    #create plan
    "create plan"
    $full_url=$base_url + $path_application_plan -replace "{service_id}",$service_id
    $body=@{
        access_token=$access_token
        name=$application_plan_name
        state_event="publish"
    }
    $reponse=Invoke-WebRequest -Method POST -Uri $full_url -body $body -ContentType $content_type
    $application_plan_id=([xml]$reponse.Content).plan.id
}
$application_plan_id

##list methods
$full_url=$base_url + $path_method_list + $access_token_para -replace "{service_id}",$service_id -replace "{metric_id}",$metric_id
$reponse=Invoke-WebRequest -Method GET -Uri $full_url
$methods=([xml]$reponse.Content).methods.method
foreach($method in $methods){
    if($limits -contains $method.friendly_name){
        ##create limit
        "create limit " + $method.friendly_name
        $full_url=$base_url + $path_limit_create -replace "{application_plan_id}",$application_plan_id -replace "{metric_id}",$method.id
        $body=@{
            access_token=$access_token
            period="eternity"
            value=0
        }
        $reponse=Invoke-WebRequest -Method POST -Uri $full_url -body $body -ContentType $content_type
        $limit_id=([xml]$reponse.Content).limit.id
        $limit_id
    }
}


