#!/bin/bash -e

if [[ $# -ne 1 ]]; then
  echo "usage: $0 S3_BUCKET_NAME" >&2
  exit 1
fi

rm /tmp/artifact.zip
pushd artifact
zip -r ../artifact.zip *
popd
aws s3 cp artifact.zip s3://$1/test/devops-playgound.zip

aws deploy register-application-revision --application-name devops-playground --s3-location bucket=$1,bundleType=zip,key=test/devops-playground.zip --region ap-southeast-1
