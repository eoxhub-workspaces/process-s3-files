# Process S3 files

For use with argo workflows to parse generated files. The script processes `NUM_FILES` sorted by last modified, sets the acl and stores the url in the json.

## Types of output 

a) No command line parameters `./process_s3_files.sh` Creates a json `{"urls": ["url-1", "url-2", "url-n"]}`

b) Possible to add multiple `--group` parameters in format `--group "regex=harshness.*,id=output_1,mimetype=image/tiff"`
which will output an object 
```json
{
  "output_1":{
    "urls":[
      "url1",
      "url2"
    ],
    "mimetype":"image/tiff"
  },
  "output_2":{
    "urls":[
      "url3"
    ],
    "mimetype":"image/tiff"
  }
}
```

Script also sets the permission to `ACL` (normally `public-read`).  

The json will be printed to stdout and stored in a file at `/tmp/out.json`.  
If `PUBLISH_JSON` is set to `true` and the `PUBLISH_JSON_*` env vars are configured the result json will be uploaded to the base bucket path with the generated filename. See `docker-compose.yaml` for details.

# Environment

All environment variables listed in `docker-compose.yaml` are mandatory, except for `PUBLISH_JSON_*` if `PUBLISH_JSON=false`.
