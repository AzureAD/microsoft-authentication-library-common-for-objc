#!/bin/bash

for f in ~/Library/Developer/Xcode/DerivedData/IdentityCore-*/Logs/Test/Diagnostics/IdentityCoreTests-*/*; do
	bname=$(basename $f)
	echo "##[group]$bname"
	cat $f
	echo "##[endgroup]$bname"
done
