$configFile = "$PWD\config.xml"
$config=[XML](Get-Content $configFile)

$base_url=$config.config.base_url
$access_token=$config.config.access_token
$service_name=$config.config.service_name
##paths

$path_metric_list=$config.SelectSingleNode('config/paths/path[name="path_metric_list"]/url').InnerText;
$path_service_list=$config.SelectSingleNode('config/paths/path[name="path_service_list"]/url').InnerText;
$path_mapping_rules_list=$config.SelectSingleNode('config/paths/path[name="path_mapping_rules_list"]/url').InnerText;

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
"get service id for " + $service_name
$full_url=$base_url + $path_service_list +$access_token_para
$reponse=Invoke-WebRequest -Method GET -Uri $full_url
$content=[xml]($reponse.Content)
$service_id=$content.SelectSingleNode("services/service[name='$service_name']/id").InnerText
$service_id

#list methods
"list methods"
$full_url=$base_url + $path_metric_list + $access_token_para -replace "{service_id}",$service_id
$reponse=Invoke-WebRequest -Method GET -Uri $full_url
$content=[xml]($reponse.Content)
$methods=$content.metrics.method

#list mapping rules
"list mapping rules"
$full_url=$base_url + $path_mapping_rules_list + $access_token_para -replace "{service_id}",$service_id
$reponse=Invoke-WebRequest -Method GET -Uri $full_url
$content=[xml]($reponse.Content)
$mapping_rules=$content.mapping_rules.mapping_rule

##create method and mapping rules from config file
$xml_rules=[xml]'<rules/>'
foreach($method in $methods){
    foreach($mapping_rule in $mapping_rules){
        if($method.id -eq $mapping_rule.metric_id){
            $method.friendly_name + "  " + $mapping_rule.pattern + "  " + $mapping_rule.http_method

            $xml_rule=$xml_rules.CreateElement('rule')
            $xml_verb=$xml_rules.CreateElement('verb')
            $xml_method=$xml_rules.CreateElement('method')
            $xml_pattern=$xml_rules.CreateElement('pattern')

            $xml_verb.InnerText=$mapping_rule.http_method
            $xml_method.InnerText=$method.friendly_name
            $xml_pattern.InnerText=$mapping_rule.pattern

            $xml_rule.AppendChild($xml_verb)
            $xml_rule.AppendChild($xml_method)
            $xml_rule.AppendChild($xml_pattern)
            $xml_rules.DocumentElement.AppendChild($xml_rule)
            break;
        }
    }
}
$xml_rules.Save("$PWD\rules.xml")



