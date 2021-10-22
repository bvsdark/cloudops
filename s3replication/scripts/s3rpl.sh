#! /bin/bash

#Environment Variables set
source $WORKSPACE/s3replication/scripts/./envawsaccounts.sh

#ENV
s3rplcblock=""
description="This resource allows replication from $SourceBucket bucket at account $SourceBucketawsalias towards bucket $DestBucket at account $DestBucketawsalias."
policyname="S3RPLFrom"
rolelabel="S3ReplicationRoleAUT"
#### PARAMETER VALIDATION #######

     if [ "$SourceBucket" == "" ]; then

        echo -e "\n#######################################################"
        echo "The SOURCE bucket parameter must not be empty"
        echo -e "#########################################################\n"

       exit 1
     elif [ "$DestBucket" == "" ]; then

        echo -e "\n#######################################################"
        echo "The DESTINATION bucket parameter must not be empty"
        echo -e "#########################################################\n"
        
       exit 1
      elif [ "$SourceBucket" == "$DestBucket" ]; then

        echo -e "\n##############################################################################"
        echo "The SOURCE and DESTINATION parameters must not contain the same value"
        echo -e "################################################################################\n"
       exit 1
     fi

##########################################################
#                    ACCOUNTS LOOK UP                 #
##########################################################

        echo -e "\n#########################"
        echo "Validating buckets existence."
        echo -e "##########################\n"

for id in `echo $awsaccountids`; do #awsaccountids comes from envawsaccounts.sh

#AWS LOGIN EACH ACCOUNT TO CONFIRM IF THE BUCKETS ARE PRESENT IN THE ACCOUNT
source $WORKSPACE/s3replication/scripts/./loginaccount.sh "arn:aws:iam::$id:role/DevOpsRole"


       
        checkSourceBucket=$(aws s3api list-buckets --region $AWSREGION | jq -r .Buckets[].Name | grep -x $SourceBucket)
        checkDestBucket=$(aws s3api list-buckets --region $AWSREGION | jq -r .Buckets[].Name | grep -x $DestBucket)


     if [ "$checkSourceBucket" == "$SourceBucket" ]; then

        SourceBucketaawsid=$id #Sets the aws account from which the bucket's data will be replicated.
        SourceBucketawsalias=$AccountAlias
        echo -e "SOURCE BUCKET $SourceBucket FOUND"
     fi

     if [ "$checkDestBucket" == "$DestBucket" ]; then

        DestBucketawsid=$id #Sets the aws account in which the bucket exist.
        DestBucketawsalias=$AccountAlias
        echo -e "DESTINATION BUCKET $DestBucket FOUND"
     fi
   
     if [ "$SourceBucketaawsid" != "" ] && [ "$DestBucketawsid" != "" ]; then

      echo -e "\n############################################################################################################################################"
      echo -e "ALL BUCKETS FOUND - SUMMARY"
      echo -e "SOURCE BUCKET INFO: NAME: $SourceBucket ACCOUNT: $SourceBucketawsalias - $SourceBucketaawsid"
      echo -e "DESTINATION BUCKET INFO: NAME: $DestBucket ACCOUNT: $DestBucketawsalias - $DestBucketawsid"
      echo -e "\n############################################################################################################################################"

     break
     fi
done

     if [ "$SourceBucketaawsid" == "" ]; then

      echo -e "\n##################################################################################################################"
      echo -e "ERROR - THE SOURCE BUCKET $SourceBucket HAS NOT BEEN FOUND"
      echo -e "TROUBLESHOOT:"
      echo -e "- MAKE SURE THE BUCKET EXISTS"
      echo -e "- CONFIRM WITH INFRA TEAM IF ALL ACCOUNTS ARE RIGHTLY ASSESSED BY THIS AUTOMATION"
      echo -e "\n#################################################################################################################"

      exit 1
     elif [ "$DestBucketawsid" == "" ]; then

      echo -e "\n##################################################################################################################"
      echo -e "ERROR - THE DESTINATION BUCKET $DestBucket HAS NOT BEEN FOUND"
      echo -e "TROUBLESHOOT:"
      echo -e "- MAKE SURE THE BUCKET EXISTS"
      echo -e "- CONFIRM WITH INFRA TEAM IF ALL ACCOUNTS ARE RIGHTLY ASSESSED BY THIS AUTOMATION"
      echo -e "\n#################################################################################################################"

      exit 1
     fi

