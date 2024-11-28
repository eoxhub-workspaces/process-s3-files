# Process S3 files

Creates a json `{"urls": ["url-1", "url-2", "url-n"]}` and sets the permission to `ACL` (normally `public-read`).  
For use with argo workflows to parse generated files. The script processes `NUM_FILES` sorted by last modified, sets the acl and stores the url in the json.


The json will be printed to stdout and stored in a file at `/tmp/out.json`.