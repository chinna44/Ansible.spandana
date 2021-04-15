#!/bin/bash

function trim {
    local trimmed="$1"

    # Strip leading spaces.
    while [[ $trimmed == ' '* ]]; do
       trimmed="${trimmed## }"
    done
    # Strip trailing spaces.
    while [[ $trimmed == *' ' ]]; do
        trimmed="${trimmed%% }"
    done

    echo "$trimmed"
}

function verifyHelper {
        echo "helper library loaded..."
        export http_proxy=$(echo "http://${sso}:${pass}@PITC-Zscaler-Americas-Alpharetta3PR.proxy.corporate.ge.com:80")
        export https_proxy=$(echo "http://${sso}:${pass}@PITC-Zscaler-Americas-Alpharetta3PR.proxy.corporate.ge.com:80")
}


function unAssumeRole {
    # you need to unset these values in case they were set from a previous call to this function
    # you want 'aws sts assume-role' to use the credentials provided by the IAM profile
    
    #this is extra precaution
    AWS_ACCESS_KEY_ID=""
    AWS_SECRET_ACCESS_KEY=""
    AWS_SESSION_TOKEN=""
    AWS_SECURITY_TOKEN=""

    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    unset AWS_SECURITY_TOKEN
    
}

# this function will assume the role specified. Will quit the script if it errors out
function assumeRole {


    local ROLE_TO_ASSUME=$( echo "arn:aws:iam::${1}:role/inf/iam-ssm-execution-role")

    # print it for informational purposes
    echo "Running:: aws sts assume-role --role-arn $ROLE_TO_ASSUME --role-session-name ssm-assume-execution-role"

    # clear the variables
    # unAssumeRole
    
    
    export AWS_ACCESS_KEY_ID=$( echo "{${gpssmkey:1}" | jq -r '.aws_access_key_id' |  tr -d '\r')
    export AWS_SECRET_ACCESS_KEY=$( echo "{${gpssmkey:1}" | jq -r '.aws_secret_access_key' |  tr -d '\r')


    # assume the role
    CREDDOC=$(aws sts assume-role --role-arn $ROLE_TO_ASSUME --role-session-name ssm-assume-execution-role)

    # exit on error
    ERR=$?
    [ 0 -ne $ERR ] && echo "Could not assume role $ROLE_TO_ASSUME; exit code was $ERR" && exit 77


    export AWS_ACCESS_KEY_ID=$( echo "${CREDDOC}" | jq -r '.Credentials.AccessKeyId' |  tr -d '\r' )
    export AWS_SECRET_ACCESS_KEY=$( echo "${CREDDOC}" | jq -r '.Credentials.SecretAccessKey' |  tr -d '\r' )
    export AWS_SESSION_TOKEN=$( echo "${CREDDOC}" | jq -r '.Credentials.SessionToken' |  tr -d '\r' )
    export AWS_DEFAULT_REGION=${2}


    aws sts get-caller-identity 
  
}

function getInstance {
    local instances=$(aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:role,Values=app Name=tag:env,Values=${1} Name=tag:app,Values=${2} --query "Reservations[*].Instances[*].InstanceId" | jq ".[][]" | paste -sd, -)
    echo "[$instances]"
}

function getInstanceWithInstTag {
    local instances=$(aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:role,Values=app Name=tag:env,Values=${1} Name=tag:app,Values=${2} Name=tag:appInstance,Values=${3} --query "Reservations[*].Instances[*].InstanceId" | jq ".[][]" | paste -sd, -)
    echo "[$instances]"
}


function invokePush {
    local modulename="app"
    if [[ -z "${3}" ]]
    then
       echo "No argument supplied.. using module name as app"
    else
       echo "argument supplied.. using module name as ${3}"
       modulename="${3}"
    fi
    local params=$(echo "{ \"ArtifactoryUser\":"[\"$artifactoryuser\""], \"ArtifactoryPass\":"[\"$artifactorypass\""] , \"BuildNo\":"[\"$Build\""], \"ModuleName\":"[\"$modulename\""]}")
    aws ssm send-command --instance-ids "${1}" --document-name "arn:aws:ssm:us-east-1:325381443140:document/app-autodeploy-pushbuild-chefzero" --parameters "${params}" --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --region "${2}"
}
function invokeExecute {
    local params=$(echo "{ \"ArtifactoryUser\":"[\"$artifactoryuser\""], \"ArtifactoryPass\":"[\"$artifactorypass\""] , \"ScriptName\":"[\"${3}\""]}")
    
    aws ssm send-command --instance-ids "${1}" --document-name "arn:aws:ssm:us-east-1:325381443140:document/app-autodeploy-executescript-chefzero" --parameters "${params}" --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --region "${2}"
}