if [ "$Terminate" == "True" ]; then


   ########### OPERATIONS AT DESTINATION BUCKET/ACCOUNT ###############

   source $WORKSPACE/s3replication/scripts/./loginaccount.sh "arn:aws:iam::$DestBucketawsid:role/DevOpsRole"
 
 checkppolicy=$(aws s3api get-bucket-policy --bucket $DestBucket --query Policy --output text --region $AWSREGION) ## Check for Existing S3 policy
 checkrplppolicy=$(echo $checkppolicy | jq -r ' .Statement[]  | select(.Sid == "'${policyname}-${SourceBucketawsalias}-${SourceBucket}'") | .Sid') # Check for Existing S3 REPLICATION policy

   if [ "$checkppolicy" == "" ]; then

         echo -e "\n###############################################################################################################################"
         echo "The destination $DestBucket bucket does not contain an S3 Replication policy. No further action is needed"
         echo -e "#################################################################################################################################\n"

   elif [ "$checkrplppolicy" == "${policyname}-${SourceBucketawsalias}-${SourceBucket}" ]; then

      s3policyarrays=$(echo $checkppolicy | jq -r ' .Statement[].Sid' | wc -l) # Checks if there is more than 1 array in the s3 policy to avoid exisiting permissions removal.

      if [ "$s3policyarrays" == "1" ]; then

         aws s3api delete-bucket-policy --bucket $DestBucket --region $AWSREGION

            if [ "$?" == "0" ]; then # Checks AWS exit code 0=Success 255=Failure failed

               echo -e "\n################################################################################"
               echo "The $DestBucket bucket's S3 Replication policy has been deleted with success."
               echo -e "#################################################################################\n"

            else
               echo -e "\n#########################################################################"
               echo "FAILURE trying to delete the $DestBucket bucket's S3 Replication policy."
               echo -e "###########################################################################\n"
            
            exit 1
            fi    
         
      else

         echo -e "\n################################################################################"
         echo "The $DestBucket bucket's contains more than one permission set."
         echo "Explicitly removing the S3 Replication policy."
         echo -e "#################################################################################\n"
      
         s3rplcblock=$(echo $checkppolicy | jq -r ' .Statement[] | select(.Sid == "'${policyname}-${SourceBucketawsalias}-${SourceBucket}'")') # Gets explicity the array containing the s3 replication policy
         s3policy=$(echo $checkppolicy | jq --argjson argval "$s3rplcblock" '.Statement -= [$argval]') # Gets explicity the array containing the s3 replication policy
         aws s3api put-bucket-policy --bucket $DestBucket --policy "$s3policy" --region $AWSREGION #Updates the S3 Policy

            if [ "$?" == "0" ]; then # Checks AWS exit code 0=Success 255=Failure failed

               echo -e "\n#######################################################################################################"
               echo "The $DestBucket bucket policy has been updated, the S3 Replication Policy has been removed with success."
               echo -e "#########################################################################################################\n"

            else
               echo -e "\n##########################################################################"
               echo "FAILURE trying to update The $DestBucket bucket S3 Replication policy."
               echo -e "###########################################################################\n"
            
               exit 1
            fi   

      fi
   fi


############# Disable Versioning ################

         aws s3api put-bucket-versioning --bucket $DestBucket --versioning-configuration Status=Suspended --region $AWSREGION

         if [ "$?" == "0" ]; then # Checks AWS exit code 0=Success 255=Failure failed

            echo -e "\n###############################################################"
            echo "Versioning successfully disabled at Source Bucket $DestBucket."
            echo -e "#################################################################\n"

         else
            echo -e "\n############################################################"
            echo "FAILURE: Unable disable Versioning at $DestBucket Bucket."
            echo -e "#############################################################\n"
           
           exit 1
         fi


########### OPERATIONS AT SOURCE BUCKET/ACCOUNT ###############

         source $WORKSPACE/s3replication/scripts/./loginaccount.sh "arn:aws:iam::$SourceBucketaawsid:role/DevOpsRole"

#######  REPLICATION DELETION/REMOVAL ########

