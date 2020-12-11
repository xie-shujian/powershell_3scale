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
#env folder
$folder="$PWD\conf\uat\"
$cross_folder="$PWD\conf\cross\"
#config file
$configFile = $folder + "info.xml"
$config=[XML](Get-Content $configFile)
$base_url=$config.config.base_url
$access_token=$config.config.access_token
$stage_url=$config.config.stage_url
#admin api
$adminFile = "$PWD\conf\admin-api.xml"
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
$path_proxy_read=$adminAPI.admin.proxy.read
$path_proxy_latest=$adminAPI.admin.proxy.latest
$path_proxy_promote=$adminAPI.admin.proxy.promote
$path_backend_list=$adminAPI.admin.backend.list
$path_backend_usage_list=$adminAPI.admin.backend.usage.list
$path_proxy_deploy=$adminAPI.admin.proxy.deploy
$path_policy_show=$adminAPI.admin.policy.show
##paras
#apis
$service_list_file = $cross_folder+"service_list.xml"
$service_list_xml = [XML](Get-Content $service_list_file)
$service_list=$service_list_xml.services.service
##paras
$content_type="application/x-www-form-urlencoded"
$access_token_para="?access_token="+$access_token

#dedicated para
$old_services=@()
$new_services=@()
$old_plans=@()
$new_plans=@()
$old_accounts=@()
$new_accounts=@()
$old_backends=@()
$new_backends=@()

#create backends
$backend_file=$cross_folder+"backend.json"
$backends_json= ConvertFrom-Json (Get-Content $backend_file -Raw)
$backend_apis=$backends_json.backend_apis.backend_api
$old_backends=$backend_apis.id

foreach($backend_api in $backend_apis){
    $name=$backend_api.name
    $private_endpoint=$backend_api.private_endpoint
    "create backend $name"
    $full_url=$base_url + $path_backend_list            
    $body=@{
        access_token=$access_token
        name=$name
        private_endpoint=$private_endpoint
    }
    $reponse=Invoke-WebRequest -Method POST -TimeoutSec 60 -Uri $full_url -body $body -ContentType $content_type
    $rep_json=ConvertFrom-Json $reponse.Content
    $backend_id=$rep_json.backend_api.id
    $backend_id
    $new_backends+=$backend_id
    
}

