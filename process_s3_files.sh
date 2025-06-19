#!/bin/bash
if [ "$DEBUG" == "true" ]; then
    env
    DEBUGFLAG="--debug"
fi

GROUP_ARGS=()
# parse GROUP_ARGS arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --group)
      if [[ -n "${2-}" ]]; then
        GROUP_ARGS+=("$2")
        shift 2
      else
        echo "Error: --group requires an argument."
        exit 1
      fi
      ;;
    --group=*)
      GROUP_ARGS+=("${1#*=}")
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done
# Get last modified file in $BUCKET at $BPATH
FILES=$(aws $DEBUGFLAG s3 ls --region $AWS_REGION --endpoint-url $AWS_S3_ENDPOINT s3://$BUCKET/$BPATH/ | sort | tail -n $NUM_FILES | awk '{ print $4 }')
URL_LIST="[]"
while IFS= read -r FILE; do
    echo Processing $FILE
    # set acl to $ACL
    aws $DEBUGFLAG s3api put-object-acl --region $AWS_REGION --endpoint-url $AWS_S3_ENDPOINT --bucket $BUCKET --key $BPATH/$FILE --acl $ACL
    echo Permissions set to $ACL
    # add to url array
    URL=$AWS_S3_ENDPOINT/$BUCKET/$BPATH/$FILE
    # If no group provided, create URL array (legacy mode)
    if [[ ${#GROUP_ARGS[@]} -eq 0 ]]; then
        echo "No --group parameter supplied, will create URLs array."
        URL_LIST=$(echo $URL_LIST | jq -r --arg URL "$URL" '. += [$URL]')
    fi
done <<< $FILES

# write file url to out.json
if [[ ${#GROUP_ARGS[@]} -eq 0 ]]; then
    echo "{\"urls\":$URL_LIST}" > /tmp/out.json
fi
# store json in bucket
if [ "$PUBLISH_JSON" == "true" ]; then
    declare -n PUBLISH_JSON_FILENAME_VALUE=${PUBLISH_JSON_FILENAME_ENV_VAR}
    if [[ $PUBLISH_JSON_FILENAME_VALUE =~ $PUBLISH_JSON_FILENAME_REGEX ]]; then
        JSON_FILENAME_BASE=${BASH_REMATCH[$PUBLISH_JSON_FILENAME_REGEX_MATCH_GROUP]}
        JSON_FILEPATH=$AWS_S3_ENDPOINT/$BUCKET/$JSON_FILENAME_BASE.json
        aws $DEBUGFLAG s3 cp /tmp/out.json --region $AWS_REGION --endpoint-url $AWS_S3_ENDPOINT s3://$BUCKET/$JSON_FILENAME_BASE.json --acl $PUBLISH_JSON_ACL
    else
        echo Regex did not match for $PUBLISH_JSON_FILENAME_ENV_VAR - $PUBLISH_JSON_FILENAME_VALUE
    fi
fi
cat /tmp/out.json