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
#config file
$configFile = "$PWD\config.xml"
$config=[XML](Get-Content $configFile)
$base_url=$config.config.base_url
$access_token=$config.config.access_token
#admin api
$adminFile = "$PWD\admin-api.xml"
$adminAPI = [XML](Get-Content $adminFile)
$path_service_list=$adminAPI.admin.service.list
$path_mapping_rule_list=$adminAPI.admin.mapping_rule.list
$path_plan_all=$adminAPI.admin.plan.all
$path_account_list=$adminAPI.admin.account.list
$path_application_all=$adminAPI.admin.application.all
##paras
$content_type="application/x-www-form-urlencoded"
$access_token_para="?access_token="+$access_token
#list all api
"list all api"
$full_url=$base_url + $path_service_list + $access_token_para
$list_service_reponse=Invoke-WebRequest -Method GET -TimeoutSec 60 -Uri $full_url
$list_service_content=[xml]($list_service_reponse.Content)
$list_service_content.Save("$PWD\data\service_list.xml")

#list all plan
"list all plan"
$full_url=$base_url + $path_plan_all + $access_token_para
$reponse=Invoke-WebRequest -Method GET -TimeoutSec 60 -Uri $full_url
$content=[xml]($reponse.Content)
$content.Save("$PWD\data\plan.xml")

#save mapping rule to file
$services=$list_service_content.services.service
foreach($service in $services){
    #save mapping rule
    $service_id=$service.id
    #save mapping rule
    "save mapping rule for $service_id"
    $full_url=$base_url + $path_mapping_rule_list + $access_token_para -replace "{service_id}",$service_id
    $reponse=Invoke-WebRequest -Method GET -Uri $full_url
    $content=[xml]($reponse.Content)
    $content.Save("$PWD\mapping_rule\$service_id.xml")
}

#export all acount
"export all acount"
$full_url=$base_url + $path_account_list + $access_token_para
$reponse=Invoke-WebRequest -Method GET -TimeoutSec 60 -Uri $full_url
$content=[xml]($reponse.Content)
$content.Save("$PWD\data\account.xml")

#export all application
"export all application"
$full_url=$base_url + $path_application_all + $access_token_para
$reponse=Invoke-WebRequest -Method GET -TimeoutSec 60 -Uri $full_url
$content=[xml]($reponse.Content)
$content.Save("$PWD\data\application.xml")