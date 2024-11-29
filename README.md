# Process S3 files

Creates a json `{"urls": ["url-1", "url-2", "url-n"]}` and sets the permission to `ACL` (normally `public-read`).  
For use with argo workflows to parse generated files. The script processes `NUM_FILES` sorted by last modified, sets the acl and stores the url in the json.


The json will be printed to stdout and stored in a file at `/tmp/out.json`.  
If `PUBLISH_JSON` is set to `true` and the `PUBLISH_JSON_*` env vars are configured the result json will be uploaded to the base bucket path with the generated filename. See `docker-compose.yaml` for details.

# Environment

All environment variables listed in `docker-compose.yaml` are mandatory, except for `PUBLISH_JSON_*` if `PUBLISH_JSON=false`.