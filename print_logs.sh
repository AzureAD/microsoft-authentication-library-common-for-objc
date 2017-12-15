#!/bin/bash

ls -la ~/Library/Developer/Xcode/DerivedData/IdentityCore-*/Logs/Test/Diagnostics

for f in ~/Library/Developer/Xcode/DerivedData/IdentityCore-*/Logs/Test/*/*/Diagnostics; do
	bname=$(basename $f)
	echo "travis_fold:start:$bname"
	cat $f
	echo "travis_fold:end:$bname"
done
