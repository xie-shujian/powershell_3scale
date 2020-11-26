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
$ErrorActionPreference="Continue"
#config file
$configFile = "$PWD\config.xml"
$config=[XML](Get-Content $configFile)
$base_url=$config.config.base_url
$access_token=$config.config.access_token
#admin api
$adminFile = "$PWD\admin-api.xml"
$adminAPI = [XML](Get-Content $adminFile)
$path_service_list=$adminAPI.admin.service.list
$path_service_read=$adminAPI.admin.service.read
$path_metric_list=$adminAPI.admin.metric.list
$path_method_list=$adminAPI.admin.method.list
$path_mapping_rule_list=$adminAPI.admin.mapping_rule.list
$path_mapping_rule_show=$adminAPI.admin.mapping_rule.show
$path_oidc_show=$adminAPI.admin.oidc.show
$path_plan_list=$adminAPI.admin.plan.list
$path_account_create=$adminAPI.admin.account.create
$path_application_list=$adminAPI.admin.application.list
$path_application_all=$adminAPI.admin.application.all
##paras
$content_type="application/x-www-form-urlencoded"
$access_token_para="?access_token="+$access_token
##dedicated para
$gw_url=$config.config.gw_url
$json_content_type="application/json"
$token_url=$gw_url+"/getToken"
#export all application
"export all application"

$service_id=158

$full_url=$base_url + $path_application_all + $access_token_para + "&service_id=" + $service_id
$reponse=Invoke-WebRequest -Method GET -TimeoutSec 60 -Uri $full_url
$content=[xml]($reponse.Content)
$applications=$content.applications.application
foreach($application in $applications){

    $application.name

    $client_id=$application.application_id
    $client_secret=$application.keys.key
    $service_id=$application.service_id
    $oidc_id=$application.oidc_configuration.id
    #list mapping rule
    $full_url=$base_url + $path_mapping_rule_list + $access_token_para -replace "{service_id}",$service_id
    $reponse=Invoke-WebRequest -Method GET -Uri $full_url
    $content=[xml]($reponse.Content)
    $mapping_rules=$content.mapping_rules.mapping_rule

    #init with app id app key
    $headers=@{
        app_id=$client_id
        app_key=$client_secret
    }
    #change to token
    if($null -ne $oidc_id){
        #get token
        $body=@{
            grant_type="client_credentials"
            client_secret=$client_secret
            client_id=$client_id
        }
        $rep=Invoke-WebRequest -Method POST -TimeoutSec 60 -Uri $token_url -body $body -ContentType $content_type
        $rep_json=ConvertFrom-Json $rep.Content
        $token=$rep_json.access_token
        $headers = @{
            Authorization="Bearer $token"
        }
    }
   
    foreach($mapping_rule in $mapping_rules){
        $http_method=$mapping_rule.http_method
        $pattern=$mapping_rule.pattern        
        $api_url=$gw_url+$pattern
        if($http_method -eq "POST"){
            $body="{}"
            try{
                $reponse=Invoke-WebRequest -Method POST -Headers $headers -TimeoutSec 60 -Uri $api_url -body $body -ContentType $json_content_type
                $StatusCode=$reponse.StatusCode
            }
            catch{
                $StatusCode = $_.Exception.Response.StatusCode.value__
            }          
        }elseif($http_method -eq "GET"){
            try{
                $reponse=Invoke-WebRequest -Method GET -Headers $headers -TimeoutSec 60 -Uri $api_url
                $StatusCode=$reponse.StatusCode
            }
            catch{
                $StatusCode = $_.Exception.Response.StatusCode.value__
            }            
        }
        $http_method + " " + $pattern +" "+$StatusCode  
    }

}