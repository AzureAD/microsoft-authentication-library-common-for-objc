#!/bin/bash

for f in ~/Library/Developer/Xcode/DerivedData/IdentityCore-*/Logs/Test/Diagnostics/IdentityCoreTests-*/*; do
	bname=$(basename $f)
	echo "travis_fold:start:$bname"
	cat $f
	echo "travis_fold:end:$bname"
done
