#!/bin/bash
# deploy.sh

echo "🚀 Iniciando despliegue..."

# INIT
echo "1. terraform init..."
terraform init || { echo "❌ Init falló"; exit 1; }

# PLAN  
echo "2. terraform plan..."
terraform plan -out=tfplan || { 
    echo "❌ Plan falló - Destruyendo..."; 
    terraform destroy -auto-approve; 
    exit 1; 
}

# APPLY
echo "3. terraform apply..."
terraform apply tfplan || { 
    echo "❌ Apply falló - Destruyendo..."; 
    terraform destroy -auto-approve; 
    exit 1; 
}

# ÉXITO
echo "✅ ¡Listo!"
terraform output
rm -f tfplan