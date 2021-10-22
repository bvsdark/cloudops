#! /bin/bash
accountrole="$@"
#Environment Variables set

source $WORKSPACE/s3replication/scripts/./envawsaccounts.sh
set +x
#AWS LOGIN - CHILDACCONT
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

aws_credentials_json=$(aws sts assume-role --role-arn $accountrole --role-session-name DevOps-CrossAccountSession --region us-east-1)

        if [ "$aws_credentials_json" == "" ]; then

        echo -e "\n###############################################################################################################"
        echo "Unable to assume AWS permissions for this operation. Validate the following:"
        echo "- Check any typo in this structure:    (User remediation)"
        echo "  {$accountrole}   ".
        echo "- Make sure you have set AWS Crossaccount permissions. (Administrators)"
        echo -e "#################################################################################################################\n"
        # exit 1
        else

        export AWS_ACCESS_KEY_ID=$(echo "$aws_credentials_json" | jq --exit-status --raw-output .Credentials.AccessKeyId)
        export AWS_SECRET_ACCESS_KEY=$(echo "$aws_credentials_json" | jq --exit-status --raw-output .Credentials.SecretAccessKey)
        export AWS_SESSION_TOKEN=$(echo "$aws_credentials_json" | jq --exit-status --raw-output .Credentials.SessionToken)
        #Get the current account Alias.
        AccountAlias=$(aws iam list-account-aliases --region $AWSREGION | jq .AccountAliases[] --raw-output)

        fi
