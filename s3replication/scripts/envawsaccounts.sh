#! /bin/bash
set +x

#### AWS ACCOUNTS ###

export awsaccountids="accounta accountb"

#### DEFAULT AWS REGION SET ###

while [ "$AWSREGION" == "" ]; do
    AWSREGION=us-east-1
done
