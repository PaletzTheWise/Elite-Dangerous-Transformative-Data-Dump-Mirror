#!/bin/bash

trap 'echo "An error occurred in $0. Exiting..."; exit 1;' ERR

deploy_locally=false
local_deployment_path=""
while getopts 'l:' option; do
    case "$option" in
	l)
	    deploy_locally=true
	    local_deployment_path=$OPTARG
	;;
	\?)
		echo "Usage %s: [-l]"
		exit 1
	;;
	esac
done

script_dir="$(dirname "$0")"
script_dir="$(realpath "$script_dir")"
cd "$script_dir"

rm -rf "release"

mkdir -p "release/source"
mkdir -p "release/lib"

cp -r -t "release/source" *.sh .git .gitignore .github *.hxml *.md COPYING.txt COPYING.LESSER.txt edsm.systemsPopulated.sample.json.gz src
cp -r -t "release/lib" "bin/lib/"*
cp -t "release" "bin/index.php"
cp -t "release" edsm.systemsPopulated.sample.json.gz

branch=$(git rev-parse --abbrev-ref HEAD)
commitCount=$(git rev-list --count $branch)
commitHash=$(git rev-parse HEAD)
echo "$branch-$commitCount-$commitHash" > "release/version.txt"

cd release/
zip -r "EliteDangerousTransformativeDataDumpMirror.zip" *
cd "$script_dir"

# local deployment
if [[ $deploy_locally == true ]]; then
    unzip -o -d "$local_deployment_path" "release/EliteDangerousTransformativeDataDumpMirror.zip"

	echo "Local deployment done."
fi

echo Packaging done.