#!/bin/bash

region='us-east-2'
aws_secret='hashilab'

sudo apt update
sudo apt install -y jq python3
curl -O https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py
pip install awscli

jump_cloud_key="$(aws --output json --region us-east-2 secretsmanager get-secret-value --secret-id $aws_secret | jq -r .SecretString | jq -r '."jump-cloud"')"

curl --tlsv1.2 --silent --show-error --header "x-connect-key: ${jump_cloud_key}" https://kickstart.jumpcloud.com/Kickstart | sudo bash