rplrule="ReplicateTo-$DestBucket-$DestBucketawsalias"
checrplkrule=$(aws s3api get-bucket-replication --bucket $SourceBucket --region $AWSREGION | jq -r .ReplicationConfiguration.Rules[].ID | grep $rplrule)


            echo -e "\n########################################################"
            echo "Checking S3 replication rule for bucket $SourceBucket."
            echo -e "##########################################################\n"


         if [ "$checrplkrule" == "$rplrule" ]; then

            echo -e "\n#################################################################"
            echo "Removing replication rule $rplrule for bucket $SourceBucket."
            echo -e "###################################################################\n"

            aws s3api delete-bucket-replication --bucket $SourceBucket --region $AWSREGION > /dev/null

               if [ "$?" == "0" ]; then # Checks AWS exit code 0=Success 255=Failure failed

                  echo -e "\n###############################################################"
                  echo "The replication S3 rule $rplrule was DELETED with success"
                  echo -e "#################################################################\n"

               else
                  echo -e "\n############################################################"
                  echo "FAILURE: Unable to DELETE the S3 replication rule $rplrule for ."
                  echo -e "#############################################################\n"
               
               exit 1
               fi

         else

            echo -e "\n#######################################################################"
            echo "The S3 replication rule $rplrule is not present. No further action needed"
            echo -e "#########################################################################\n"

         fi

####### IAM ROLE SET FOR S3 REPLICATION REMOVAL ########

checkrole=$(aws iam list-roles --region $AWSREGION | jq -r .Roles[].RoleName | grep "${SourceBucket}-$rolelabel")

            echo -e "\n########################################################"
            echo "Checking IAM Role for replication from $SourceBucket."
            echo -e "##########################################################\n"


         if [ "$checkrole" == "${SourceBucket}-$rolelabel" ]; then

            echo -e "\n########################################################################################"
            echo "Removing the IAM role ${SourceBucket}-$rolelabel role."
            echo -e "##########################################################################################\n"

            aws iam delete-role-policy --role-name ${SourceBucket}-$rolelabel \
            --policy-name ${SourceBucket}-S3ReplicationPolicyAUT --region $AWSREGION

            aws iam delete-role --role-name ${SourceBucket}-$rolelabel --region $AWSREGION

            echo -e "\n########################################################################################"
            echo "IAM role ${SourceBucket}-$rolelabel role removed with success."
            echo -e "##########################################################################################\n"

         else

            echo -e "\n##################################################################################################"
            echo "The IAM role ${SourceBucket}-$rolelabel is NOT present. No further action is needed."
            echo -e "####################################################################################################\n"

         fi

checkversioning=$(aws s3api get-bucket-versioning --bucket $SourceBucket --region $AWSREGION | jq -r .Status)

            echo -e "\n########################################################"
            echo "Checking versioning status at source bucket $SourceBucket ."
            echo -e "##########################################################\n"

      if [ "$checkversioning" == "Enabled" ]; then

         echo -e "\n#######################################################################"
         echo "Disabling Versioning at Source Bucket $SourceBucket."
         echo -e "########################################################################\n"

          aws s3api put-bucket-versioning --bucket $SourceBucket --versioning-configuration Status=Suspended --region $AWSREGION

         if [ "$?" == "0" ]; then # Checks AWS exit code 0=Success 255=Failure failed

            echo -e "\n###############################################################"
            echo "Versioning successfully disabled at Source Bucket $SourceBucket."
            echo -e "#################################################################\n"

         else
            echo -e "\n############################################################"
            echo "FAILURE: Unable to disable Versioning at $SourceBucket."
            echo -e "#############################################################\n"
           
           exit 1
         fi

      else

         echo -e "\n##########################################################################################"
         echo "Versioning status is disabled at Source Bucket $SourceBucket. No further action is needed"
         echo -e "############################################################################################\n"

      fi

exit 0
fi


############### AWS S3 BUCKET ACCOUNT (PREPARE FOR REPLICATION) #################################
##########################################################################################

#### AWS S3 REPLICATION set at Destination BUCKET/ACCOUNT ########
###########################################################

############ S3 POLICY SET #################

source $WORKSPACE/s3replication/scripts/./loginaccount.sh "arn:aws:iam::$DestBucketawsid:role/DevOpsRole"

        echo -e "\n#################################################################"
        echo "Preparing $DestBucket bucket policy for replication."
        echo -e "###################################################################\n"

