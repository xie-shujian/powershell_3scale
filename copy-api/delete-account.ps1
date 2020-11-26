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
$path_service_read=$adminAPI.admin.service.read
$path_account_list=$adminAPI.admin.account.list
$path_account_read=$adminAPI.admin.account.read
#delete all acount
"delete all acount"
$full_url=$base_url + $path_account_list + $access_token_para
$reponse=Invoke-WebRequest -Method GET -TimeoutSec 60 -Uri $full_url
$content=[xml]($reponse.Content)
$accounts=$content.accounts.account
foreach($account in $accounts){
    ##delete account
    "delete account " + $account.org_name
    $full_url=$base_url + $path_account_read -replace "{id}",$account.id 
    $body=@{
        access_token=$access_token
    }
    $reponse=Invoke-WebRequest -Method DELETE -Uri $full_url -body $body -ContentType $content_type
}

#list all api
"list all api"
$full_url=$base_url + $path_service_list + $access_token_para
$list_service_reponse=Invoke-WebRequest -Method GET -TimeoutSec 60 -Uri $full_url
$list_service_content=[xml]($list_service_reponse.Content)
$service_list=$list_service_content.services.service
foreach($service in $service_list){
        ##delete service
        "delete service " + $service.name
        $full_url=$base_url + $path_service_read -replace "{id}",$service.id 
        $body=@{
            access_token=$access_token
        }
        $reponse=Invoke-WebRequest -Method DELETE -Uri $full_url -body $body -ContentType $content_type
}