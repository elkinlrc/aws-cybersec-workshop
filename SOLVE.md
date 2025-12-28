lo primero que haremos es usar el comando sudo su ubuntu para cambiar de usuario con mas privilegios
y despues cd para ubicarnos en la carpeta principal del usuario ubuntu

una vez estando ubicados en la carpeta hacer es configurar el entorno para que todo funcion en el servidor


sudo apt update && sudo apt upgrade -y 
sudo apt install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

una vez configurado el entorno procedemos a descargar los materiales que vamos a necesitar
para terraformar 

git clone https://github.com/elkinlrc/aws-cybersec-workshop
y accedemos a la carpeta de descargamos
cd aws-cybersec-workshop



terraform init

terraform plan

terraform plan -var environment=dev -var owner=$USER

terraform apply -auto-approve -var environment=dev -var owner=$USER

