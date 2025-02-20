
# Creación de una clave SSH #############################################
resource "aws_key_pair" "deployer-key" {
  key_name      = "${var.project_name}-deployer-key"  # Nombre de la clave
  public_key    = file(var.ssh_key_path)              # Ruta de la clave pública
}

# Creación de un volumen EBS #############################################
resource "aws_ebs_volume" "web" {
  availability_zone = var.availability_zone     # Zona de disponibilidad donde se crea el volumen: eu-west-3a
  size              = 4                         # 4 GB
  type              = "gp3"                     # General Purpose SSD  (gp3)
  encrypted         = true                      # Encrypt the volume
  tags = {
    Name = "${var.project_name}-web-ebs"        # Nombre del volumen
  }
}

# Creación de un grupo de seguridad #####################################
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_${var.project_name}"          # Nombre del grupo de seguridad
  description = "Allow SSH inbound traffic"              # Descripción del grupo de seguridad
  vpc_id      = var.vpc_id                               # VPC donde se crea el grupo de seguridad

  ingress {
    description = "SSH from VPC ${var.project_name}"     # Descripción de la regla de entrada
    from_port   = 22                                     # Puerto de origen                  
    to_port     = 22                                     # Puerto de destino               
    protocol    = "tcp"                                  # Protocolo de transporte
    cidr_blocks = ["0.0.0.0/0"]                          # Dirección IP de origen       
  }

  egress {
    from_port   = 0                                      # Puerto de origen
    to_port     = 0                                      # Puerto de destino
    protocol    = "-1"                                   # Protocolo de transporte
    cidr_blocks = ["0.0.0.0/0"]                          # Dirección IP de destino
  }

  tags = {                                               # Etiquetas del grupo de seguridad
    Name = "allow_ssh"                                   # Nombre del grupo de seguridad
  }
}

# Creación de un grupo de seguridad #####################################
resource "aws_security_group" "allow_http" {
    name        = "allow_http-${var.project_name}"
    description = "Allow http inbound traffic"
    vpc_id      = var.vpc_id

    ingress {
      description = "http from VPC"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "allow_http"
    }
  }

# Tamaño máximo de 16kB para el script de usuario especificado en la documentación de Terraform
// 16kB tamaño maximo
# data "template_file" "userdata" {
#   template = file("${path.module}/userdata.sh")
# }


# Creación de una instancia EC2 ##########################################
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id                      # ID de la AMI
  availability_zone = var.availability_zone                   # Zona de disponibilidad
  instance_type = var.instance_type                           # Tipo de instancia
  vpc_security_group_ids = [                                  # Grupos de seguridad
    aws_security_group.allow_ssh.id,                          
    aws_security_group.allow_http.id                       
  ]
  user_data = templatefile(                                   # Script de usuario
    "${path.module}/userdata.sh",                             # Ruta del script que se ejecutará al arrancar la instancia
    # variables para la plantilla                             # Variables que se pasan al script
    # { port = 8080, ip_addrs = ["10.0.0.1", "10.0.0.2"] }
    {}
  )
  key_name      = aws_key_pair.deployer-key.key_name          # Nombre de la clave SSH
  tags          = {
    Name = "${var.project_name}-web-instance"                 # Nombre de la instancia
  }
}



# Asociación de una IP elástica a la instancia EC2 ######################
resource "aws_eip" "eip" {
  instance      = aws_instance.web.id                        # ID de la instancia
  # corrección de deprecated   
  domain        = "vpc"                                      # Tipo de IP elástica
  # vpc         = true 
  tags          = {
    Name        = "${var.project_name}-web-epi"              # Nombre de la IP elástica
  }
}

# Asociación de un volumen EBS a la instancia EC2 ######################
resource "aws_volume_attachment" "web" {
  device_name = "/dev/sdh"                                  # Nombre del dispositivo
  volume_id   = aws_ebs_volume.web.id                       # ID del volumen
  instance_id = aws_instance.web.id                         # ID de la instancia
}