#create service one by one
foreach($service in $service_list){

    $old_metrics=@()
    $new_metrics=@()

    $auth_mode=$service.backend_version

    $old_service_id=$service.id
    $service_name=$service.name    
    Write-Host "start create service " + $service_name -ForegroundColor green 
    ##service create
    "create service"
    $full_url=$base_url + $path_service_list
    $body=@{
        access_token=$access_token
        name=$service_name
        deployment_option=$service.deployment_option
        backend_version=$service.backend_version
    }
    $reponse=Invoke-WebRequest -Method POST -TimeoutSec 60 -Uri $full_url -body $body -ContentType $content_type
    $service_id=([xml]$reponse.Content).service.id
    $service_id

    $old_services+=$service.id
    $new_services+=$service_id

    "get backend id"
    $backend_usage_file=$cross_folder+"backend_usage\" + $service.id + ".json"
    $backend_usage_json= ConvertFrom-Json (Get-Content $backend_usage_file)
    $backend_usages=$backend_usage_json.backend_usage
    foreach($backend_usage in $backend_usages){
        $path=$backend_usage.path
        #look for new backend id
        $new_backend_id=-1
        for($i=0;$i -le $old_backends.count;$i++){
            if($old_backends[$i] -eq $backend_usage.backend_id){
                $new_backend_id=$new_backends[$i]
                break
            }
        }
        "add backend to service"
        $full_url=$base_url + $path_backend_usage_list -replace "{service_id}",$service_id
        $body=@{
            access_token=$access_token
            backend_api_id=$new_backend_id
            path=$path
        }
        $reponse=Invoke-WebRequest -Method POST -TimeoutSec 60 -Uri $full_url -body $body -ContentType $content_type   
    }

    #get proxy
    $proxy_file = $cross_folder+"proxy\" + $service.id + ".xml"
    $proxy_xml = [XML](Get-Content $proxy_file)
    $old_proxy=$proxy_xml.proxy
    #update proxy
    "update proxy"
    $full_url=$base_url + $path_proxy_read -replace "{service_id}",$service_id
    $body=@{
        access_token=$access_token
        credentials_location=$old_proxy.credentials_location
        oidc_issuer_endpoint=$old_proxy.oidc_issuer_endpoint
        sandbox_endpoint=$stage_url
    }
    $reponse=Invoke-WebRequest -Method PATCH -Uri $full_url -body $body -ContentType $content_type

    #get policy
    $policy_file = $cross_folder+"policy\" + $service.id + ".json"
    $policy = Get-Content $policy_file
    $len=$policy.Length
    $chain=$policy.Remove($len-1,1).Remove(0,19)
    #update policy
    "update policy"
    $full_url=$base_url + $path_policy_show -replace "{service_id}",$service_id
    $body=@{
        access_token=$access_token
        policies_config=$chain
    }
    $reponse=Invoke-WebRequest -Method PUT -Uri $full_url -body $body -ContentType $content_type

    #update oidc
    if($auth_mode -eq "oidc"){
        "update oidc"
        $full_url=$base_url + $path_oidc_show -replace "{service_id}",$service_id
        $body=@{
            access_token=$access_token
            standard_flow_enabled="true"
            implicit_flow_enabled="true"
            service_accounts_enabled="true"
            direct_access_grants_enabled="true"
        }
        $reponse=Invoke-WebRequest -Method PATCH -Uri $full_url -body $body -ContentType $content_type
    }

    ##get metric hits id
    "get hits id"
    $full_url=$base_url + $path_metric_list + $access_token_para -replace "{service_id}",$service_id
    $reponse=Invoke-WebRequest -Method GET -Uri $full_url
    $hits_id=([xml]$reponse.Content).SelectSingleNode('/metrics/metric[name="hits"]/id').InnerText
    $hits_id

    #get default mapping rule
    "get default mapping rule"
    $full_url=$base_url + $path_mapping_rule_list + $access_token_para -replace "{service_id}",$service_id
    $reponse=Invoke-WebRequest -Method GET -Uri $full_url
    $default_mapping_rule_id=([xml]$reponse.Content).SelectSingleNode('/mapping_rules/mapping_rule/id').InnerText
    $default_mapping_rule_id
    #delete default mapping rule
    "delete default mapping rule"
    $full_url=$base_url + $path_mapping_rule_show + $access_token_para -replace "{service_id}",$service_id -replace "{id}",$default_mapping_rule_id
    $reponse=Invoke-WebRequest -Method DELETE -Uri $full_url

    #create metric
    $metrics=$service.metrics.metric
    foreach($metric in $metrics){
        
        $old_metrics+=$metric.id

        if($metric.friendly_name -ne "Hits"){
            ##create metric
            "create metric " + $metric.friendly_name
            $full_url=$base_url + $path_metric_list -replace "{service_id}",$service_id
            $body=@{
                access_token=$access_token
                friendly_name=$metric.friendly_name
                unit=1
            }
            $reponse=Invoke-WebRequest -Method POST -TimeoutSec 60 -Uri $full_url -body $body -ContentType $content_type
            $metric_id=([xml]$reponse.Content).metric.id
            $metric_id

            $new_metrics+=$metric_id
         }else{
            $new_metrics+=$hits_id
         }
    }   
    
    #create method
    $methods=$service.metrics.method
    foreach($method in $methods){    
        ##create method
        "create method " + $method.friendly_name
        $full_url=$base_url + $path_method_list -replace "{service_id}",$service_id -replace "{metric_id}",$hits_id
        $body=@{
            access_token=$access_token
            friendly_name=$method.friendly_name
            unit="hit"
        }
        $reponse=Invoke-WebRequest -Method POST -TimeoutSec 60 -Uri $full_url -body $body -ContentType $content_type
        $method_id=([xml]$reponse.Content).method.id
        $method_id

        $old_metrics+=$method.id
        $new_metrics+=$method_id
    }
     
    #create mapping rule
    #apis
    $mapping_rule_file = $cross_folder+"mapping_rule\$old_service_id.xml"
    $mapping_rule_xml = [XML](Get-Content $mapping_rule_file)
    $mapping_rules=$mapping_rule_xml.mapping_rules.mapping_rule
    foreach($mapping_rule in $mapping_rules){
        $old_metric_id=$mapping_rule.metric_id
        #find new metric id
        $new_metric_id=$hits_id
        for($i=0;$i -le $old_metrics.count;$i++){
            if($old_metrics[$i] -eq $old_metric_id){
                $new_metric_id=$new_metrics[$i]
                break
            }
        }

        ##create mapping rule
        "create mapping rule " + $mapping_rule.http_method + " " + $mapping_rule.pattern
        $full_url=$base_url + $path_mapping_rule_list -replace "{service_id}",$service_id
        $body=@{
            access_token=$access_token
            http_method=$mapping_rule.http_method
            pattern=$mapping_rule.pattern
            delta="1"
            metric_id=$new_metric_id
        }
        $reponse=Invoke-WebRequest -Method POST -Uri $full_url -body $body -ContentType $content_type
        $rule_id=([xml]$reponse.Content).mapping_rule.id
        $rule_id    
    }

    #deploy to sandbox
    "deploy to sandbox"
    $full_url=$base_url + $path_proxy_deploy -replace "{service_id}",$service_id
    $body=@{
        access_token=$access_token
    }
    $reponse=Invoke-WebRequest -Method POST -TimeoutSec 60 -Uri $full_url -body $body -ContentType $content_type

}

