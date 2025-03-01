#!/usr/bin/env bash

# if there is a env file, source it
if [ -f "./.env" ]; then
   source ./.env
# source example else
else
   source ./.env.example
fi

# enabled repositories for the build
REPOSITORIES=$1

# enable all repositories if any specified
if [[ -z $REPOSITORIES ]]; then
    REPOSITORIES=$ALL_REPOSITORIES
fi

# for returning later to the main directory
ROOT_DIRECTORY=`pwd`

# function for building images
function build_repository {
    # read repository configuration
    source $ROOT_DIRECTORY/$REPOSITORY/buildvars

    # build all enabled versions
    for TAG in $TAGS; do
      # Check if any file has been modified in the directory
      if git diff --quiet HEAD^ HEAD -- $REPOSITORY/$TAG; then
        echo "$REPOSITORY/$TAG has not changed. Skipping build."
        continue
      fi

      # some verbose
      echo $'\n\n'"# Building $NAMESPACE/$REPOSITORY:$TAG"$'\n'
      cd $ROOT_DIRECTORY/$REPOSITORY/$TAG

      if [ $USE_CACHE == true ]; then
        # build using cache
        docker build -t $NAMESPACE/$REPOSITORY:$TAG .
      fi

      if [ $USE_CACHE == false ]; then
        docker build --no-cache=true -t $NAMESPACE/$REPOSITORY:$TAG .
      fi

      # if this tag is the latest, create the latest tag
      if [[ "$TAG" == "$LATEST" ]]; then
        echo $'\n\n'"# Aliasing $LATEST as 'latest'"$'\n'
        docker tag $NAMESPACE/$REPOSITORY:$LATEST $NAMESPACE/$REPOSITORY:latest
      fi
    done
}

# function for publishing images
function publish_repository {
    # read repository configuration
    source $ROOT_DIRECTORY/$REPOSITORY/buildvars

    # publish all enabled versions
    for TAG in $TAGS; do
      # Check if any file has been modified in the directory
      if git diff --quiet HEAD^ HEAD -- $REPOSITORY/$TAG; then
        echo "$REPOSITORY/$TAG has not changed. Skipping push."
        continue
      fi

      # some verbose
      echo $'\n\n'"# Publishing $NAMESPACE/$REPOSITORY:$TAG"$'\n'
      # publish
      docker push $NAMESPACE/$REPOSITORY:$TAG

      # if this tag is the latest, push the latest tag
      if [[ "$TAG" == "$LATEST" ]]; then
        echo $'\n\n'"# Publishing $NAMESPACE/$REPOSITORY:latest (from $LATEST)"$'\n'
        docker push $NAMESPACE/$REPOSITORY:latest
      fi
    done
}

# for each enabled repository
for REPOSITORY in $REPOSITORIES; do
  # build the repository
  build_repository $REPOSITORY

  # If publishing is enabled
  if [ $PUBLISH == true ]; then
    # Push the built image
    publish_repository $REPOSITORY
  fi
done
