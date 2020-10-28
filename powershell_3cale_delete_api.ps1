$configFile = "$PWD\dev.xml"
$config=[XML](Get-Content $configFile)

$base_url=$config.config.base_url
$access_token=$config.config.access_token
$service_name=$config.config.service_name
##paths

$path_service_list=$config.SelectSingleNode('config/paths/path[name="path_service_list"]/url').InnerText;
$path_mapping_rules_list=$config.SelectSingleNode('config/paths/path[name="path_mapping_rules_list"]/url').InnerText;
$path_mapping_rule_delete=$config.SelectSingleNode('config/paths/path[name="path_mapping_rule_delete"]/url').InnerText;
$path_metric_delete=$config.SelectSingleNode('config/paths/path[name="path_metric_delete"]/url').InnerText;

#rules from config
$rules_to_be_delete=$config.config.rules.rule

##paras
$content_type="application/x-www-form-urlencoded"
$access_token_para="?access_token="+$access_token
$access_token_body=@{
    access_token=$access_token
}

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
"get service id for " + $service_name
$full_url=$base_url + $path_service_list +$access_token_para
$reponse=Invoke-WebRequest -Method GET -Uri $full_url
$content=[xml]($reponse.Content)
$service_id=$content.SelectSingleNode("services/service[name='$service_name']/id").InnerText
$service_id

#list mapping rules
"list mapping rules"
$full_url=$base_url + $path_mapping_rules_list + $access_token_para -replace "{service_id}",$service_id
$reponse=Invoke-WebRequest -Method GET -Uri $full_url
$content=[xml]($reponse.Content)
$mapping_rules=$content.mapping_rules.mapping_rule

#delete mapping rule and method
foreach($rule_to_be_delete in $rules_to_be_delete){
    foreach($mapping_rule in $mapping_rules){
        if(($rule_to_be_delete.verb -eq $mapping_rule.http_method) -and ($rule_to_be_delete.pattern -eq $mapping_rule.pattern)){
            "delete " + $rule_to_be_delete.pattern
            $full_url=$base_url + $path_mapping_rule_delete -replace "{service_id}",$service_id -replace "{id}",$mapping_rule.id 
            $reponse=Invoke-WebRequest -Method DELETE -Uri $full_url -body $access_token_body -ContentType $content_type
            $content=[xml]($reponse.Content)
            "delete " + $mapping_rule.metric_id
            $full_url=$base_url + $path_metric_delete -replace "{service_id}",$service_id -replace "{id}",$mapping_rule.metric_id 
            $reponse=Invoke-WebRequest -Method DELETE -Uri $full_url -body $access_token_body -ContentType $content_type
            $content=[xml]($reponse.Content)
            break;
        }
    }
}




