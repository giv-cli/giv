#!/bin/sh
curl -s https://api.github.com/repos/giv-cli/giv/releases \
    | awk -F'"' '/"tag_name":/ {print $4}'
exit 0