#!/bin/bash

cd IdentityCore/src
rm -r public
mkdir public
cd public
find ../ -type f -name "*.h" -maxdepth 10 -print0 | while read -d $'\0' file
do
    ln -s $file $basename
done
