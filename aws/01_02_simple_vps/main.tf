# Configuración del proveedor de AWS
provider "aws" {
  region = "eu-west-3" # Región donde se desplegarán los recursos (París)
}




# Data source para obtener la AMI de Ubuntu más reciente ##################################################
data "aws_ami" "ubuntu" {
  most_recent = true # Se selecciona la AMI más reciente que cumpla los filtros

  # Filtro para que el nombre de la AMI coincida con el patrón especificado
  filter {
    name   = "name"
    # values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]  # Otro patrón (comentado)
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"] # Patrón para la búsqueda
  }

  # Filtro para seleccionar solo imágenes que usan EBS como dispositivo raíz
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  # Filtro para seleccionar imágenes que usan virtualización HVM
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Limita la búsqueda a imágenes propiedad de Canonical (ID: 099720109477)
  owners = ["099720109477"]
}



# Declaración de variables para parametrizar la configuración ##################################################

# Ruta al archivo que contiene la clave pública SSH
variable "ssh_key_path" {
  type = string
}

# Ruta al archivo que contiene la clave privada SSH
variable "ssh_key_private_path" {
  type = string
}

# ID de la VPC donde se crearán los recursos
variable "vpc_id" {
  type = string
}

# Nombre del proyecto (valor por defecto: "profe")
variable "project_name" {
  type    = string
  default = "profe"
}

# Recurso para crear un key pair en AWS que servirá para acceder a la instancia por SSH ##################################################
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key-ubuntu-${var.project_name}" # Nombre del key pair que incluye el nombre del proyecto
  public_key = file(var.ssh_key_path) # Lee el contenido del archivo de la clave pública
}

# Recurso para crear un grupo de seguridad que permita el acceso SSH a la instancia ##################################################
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh-${var.project_name}" # Nombre del grupo de seguridad
  description = "Allow SSH inbound traffic"       # Descripción del grupo
  vpc_id      = var.vpc_id                        # Asocia el grupo de seguridad a la VPC especificada

  # Regla de entrada: permite conexiones SSH (puerto 22) desde cualquier IP
  ingress {
    description = "SSH from VPC"
    from_port   = 22     # Puerto de inicio (SSH)
    to_port     = 22     # Puerto final (SSH)
    protocol    = "tcp"  # Protocolo TCP
    cidr_blocks = ["0.0.0.0/0"] # Permite acceso desde cualquier dirección IP
  }

  # Regla de salida: permite todo el tráfico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # "-1" significa todos los protocolos
    cidr_blocks = ["0.0.0.0/0"] # Permite salida hacia cualquier dirección IP
  }

  # Etiquetas para identificar el recurso
  tags = {
    Name = "allow_ssh"
  }
}

# Recurso para crear una instancia EC2 en AWS ##################################################
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id      # Utiliza la AMI de Ubuntu obtenida del data source
  instance_type = "t3.micro"                   # Tipo de instancia (adecuada para pruebas o cargas ligeras)
  key_name      = aws_key_pair.deployer.key_name # Asocia la instancia con el key pair creado
  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id          # Asocia el grupo de seguridad que permite SSH
  ]
  tags = {
    Name = "HelloWorld-${var.project_name}"  # Etiqueta que identifica la instancia
  }

  # Provisioner que se ejecuta en la máquina local (donde se lanza Terraform)
  provisioner "local-exec" {
    command = "echo The ssh id is ${self.id}" # Muestra en la consola el ID de la instancia
  }
  
  # Configuración de conexión SSH para los provisioners remotos
  connection {
    type        = "ssh"                                     # Se establece conexión por SSH
    user        = "ubuntu"                                  # Usuario para conectarse a la instancia (por defecto en Ubuntu)
    host        = self.public_ip                            # Utiliza la IP pública de la instancia
    private_key = file(var.ssh_key_private_path)            # Lee la clave privada desde el archivo especificado
    #agent      = true                                      # Permite usar el agente SSH   
  }

  # Provisioner que se ejecuta de forma remota en la instancia EC2
  provisioner "remote-exec" {
    inline = [
      "echo hola >> fichero.txt" # Ejecuta el comando que añade "hola" al archivo "fichero.txt" en la instancia
    ]
  }
}

# Outputs para mostrar información relevante tras el despliegue ##################################################

# Muestra la dirección IP pública de la instancia EC2
output "ip_instance" {
  value = aws_instance.web.public_ip
}

# Proporciona un comando de ejemplo para conectarse a la instancia vía SSH
output "ssh" {
  value = "ssh -l ubuntu ${aws_instance.web.public_ip}"
}
