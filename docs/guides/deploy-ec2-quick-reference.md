## Hướng local

sed -i.bak 's/^IMAGE_TAG=.*/IMAGE_TAG=20260506-01/' .env.ec2
make release-images EC2_ENV_FILE=.env.ec2                   
make package-ec2-deploy EC2_ENV_FILE=.env.ec2 
scp -i czech-app-key.pem dist/czech-go-system-ec2-deploy.tar.gz ec2-user@ec2-35-156-93-163.eu-central-1.compute.amazonaws.com:~/

ssh -i "czech-app-key.pem" ec2-user@ec2-35-156-93-163.eu-central-1.compute.amazonaws.com

## trên ec2
cd ~/czech-go-system                                                                  
sh scripts/ecr-login.sh .env.ec2 
tar -xzf ~/czech-go-system-ec2-deploy.tar.gz --strip-components=1                                                  
sh scripts/deploy-ec2.sh .env.ec2                                                                              
docker ps

## trên rds
docker run -it --rm postgres:16-alpine psql \
 "host=database-odoo-2.cvundtaezu15.eu-central-1.rds.amazonaws.com port=5432 user=odoo dbname=postgres sslmode=require"

### kiểm tra connection
SELECT count(*), usename
FROM pg_stat_activity
GROUP BY usename
ORDER BY count DESC;

SELECT
  datname,
  usename,
  client_addr,
  application_name,
  state,
  count(*)
FROM pg_stat_activity
GROUP BY datname, usename, client_addr, application_name, state
ORDER BY count(*) DESC;


