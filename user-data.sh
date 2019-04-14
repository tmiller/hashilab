#!/bin/bash

set -e
set -o pipefail

aws_secret='hashilab'
aws_region='us-east-2'
CONSUL_VERSION='1.4.4'

sudo apt update
sudo apt install -y jq python zip
curl -O https://bootstrap.pypa.io/get-pip.py
python get-pip.py
pip install awscli

consul_encryption_key="$(aws --region ${aws_region} --output json secretsmanager get-secret-value --secret-id $aws_secret | jq -r .SecretString | jq -r '."consul-encryption-key"')"
jump_cloud_key="$(aws --region ${aws_region} --output json secretsmanager get-secret-value --secret-id $aws_secret | jq -r .SecretString | jq -r '."jump-cloud"')"
curl --tlsv1.2 --silent --show-error --header "x-connect-key: ${jump_cloud_key}" https://kickstart.jumpcloud.com/Kickstart | sudo bash

curl --silent --remote-name https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
curl --silent --remote-name https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS
curl --silent --remote-name https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS.sig

# Install consul
unzip consul_${CONSUL_VERSION}_linux_amd64.zip
sudo chown root:root consul
sudo mv consul /usr/local/bin

sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo chown --recursive consul:consul /opt/consul

cat <<EOF | sudo tee /etc/systemd/system/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/local/bin/consul reload
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo mkdir --parents /etc/consul.d
sudo touch /etc/consul.d/consul.hcl
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/consul.hcl

cat <<EOF | sudo tee -a /etc/consul.d/consul.hcl
datacenter = "dc1"
data_dir = "/opt/consul"
encrypt = "${consul_encryption_key}"
retry_join = ["provider=aws tag_key=consul"]
EOF

sudo mkdir --parents /etc/consul.d
sudo touch /etc/consul.d/server.hcl
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/server.hcl

cat <<EOF | sudo tee -a /etc/consul.d/server.hcl
server = true
bootstrap_expect = 3
ui = true
EOF

sudo systemctl enable consul
sudo systemctl start consul
sudo systemctl status consul
