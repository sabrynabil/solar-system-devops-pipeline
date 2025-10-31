#!/bin/bash

echo "integration test ....................."


Data=$(aws ec2 describe-instances)

echo "Data : $Data"
URL=$(aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | select(.Tags[].Value=="ec2-solar") | .PublicDnsName')
echo "URL Data -  $URL"

if [[ "$URL" != "" ]]; then
    http_code=$(curl -s -o /dev/null -w "%{http_code}" http://$URL:3030/live)
    echo "HTTP Status Code: $http_code"
    planet_data=$(curl -s -XPOST http://$URL:3030/plants -H "Content-Type: application/json" -d '{"id": "3"}')
    echo "Planet Data: $planet_data"
    planet_name=$(echo $planet_data | jq -r '.name')
    echo "Planet Name: $planet_name"
    if [[ "$http_code" -eq 200 && "$planet_name" == "Earth" ]]; then
        echo "Integration test passed."
        exit 0
    else
        echo "Integration test failed."
        exit 1
    fi

else
  echo "EC2 Instance creation failed or Public DNS not found."
  exit 1
fi