checkppolicy=$(aws s3api get-bucket-policy --bucket $DestBucket --query Policy --output text --region $AWSREGION) ## Check for Existing S3 policy


    if [ "$checkppolicy" == "" ] || [ "$?" != "0" ] ; then

        echo -e "\n###############################################################################################################################"
        echo "The destination $DestBucket bucket does not contain an S3 Replication policy. Creating S3 Replication Policy..."
        echo -e "#################################################################################################################################\n"

      s3rplcblock=$(cat $WORKSPACE/s3replication/policies/s3/s3rplpolicy.json \
      | sed -e "s/S3ReplicationPolicyAUT/${policyname}-${SourceBucketawsalias}-${SourceBucket}/g" \
      | sed -e "s/sourcesawsid/$SourceBucketaawsid/g" | sed -e "s/destbucket/$DestBucket/g") # Builds the S3 policy (from a default policy file) including the values in the job.
      
      aws s3api put-bucket-policy --bucket $DestBucket --policy "$s3rplcblock" --region $AWSREGION

         if [ "$?" == "0" ]; then # Checks AWS exit code 0=Success 255=Failure failed

            echo -e "\n#######################################################"
            echo "The $DestBucket bucket S3 Replication policy is now set."
            echo -e "#########################################################\n"

         else
            echo -e "\n############################################################"
            echo "FAILURE trying to set The $DestBucket bucket S3 Replication policy."
            echo -e "#############################################################\n"
           
           exit 1
         fi

    else

      checkrplppolicy=$(echo $checkppolicy | jq -r ' .Statement[]  | select(.Sid == "'${policyname}-${SourceBucketawsalias}-${SourceBucket}'") | .Sid') # Check for Existing S3 REPLICATION policy

      if [ "$checkrplppolicy" == "${policyname}-${SourceBucketawsalias}-${SourceBucket}" ]; then

        echo -e "\n############################################################################"
        echo "The S3 Replication Policy is already present at destination $DestBucket."
        echo -e "##############################################################################\n"

      elif [ "$checkrplppolicy" == "" ]; then

        echo -e "\n##########################################################################################################"
        echo "The destination $DestBucket has an S3 policy but lacks of the S3 Replication Policy. Setting S3 Replication Policy..."
        echo -e "############################################################################################################\n"

        s3rplcblock=$(cat $WORKSPACE/s3replication/policies/s3/s3rplpolicy.json \
        | sed -e "s/S3ReplicationPolicyAUT/${policyname}-${SourceBucketawsalias}-${SourceBucket}/g" \
        | sed -e "s/sourcesawsid/$SourceBucketaawsid/g" | sed -e "s/destbucket/$DestBucket/g" \
        | jq ' .Statement[]  | select(.Sid == "'${policyname}-${SourceBucketawsalias}-${SourceBucket}'")') # Builds and FORMATS the S3 policy with the parameters in the job (used from a default policy file).

        s3policy=$(echo $checkppolicy | jq --argjson argval "$s3rplcblock" '.Statement += [$argval]') # Builds the final policy without disfrupting the existing policy in the bucket.
       
      echo "###################POLICY TO BE UPLOADED##########################"
      echo -e "$s3policy"

        aws s3api put-bucket-policy --bucket $DestBucket --policy "$s3policy" --region $AWSREGION

         if [ "$?" == "0" ]; then # Checks AWS exit code 0=Success 255=Failure failed

            echo -e "\n################################################################################"
            echo "The $DestBucket bucket policy has been updated containing the S3 Replication Policy."
            echo -e "#################################################################################\n"

         else
            echo -e "\n############################################################"
            echo "FAILURE trying to update The $DestBucket bucket S3 Replication policy."
            echo -e "#############################################################\n"
           
           exit 1
         fi        

      fi
     

    fi

############ S3 VERSIONING SET #################

checkversioning=$(aws s3api get-bucket-versioning --bucket $DestBucket --region $AWSREGION | jq -r .Status)

            echo -e "\n########################################################"
            echo "Checking versioning status at Destination bucket $DestBucket."
            echo -e "##########################################################\n"

      if [ "$checkversioning" == "Enabled" ]; then

         echo -e "\n#######################################################################"
         echo "Versioning status is already enabled at Destination Bucket $DestBucket."
         echo -e "########################################################################\n"

      else

         aws s3api put-bucket-versioning --bucket $DestBucket --versioning-configuration Status=Enabled --region $AWSREGION

         if [ "$?" == "0" ]; then # Checks AWS exit code 0=Success 255=Failure failed

            echo -e "\n###############################################################"
            echo "Versioning successfully enabled at Destination Bucket $DestBucket."
            echo -e "#################################################################\n"

         else
            echo -e "\n############################################################"
            echo "FAILURE: Unable to set Versioning at $DestBucket."
            echo -e "#############################################################\n"
           
           exit 1
         fi

      fi

#### AWS S3 Replication set at SOURCE BUCKET/ACCOUNT ########
#############################################################

source $WORKSPACE/s3replication/scripts/./loginaccount.sh "arn:aws:iam::$SourceBucketaawsid:role/DevOpsRole"

############ S3 VERSIONING SET #################

