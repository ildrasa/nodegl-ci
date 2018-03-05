#!/bin/bash

# clean previous results
rm -rf ./cov-int.tgz ./test-results

echo "manage docker image"
# check if docker image is already built
if [[ "$(docker images -q nodegl:CI 2> /dev/null)" == "" ]]; then
	echo "docker image nodegl:CI not built yet; will be built"
	docker build -f nodegl-dockerfile -t nodegl:CI .
fi


echo "manage docker volumes"
# get "coverity" docker volume path; create it if it does not exists yet
COVERITY_PATH=$(docker volume inspect --format '{{ .Mountpoint }}' coverity)
if [[ -z "$COVERITY_PATH" ]]; then
	echo "Docker volume 'coverity' not found. It will de be created"
	docker volume create coverity
	COVERITY_PATH=$(docker volume inspect --format '{{ .Mountpoint }}' coverity)
	echo "untar coverity into volume 'coverity' "
	# untar coverity into coverity volume
	tar -xvzf cov.tgz -C $COVERITY_PATH
fi
echo "Docker volume 'coverity' found at $COVERITY_PATH."


# get "build-script" docker volume path; create it if it does not exists yet
BUILD_SCRIPT_PATH=$(docker volume inspect --format '{{ .Mountpoint }}' build-script)
if [[ -z "$BUILD_SCRIPT_PATH" ]]; then
	echo "Docker volume 'build-script' not found. It will de be created"
	docker volume create build-script
	BUILD_SCRIPT_PATH=$(docker volume inspect --format '{{ .Mountpoint }}' build-script)
	# copy nodegl build script into build-script volume and give it execution rights
	echo "copy cnodegl build script into volume 'build-script' "
	cp nodegl-build.sh $BUILD_SCRIPT_PATH
	chmod -x $BUILD_SCRIPT_PATH/nodegl-build.sh
fi
echo "Docker volume 'build-script' found at $BUILD_SCRIPT_PATH."

# start docker container used for build and running tests
echo "start container"
docker run -d --name nodegl-build -t --mount source=coverity,destination=/home/root/coverity --mount source=build-script,destination=/home/root/build-script nodegl:CI

# launch build and tests
echo "launch build and test on container"
docker exec --workdir /home/root/build-script nodegl-build sh nodegl-build.sh

# get results from docker volumes
echo "recover test results artifacts"
cp -R $COVERITY_PATH/cov-int .
cp -R $BUILD_SCRIPT_PATH/tests-results .
tar cvzf cov-int.tgz cov-int

# clean for next run
echo "clean build artifacts"
docker stop nodegl-build
docker rm nodegl-build
rm -rf $COVERITY_PATH/cov-int $BUILD_SCRIPT_PATH/test-results ./cov-int

