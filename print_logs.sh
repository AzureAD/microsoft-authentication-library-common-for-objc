#!/bin/bash

ls -la ~/Library/Developer/Xcode/DerivedData/IdentityCore-*/Logs/Test

for f in ~/Library/Developer/Xcode/DerivedData/IdentityCore-*/Logs/Test/*/*; do
	bname=$(basename $f)
	echo "travis_fold:start:$bname"
	cat $f
	echo "travis_fold:end:$bname"
done
