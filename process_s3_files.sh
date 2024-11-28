#!/bin/bash
# Get last modified file in $BUCKET at $BPATH
FILES=$(aws s3 ls --region $AWS_REGION --endpoint-url $AWS_S3_ENDPOINT s3://$BUCKET/$BPATH/ | sort | tail -n $NUM_FILES | awk '{ print $4 }')
URL_LIST="[]"
while IFS= read -r FILE; do
    echo Processing $FILE
    # set acl to $ACL
    aws s3api put-object-acl --region $AWS_REGION --endpoint-url $AWS_S3_ENDPOINT --bucket $BUCKET --key $BPATH/$FILE --acl $ACL
    echo Permissions set to $ACL
    # add to url array
    URL=$AWS_S3_ENDPOINT/$BUCKET/$BPATH/$FILE
    URL_LIST=$(echo $URL_LIST | jq -r --arg URL "$URL" '. += [$URL]')
done <<< $FILES
# write file url to out.json
echo "{\"urls\":$URL_LIST}" > /tmp/out.json
cat /tmp/out.json