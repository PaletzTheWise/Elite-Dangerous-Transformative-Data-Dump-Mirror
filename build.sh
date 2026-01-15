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

haxe build.hxml

echo Compilation done.
	
package_params=()
if [[ $deploy_locally == true ]]; then
    package_params+="-l $local_deployment_path"
fi
./package.sh ${package_params[@]}
	
echo Build done.
