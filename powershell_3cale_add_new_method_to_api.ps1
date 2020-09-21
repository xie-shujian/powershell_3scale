##env var
$base_url="https://xxxxx"
$access_token="xxxxx"
$rules_file="rules.csv"
##service
$service_id='111'
##paths
$path_method_create="/admin/api/services/{service_id}/metrics/{metric_id}/methods.xml"
$path_mapping_rule_create="/admin/api/services/{service_id}/proxy/mapping_rules.xml"
$path_metric_list="/admin/api/services/{service_id}/metrics.xml"
$path_service_create="/admin/api/services.xml"
##paras
$content_type="application/x-www-form-urlencoded"
$access_token_para="?access_token="+$access_token

##ignore self sign certificate
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
$ErrorActionPreference="Stop"

##get metric hits id
"get hits id"
$full_url=$base_url + $path_metric_list + $access_token_para -replace "{service_id}",$service_id
$reponse=Invoke-WebRequest -Method GET -Uri $full_url
$metric_id=([xml]$reponse.Content).metrics.metric.id
$metric_id

##create method and mapping rules from config file
$rules=Import-Csv $rules_file
foreach($rule in $rules){
    $verb=$rule.verb
    $method=$rule.method
    $pattern=$rule.pattern
            
    ##create method
    "create method " + $method
    $full_url=$base_url + $path_method_create -replace "{service_id}",$service_id -replace "{metric_id}",$metric_id
    $body=@{
        access_token=$access_token
        friendly_name=$method
        system_name=$method
        unit="hit"
    }
    $reponse=Invoke-WebRequest -Method POST -Uri $full_url -body $body -ContentType $content_type
    $method_id=([xml]$reponse.Content).method.id
    $method_id

    ##create mapping rule
    "create mapping rule " + $verb + " " + $pattern
    $pattern
    $full_url=$base_url + $path_mapping_rule_create -replace "{service_id}",$service_id
    $body=@{
        access_token=$access_token
        http_method=$verb
        pattern=$pattern
        delta="1"
        metric_id=$method_id
    }
    $reponse=Invoke-WebRequest -Method POST -Uri $full_url -body $body -ContentType $content_type
    $rule_id=([xml]$reponse.Content).mapping_rule.id
}



