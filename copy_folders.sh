#!/bin/bash

DEST="/mnt/c/Program Files/Ascension Launcher/resources/client/Interface/AddOns"

for dir in */; do
    echo "Copying $dir to $DEST"
    cp -r "$dir" "$DEST/"
done
