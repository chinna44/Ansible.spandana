#!/bin/bash

#file is to run chef recipes inabsence of chef server (chef-client existed on server)using aws ssm for a jenkins particular publish job


pwd
ls -lart
cd ../helper 
pwd 
source helper.sh
cd ../PW_WEB_wmsa_Publish_SSM
pwd

verifyHelper

app_instance=`echo "${Application_Instance_Name}" | tr '[:upper:]' '[:lower:]'`
    
case $app_instance in
  *qa*) 
    aws_account_id=930136447543
    aws_region=us-east-1
    app_env=qa
    app_instance=TBD
    ;;
  *st2*)
    aws_account_id=988201728534 
    aws_region=us-east-1
    app_env=stg
    app_instance=st2-wmsa
    ;;
  *st*)
    aws_account_id=988201728534 
    aws_region=us-east-1
    app_env=stg
    app_instance=st-wmsa
    ;;
  *prd*)
    aws_account_id=988201728534 
    aws_region=us-east-1
    app_env=prd
    app_instance=prd-wmsa
    ;;
  *) 
    app_env=na 
    ;;
esac

if [ "$Action" == "Publish" ] 
then
  cd /usr/share/git/applicationConfig
  git pull

  FILE=/usr/share/git/applicationConfig/${Applicatin_Name}/$Application_Instance_Name/app/appConfig.json

  if [ -f $FILE ]
  then
    echo "File $FILE exists." 
	command_publish="jq 'map(if .components[0].Module_Name == "\"app"\" then .components[$Component_id].Build_Number = $Build else . end)' $FILE > /usr/share/git/temp.json"
    eval $command_publish
    cp /usr/share/git/temp.json $FILE
    git commit -am "updating build number for ${Applicatin_Name}/$Application_Instance_Name/app"
    git push origin master
  fi

  echo "Download build"
  
  echo "1. Starting download of the file on the instance .... This will take time"
  
  assumeRole $aws_account_id $aws_region
   
  instanceId=$(getInstanceWithInstTag  $app_env "wmsa-v3" $app_instance)
  
  invokePush $instanceId $aws_region
  
  echo "2. waiting till download is finished."
  
  sleep 90
  
  echo "3. Running deploy script"
  
  invokeExecute $instanceId $aws_region "deploy.sh"
  
else

  assumeRole $aws_account_id $aws_region
  
  instanceId=$(getInstanceWithInstTag  $app_env "wmsa-v3" $app_instance)
  
  invokeExecute $instanceId $aws_region "restart.sh"
  
fi
