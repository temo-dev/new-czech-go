# Bootstrap A Fresh EC2 ARM Host

## Purpose
This doc is for the case where your EC2 instance is still almost empty:
- ARM / `arm64`
- no Docker yet
- no Docker Compose plugin yet
- no AWS CLI yet

It prepares the host for the deployment flow already documented in:
- [deploy-ec2-nginx-proxy.md](/Users/daniel.dev/Desktop/czech-go-system/docs/deploy-ec2-nginx-proxy.md)
- [deploy-first-release-checklist.md](/Users/daniel.dev/Desktop/czech-go-system/docs/deploy-first-release-checklist.md)

## Files You Will Use
- [docker-compose.proxy.yml](/Users/daniel.dev/Desktop/czech-go-system/docker-compose.proxy.yml)
- [docker-compose.ec2.yml](/Users/daniel.dev/Desktop/czech-go-system/docker-compose.ec2.yml)
- [scripts/check-ec2-host.sh](/Users/daniel.dev/Desktop/czech-go-system/scripts/check-ec2-host.sh)
- [scripts/check-ec2-env.sh](/Users/daniel.dev/Desktop/czech-go-system/scripts/check-ec2-env.sh)
- [scripts/package-ec2-deploy.sh](/Users/daniel.dev/Desktop/czech-go-system/scripts/package-ec2-deploy.sh)
- [.env.ec2.example](/Users/daniel.dev/Desktop/czech-go-system/.env.ec2.example)

## Recommended Shape
For this project, the simplest production shape remains:
- one ARM EC2 host
- `nginxproxy/nginx-proxy`
- `nginxproxy/acme-companion`
- one `backend` container
- one `cms` container
- `RDS` outside Docker
- `ECR` for versioned images

## Decide The Base OS
Use one of these:
- `Amazon Linux 2023 arm64`
- `Ubuntu 24.04 arm64`

If you have not launched the instance yet, I recommend `Amazon Linux 2023` because it fits AWS defaults well and keeps the bootstrap short.

## Common First Steps
After SSH in:

```bash
uname -m
cat /etc/os-release
```

Expected architecture:

```bash
aarch64
```

## Path A: Amazon Linux 2023 ARM
AWS documentation shows this path for installing Docker on Amazon Linux 2023:
- `sudo yum update -y`
- `sudo yum install -y docker`
- `sudo service docker start`
- `sudo usermod -a -G docker ec2-user`

Run:

```bash
sudo yum update -y
sudo yum install -y docker unzip curl
sudo service docker start
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user
```

Reconnect your SSH session after adding the user to the `docker` group.

Verify:

```bash
docker info
```

### Docker Compose Plugin
If `docker compose version` already works, keep it.

If not, Docker's Linux plugin docs say RPM-based systems can install:

```bash
sudo yum update
sudo yum install docker-compose-plugin
```

Then verify:

```bash
docker compose version
```

## Path B: Ubuntu ARM
Docker's Ubuntu docs support `arm64` and recommend installing from Docker's apt repository.

Run:

```bash
sudo apt update
sudo apt install -y ca-certificates curl unzip
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -a -G docker $USER
```

Reconnect your SSH session, then verify:

```bash
docker info
docker compose version
```

## Install AWS CLI On ARM
AWS CLI v2 provides an ARM installer for Linux.

Run:

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

If you are updating an existing install:

```bash
sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
```

## Authenticate AWS CLI
Choose one:
- `aws configure`
- or attach an instance role with ECR access

Minimum AWS abilities needed for the current flow:
- pull from `ECR`
- optional later: access `S3` and `Transcribe`

## Prepare The App Folder
Preferred flow: build a deploy bundle on your workstation, then copy it to the EC2 host.

On your workstation:

```bash
make package-ec2-deploy EC2_ENV_FILE=.env.ec2
scp dist/czech-go-system-ec2-deploy.tar.gz ec2-user@<ec2-host>:~/
```

On EC2:

```bash
mkdir -p ~/czech-go-system
cd ~/czech-go-system
tar -xzf ~/czech-go-system-ec2-deploy.tar.gz --strip-components=1
```

If you prefer not to use the bundle script, copy these files into the folder manually:
- `docker-compose.proxy.yml`
- `docker-compose.ec2.yml`
- `scripts/check-ec2-host.sh`
- `scripts/check-ec2-env.sh`
- `scripts/ecr-login.sh`
- `scripts/deploy-ec2.sh`
- `.env.ec2`

## Bring Up The Reverse Proxy
Because your EC2 host is fresh, `nginx-proxy` and `acme-companion` are not there yet.

You already have a working pattern for this from your Odoo stack. The repo now also includes a minimal proxy bootstrap stack if you want a clean starting point on the fresh host.

Render it first:

```bash
docker compose --env-file .env.ec2 -f docker-compose.proxy.yml config
```

Bring it up:

```bash
docker compose --env-file .env.ec2 -f docker-compose.proxy.yml up -d
```

Inspect:

```bash
docker compose --env-file .env.ec2 -f docker-compose.proxy.yml logs --tail=100
docker network ls
```

The important outcome is:
- ports `80` and `443` are owned by the proxy stack
- the proxy stack is connected to Docker network `proxy`

## Preflight
Check the host itself first:

```bash
sh scripts/check-ec2-host.sh .env.ec2
```

Then validate the app env:

```bash
sh scripts/check-ec2-env.sh .env.ec2
```

Confirm the ECR repositories exist:

```bash
aws ecr describe-repositories --region eu-central-1 --repository-names czech-go-system-backend czech-go-system-cms
```

If you do not have the repo checked out on the EC2 host, run the script directly from the copied project folder:

```bash
sh scripts/check-ec2-host.sh .env.ec2
sh scripts/check-ec2-env.sh .env.ec2
```

## Deploy
Then continue with the normal flow:

```bash
sh scripts/ecr-login.sh .env.ec2
sh scripts/deploy-ec2.sh .env.ec2
```

## First Verification
After deploy:

```bash
docker compose --env-file .env.ec2 -f docker-compose.ec2.yml ps
docker compose --env-file .env.ec2 -f docker-compose.ec2.yml logs --tail=100
curl -I https://apicz.hadoo.eu/healthz
curl -I https://cmscz.hadoo.eu/api/healthz
```

## Current Known Warnings
For your current `.env.ec2`, preflight still warns that:
- `TRANSCRIBER_PROVIDER=dev`
- `ATTEMPT_UPLOAD_PROVIDER=local`
- `CMS_ADMIN_TOKEN=dev-admin-token`
- `CMS_BASIC_AUTH_PASSWORD=change-me` or the CMS basic-auth envs are empty

That is acceptable for the first deploy, but not the final hardened production shape.

## References
Official references used for this bootstrap:
- [Docker Engine install on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [Docker Compose plugin on Linux](https://docs.docker.com/compose/install/linux/)
- [AWS CLI install on Linux ARM](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [AWS note for installing Docker on Amazon Linux 2023](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-docker.html)
