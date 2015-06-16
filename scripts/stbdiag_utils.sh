upload_to_dropbox() {
    upload_path=$1
    local_fully_qualified_filename=$2
    curl -H "Authorization: Bearer zf_DdnPHb5AAAAAAAAAADT9lSd93RJy3HeBShWgENMgso_IYW9Cu48XN6E4PCg15" https://api-content.dropbox.com/1/files_put/auto/$upload_path/ -T $local_fully_qualified_filename >> /dev/null 2>&1
    echo "File $fully_qualified_filename uploaded to QA Dropbox Account."
}