#crete plan one by one
"create plan one by one"
$plan_file = $cross_folder+"plan.xml"
$plan_xml = [XML](Get-Content $plan_file)
$plans=$plan_xml.plans.plan
foreach($plan in $plans){
    $old_service_id=$plan.service_id
    for($i=0;$i -le $old_services.count;$i++){
        if($old_services[$i] -eq $old_service_id){
            $new_service_id=$new_services[$i]
            ##create plan
            "create plan " + $plan.name
            $full_url=$base_url + $path_plan_list -replace "{service_id}",$new_service_id
            $body=@{
                access_token=$access_token
                name=$plan.name
                state_event="publish"
            }
            $reponse=Invoke-WebRequest -Method POST -Uri $full_url -body $body -ContentType $content_type
            $plan_id=([xml]$reponse.Content).plan.id
            $plan_id
            $old_plans+=$plan.id
            $new_plans+=$plan_id
            break
        }
    }
}

#create account one by one
"create account one by one"
$acount_file = $cross_folder+"account.xml"
$account_xml = [XML](Get-Content $acount_file)
$accounts=$account_xml.accounts.account
foreach($account in $accounts){
    ##create account
    "create account " + $account.org_name
    $full_url=$base_url + $path_account_create
    $body=@{
        access_token=$access_token
        org_name=$account.org_name
        username=$account.users.user.username
        email=$account.users.user.email
        password=$account.users.user.username
    }
    $reponse=Invoke-WebRequest -Method POST -Uri $full_url -body $body -ContentType $content_type
    $account_id=([xml]$reponse.Content).account.id
    $account_id
    $old_accounts+=$account.id
    $new_accounts+=$account_id
}

#create application one by one
"create application one by one"
$application_file = $cross_folder+"application.xml"
$application_xml = [XML](Get-Content $application_file)
$applications=$application_xml.applications.application
foreach($application in $applications){
    #look for account id
    $new_account_id=-1
    for($i=0;$i -le $old_accounts.count;$i++){
        if($old_accounts[$i] -eq $application.user_account_id){
            $new_account_id=$new_accounts[$i]
            break
        }
    }
    #look for plan id
    $new_plan_id=-1
    for($i=0;$i -le $old_plans.count;$i++){
        if($old_plans[$i] -eq $application.plan.id){
            $new_plan_id=$new_plans[$i]
            break
        }
    }

    #create application
    "create application " + $application.name
    $full_url=$base_url + $path_application_list -replace "{account_id}",$new_account_id
    $body=@{}
    if($null -eq $application.user_key){
        $body=@{
            access_token=$access_token
            account_id=$new_account_id
            plan_id=$new_plan_id
            name=$application.name
            description=$application.name
            application_id=$application.application_id
            application_key=$application.keys.key
            redirect_url=$application.redirect_url
        }
    }else{
        $body=@{
            access_token=$access_token
            account_id=$new_account_id
            plan_id=$new_plan_id
            name=$application.name
            description=$application.name
            user_key=$application.user_key
        }
    }

    $reponse=Invoke-WebRequest -Method POST -Uri $full_url -body $body -ContentType $content_type -TimeoutSec 120
    $application_id=([xml]$reponse.Content).application.id
    $application_id
}