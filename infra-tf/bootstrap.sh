
sudo apt-get remove docker docker-engine docker.io

sudo apt-get update

sudo apt-get upgrade -y

sudo apt install docker.io -y

sudo systemctl start docker

sudo systemctl enable docker


# Run NGINX Docker container
# sudo docker run -d -p 80:80 --name nginx nginx:latest
docker run -it -d -p 80:8001 --name bikeshare-fastapi-container ravikumarbgdocker/bikeshare-fastapi:latest