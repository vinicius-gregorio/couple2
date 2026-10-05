#!/bin/bash

# Script para criar um novo módulo Flutter seguindo a arquitetura do projeto
# Uso: ./create_module.sh <nome_do_modulo>

# Verifica se o nome do módulo foi fornecido
if [ -z "$1" ]; then
    echo "📦 Criar novo módulo Flutter"
    echo ""
    read -p "Digite o nome do módulo: " MODULE_INPUT
    
    if [ -z "$MODULE_INPUT" ]; then
        echo "❌ Erro: Nome do módulo não pode ser vazio."
        exit 1
    fi
else
    MODULE_INPUT="$1"
fi

# Converte o nome do módulo para snake_case (minúsculas com underscores)
MODULE_NAME=$(echo "$MODULE_INPUT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')

# Define o caminho base dos módulos
BASE_PATH="lib/modules/$MODULE_NAME"

# Verifica se o módulo já existe
if [ -d "$BASE_PATH" ]; then
    echo "❌ Erro: O módulo '$MODULE_NAME' já existe!"
    exit 1
fi

echo "🚀 Criando módulo: $MODULE_NAME"
echo ""

# Cria a estrutura de pastas
echo "📁 Criando estrutura de pastas..."
mkdir -p "$BASE_PATH/data"
mkdir -p "$BASE_PATH/domain"
mkdir -p "$BASE_PATH/routing"
mkdir -p "$BASE_PATH/ui"

# Cria o arquivo principal do módulo
echo "📄 Criando arquivo principal..."
touch "$BASE_PATH/$MODULE_NAME.dart"

# Cria os arquivos barrel de cada camada
echo "📄 Criando arquivos barrel..."
touch "$BASE_PATH/data/data.dart"
touch "$BASE_PATH/domain/domain.dart"
touch "$BASE_PATH/routing/routing.dart"
touch "$BASE_PATH/ui/ui.dart"

echo ""
echo "✅ Módulo '$MODULE_NAME' criado com sucesso!"
echo ""
echo "📂 Estrutura criada:"
echo "   $BASE_PATH/"
echo "   ├── ${MODULE_NAME}.dart"
echo "   ├── data/"
echo "   │   └── data.dart"
echo "   ├── domain/"
echo "   │   └── domain.dart"
echo "   ├── routing/"
echo "   │   └── routing.dart"
echo "   └── ui/"
echo "       └── ui.dart"
echo ""
echo "📝 Próximos passos:"
echo "   1. Adicionar exports no arquivo ${MODULE_NAME}.dart"
echo "   2. Implementar as camadas conforme necessário"
echo "   3. Adicionar rotas em routing/routing.dart"
echo "   4. Criar telas em ui/"
echo ""
