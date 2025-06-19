#!/bin/bash

process_group() {
  local group_str="$1"
  local url="$2"
  local filename="$2"
  # Extract components from the group config
  local regex id mimetype
  IFS=',' read -r -a parts <<< "$group_str"
  for part in "${parts[@]}"; do
    case "$part" in
      regex=*)     regex="${part#regex=}";;
      id=*)        id="${part#id=}";;
      mimetype=*)  mimetype="${part#mimetype=}";;
      *)
        echo "Warning: Unrecognized part '$part' in group '$group_str'" >&2
        ;;
    esac
  done
  if [[ -z "$regex" || -z "$id" || -z "$mimetype" ]]; then
    echo "Error: Missing required keys in group: $group_str" >&2
    exit 1
  fi
  GROUP_MIMETYPES["$id"]="$mimetype"
  # regex on filename, not full URL, but save URL
  if [[ "$filename" =~ $regex ]]; then
    # Append with comma if needed
    if [[ -n "${GROUP_URLS[$id]}" ]]; then
      GROUP_URLS["$id"]+=",\"$url\""
    else
      GROUP_URLS["$id"]="\"$url\""
    fi
  fi
}

if [ "$DEBUG" == "true" ]; then
    env
    DEBUGFLAG="--debug"
fi

GROUP_ARGS=()
declare -A GROUP_URLS # key: id, value: comma-separated URLs
declare -A GROUP_MIMETYPES
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
OUTPUT="[]"

while IFS= read -r FILE; do
    echo Processing $FILE
    # set acl to $ACL
    aws $DEBUGFLAG s3api put-object-acl --region $AWS_REGION --endpoint-url $AWS_S3_ENDPOINT --bucket $BUCKET --key $BPATH/$FILE --acl $ACL
    echo Permissions set to $ACL
    # add to url array
    URL=$AWS_S3_ENDPOINT/$BUCKET/$BPATH/$FILE
    # If no group provided, create URL array (legacy mode)
    if [[ ${#GROUP_ARGS[@]} -eq 0 ]]; then
        echo "No --group parameter used, will create URLs array."
        OUTPUT=$(echo $OUTPUT | jq -r --arg URL "$URL" '. += [$URL]')
    else
        echo "--group parameter(s) used, will create output object."
        for group in "${GROUP_ARGS[@]}"; do
          process_group "$group" "$URL" "$FILE"
        done
    fi
done <<< $FILES

# write file urls to out.json
if [[ ${#GROUP_ARGS[@]} -eq 0 ]]; then
    echo "{\"urls\":$OUTPUT}" > /tmp/out.json
else
  json_input="{}"
  for id in "${!GROUP_URLS[@]}"; do
    urls="[${GROUP_URLS[$id]}]"
    mimetype="${GROUP_MIMETYPES[$id]}"

    # Use jq to add one group at a time
    json_input=$(jq --arg id "$id" \
                    --argjson urls "$urls" \
                    --arg mimetype "$mimetype" \
      '. + {($id): {urls: $urls, mimetype: $mimetype}}' <<< "$json_input")
  done
  echo "$json_input" > /tmp/out.json
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
