$configFile = "$PWD\create_application.xml"
$config=[XML](Get-Content $configFile)

$base_url=$config.config.base_url
$redirect_url=$config.config.redirect_url
$access_token=$config.config.access_token
$plan_id=$config.config.plan_id
##paths
$path_application_create="/admin/api/accounts/{account_id}/applications.xml";

# apps
$apps=$config.config.apps.app

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

#create applications
foreach($app in $apps){            
    #create application
    "create application " + $app.name
    $full_url=$base_url + $path_application_create -replace "{account_id}",$app.account_id
    $body=@{
        access_token=$access_token
        account_id=$app.account_id
        plan_id=$plan_id
        name=$app.name
        description=$app.name
        application_id=$app.application_id
        application_key=$app.application_key
        redirect_url=$redirect_url
    }
    $reponse=Invoke-WebRequest -Method POST -Uri $full_url -body $body -ContentType $content_type -TimeoutSec 120
    $application_id=([xml]$reponse.Content).application.id
    $application_id
}