checkversioning=$(aws s3api get-bucket-versioning --bucket $SourceBucket --region $AWSREGION | jq -r .Status)

            echo -e "\n########################################################"
            echo "Checking versioning status at source bucket $SourceBucket ."
            echo -e "##########################################################\n"

      if [ "$checkversioning" == "Enabled" ]; then

         echo -e "\n#######################################################################"
         echo "Versioning status is already enabled at Source Bucket $SourceBucket."
         echo -e "########################################################################\n"

      else

         aws s3api put-bucket-versioning --bucket $SourceBucket --versioning-configuration Status=Enabled --region $AWSREGION

         if [ "$?" == "0" ]; then # Checks AWS exit code 0=Success 255=Failure failed

            echo -e "\n###############################################################"
            echo "Versioning successfully enabled at Source Bucket $SourceBucket."
            echo -e "#################################################################\n"

         else
            echo -e "\n############################################################"
            echo "FAILURE: Unable to set Versioning at $SourceBucket."
            echo -e "#############################################################\n"
           
           exit 1
         fi

      fi


####### IAM ROLE SET FOR S3 REPLICATION ########

checkrole=$(aws iam list-roles --region $AWSREGION | jq -r .Roles[].RoleName | grep "${SourceBucket}-$rolelabel")

            echo -e "\n########################################################"
            echo "Checking IAM Role for replication from $SourceBucket."
            echo -e "##########################################################\n"


         if [ "$checkrole" == "${SourceBucket}-$rolelabel" ]; then

            echo -e "\n########################################################################################"
            echo "The IAM role ${SourceBucket}-$rolelabel is already present."
            echo -e "##########################################################################################\n"

         else

            echo -e "\n############################################################"
            echo "Creating IAM Role ${SourceBucket}-$rolelabel."
            echo -e "#############################################################\n"
           
            s3roletrustpolicy=$(cat $WORKSPACE/s3replication/policies/iam/S3-role-trust-policy.json) #Get policy

            # Create role with policy
            aws iam create-role --role-name ${SourceBucket}-$rolelabel \
            --assume-role-policy-document "$s3roletrustpolicy"  \
            --description "$description" --region $AWSREGION
            
            # Format permission policy
            s3rolepermissionspolicy=$(cat $WORKSPACE/s3replication/policies/iam/s3rplsource.json \
            | sed -e "s/sourcebucket/$SourceBucket/g" \
            | sed -e "s/destbucket/$DestBucket/g")

            # Put policy
            aws iam put-role-policy --role-name ${SourceBucket}-$rolelabel \
            --policy-document "$s3rolepermissionspolicy" \
            --policy-name ${SourceBucket}-S3ReplicationPolicyAUT --region $AWSREGION

         fi

#######  REPLICATION CONFIGURATION ########

rplrule="ReplicateTo-$DestBucket-$DestBucketawsalias"
checrplkrule=$(aws s3api get-bucket-replication --bucket $SourceBucket --region $AWSREGION | jq -r .ReplicationConfiguration.Rules[].ID | grep $rplrule)


            echo -e "\n########################################################"
            echo "Checking S3 replication rule for bucket $SourceBucket."
            echo -e "##########################################################\n"


         if [ "$checrplkrule" == "$rplrule" ]; then

            echo -e "\n########################################################################################"
            echo "The replication rule $rplrule is already present."
            echo -e "##########################################################################################\n"

         else

            echo -e "\n#################################################################"
            echo "Creating replication rule $rplrule for bucket $SourceBucket."
            echo -e "###################################################################\n"

               s3rplcfg=$(cat $WORKSPACE/s3replication/policies/s3/s3rplcfgrule.json \
               | sed -e "s/rplacc/${SourceBucketaawsid}/g" \
               | sed -e "s/rplroleaut/${SourceBucket}-${rolelabel}/g" \
               | sed -e "s/destbucket/$DestBucket/g" \
               | sed -e "s/rplruleaut/${rplrule}/g" \
               | sed -e "s/destaccount/$DestBucketawsid/g")


               aws s3api put-bucket-replication \
               --replication-configuration "$s3rplcfg" \
               --bucket $SourceBucket \
               --region $AWSREGION #> /dev/null



               if [ "$?" == "0" ]; then # Checks AWS exit code 0=Success 255=Failure failed

                  echo -e "\n###############################################################"
                  echo "The replication S3 rule $rplrule was created with success"
                  echo -e "#################################################################\n"

               else
                  echo -e "\n############################################################"
                  echo "FAILURE: Unable to create the S3 replication rule $rplrule at $SourceBucket bucket."
                  echo -e "#############################################################\n"
               
               exit 1
               fi
         fi

