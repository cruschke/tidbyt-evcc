#!/bin/bash

# to automate the process of converting images to base64

for file in $(ls *.png); do
    BASE64=$(cat $file |  base64)
    lowercase_name=$(basename $file .png)
    NAME=$(echo $lowercase_name | tr '[:lower:]' '[:upper:]')
    export NAME
    export BASE64
    cat  template.tpl  | envsubst 
done
