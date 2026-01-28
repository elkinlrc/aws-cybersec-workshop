# 💻 Capa de Computación - Despliegue seguro
resource "aws_launch_template" "app_template" {
  name_prefix   = "${var.prefix}-app-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  # ETIQUETAS DEL LAUNCH TEMPLATE (nivel recurso) - ¡ESTO FALTABA!
  tags = {
    proyecto = "cybersec"
    funcion  = "computacion"
    Name     = "${var.prefix}-launch-template"
  }

  iam_instance_profile {
    name = "LabInstanceProfile"
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.appsg.id]
  }

  # UserData SIMPLIFICADO (< 16KB)
  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y python3 python3-pip

              cat > /home/ubuntu/app.py << 'EOL'
              from flask import Flask, jsonify
              app = Flask(__name__)

              @app.route('/')
              def index():
                  return "Workshop Ciberseguridad AWS"

              @app.route('/health')
              def health():
                  return jsonify({"status": "healthy", "service": "pokemon-api"})

              @app.route('/pokemon')
              def pokemon():
                  return jsonify([
                      {"id": 25, "name": "Pikachu", "type": "Electric", "hp": 35},
                      {"id": 6, "name": "Charizard", "type": "Fire/Flying", "hp": 78},
                      {"id": 3, "name": "Venusaur", "type": "Grass/Poison", "hp": 80}
                  ])

              if __name__ == '__main__':
                  app.run(host='0.0.0.0', port=8080, debug=False)
              EOL

              pip3 install flask

              # Crear servicio systemd para que la app persista
              cat > /etc/systemd/system/pokemon-app.service << 'EOL'
              [Unit]
              Description=Pokemon Workshop Application
              After=network.target

              [Service]
              Type=simple
              User=root
              WorkingDirectory=/home/ubuntu
              ExecStart=/usr/bin/python3 /home/ubuntu/app.py
              Restart=always

              [Install]
              WantedBy=multi-user.target
              EOL

              # Iniciar servicio
              systemctl daemon-reload
              systemctl enable pokemon-app.service
              systemctl start pokemon-app.service

              # Esperar y verificar
              sleep 5
              curl -f http://localhost:8080/health || echo "App iniciada"

              echo "✅ Aplicación desplegada en $(hostname)"
              EOF
  )

  # Etiquetas que se propagarán a las instancias (tag_specifications)
  tag_specifications {
    resource_type = "instance"

    tags = {
      proyecto = "cybersec"
      funcion  = "computacion"
      Name     = "${var.prefix}-app-instance"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      proyecto = "cybersec"
      funcion  = "computacion"
    }
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name               = "${var.prefix}-app-asg"
  vpc_zone_identifier = module.vpc.private_subnets

  min_size         = 2
  max_size         = 2
  desired_capacity = 2
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app_template.id
    version = "$Latest"
  }

target_group_arns = [aws_lb_target_group.maintg.arn]

  # Etiquetas que se propagarán a las instancias del ASG
  tag {
    key                 = "proyecto"
    value               = "cybersec"
    propagate_at_launch = true
  }

  tag {
    key                 = "funcion"
    value               = "computacion"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.prefix}-app-instance"
    propagate_at_launch = true
  }
}

# Recurso para verificar las etiquetas (opcional - solo para debug)
resource "null_resource" "verify_tags" {
  depends_on = [aws_launch_template.app_template]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Verificando etiquetas del Launch Template..."
      aws ec2 describe-launch-templates \
        --launch-template-ids ${aws_launch_template.app_template.id} \
        --query 'LaunchTemplates[0].Tags' \
        --output table
    EOT
  }
}


