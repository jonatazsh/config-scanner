#!/bin/bash

USER_AGENT="Docker-Config-Scanner"

# Identifica se o input é uma URL ou um nome de usuário
INPUT=${1}

if [ -z "$INPUT" ]; then
    echo "Uso: $0 <github-user> ou $0 <github-repo-url>"
    exit 1
fi

# Função para buscar conteúdo e escanear por segredos e versões
scan_file_content() {
    local owner=$1
    local repo=$2
    local file_path=$3
    local download_url=$4

    # Download do conteúdo bruto (raw)
    local content=$(curl -s -L -H "User-Agent: Gemini-CLI-Scanner" "$download_url")
    
    # 1. Busca por SEGREDOS (Senhas, chaves, etc)
    local secret_keywords="password|passwd|pwd|user|username|secret|key|token|auth|credentials|admin"
    local secret_matches=$(echo "$content" | grep -Ei "($secret_keywords).*[=:]" | sed 's/^[[:space:]]*//')

    if [ ! -z "$secret_matches" ]; then
        echo "    [!] POSSÍVEIS CREDENCIAIS em '$file_path':"
        echo "$secret_matches" | while read -r line; do
            echo "        -> $line"
        done
    fi

    # 2. Busca por INFRA/VERSÕES (Imagens, versões de software, kernel)
    local infra_keywords="image|version|kernel|build|distro|os|runtime|platform|engine"
    local infra_matches=$(echo "$content" | grep -Ei "($infra_keywords).*[=:]|[a-z0-9_-]+:[0-9]+\.[0-9]+|[a-z0-9_-]+:[0-9]+" | sed 's/^[[:space:]]*//' | grep -vE "^#")

    if [ ! -z "$infra_matches" ]; then
        echo "    [i] INFO DE SOFTWARE/VERSÃO em '$file_path':"
        echo "$infra_matches" | while read -r line; do
            echo "        -> ${line:0:100}"
        done
    fi
}

# Função para checar um repositório específico
check_repo() {
    local owner=$1
    local repo=$2
    echo "Analisando repositório: $owner/$repo"
    
    # Busca arquivos na raiz do repositório via API do GitHub
    local response=$(curl -s -H "Accept: application/vnd.github.v3+json" \
                 -H "User-Agent: $USER_AGENT" \
                 "https://api.github.com/repos/$owner/$repo/contents/")
    
    # Verifica erro
    local error_msg=$(echo "$response" | jq -r 'if type=="object" then .message else empty end')
    if [ ! -z "$error_msg" ] && [ "$error_msg" != "null" ]; then
        echo "  [ ERRO ] Não foi possível acessar. Mensagem: $error_msg"
        return
    fi

    # REGEX EXPANDIDA:
    # - Configs tradicionais (.json, .yaml, .conf, .ini, .properties, .toml, .xml)
    # - Arquivos de ambiente (.env, .env.production, etc)
    # - Documentação e Texto (.md, .txt)
    # - Manifestos (Dockerfile, package.json, requirements.txt, go.mod, pom.xml)
    local interest_regex="^(config\.|settings\.|application\.|.*\.json$|.*\.yaml$|.*\.yml$|.*\.conf$|.*\.ini$|.*\.properties$|.*\.toml$|.*\.xml$|Dockerfile$|requirements\.txt$|package\.json$|go\.mod$|pom\.xml$|\.env.*|.*\.md$|.*\.txt$)"
    
    local config_data=$(echo "$response" | jq -r --arg regex "$interest_regex" '.[] | select(.type == "file") | select(.name | test($regex; "i")) | "\(.name)|\(.download_url)"')

    if [ -z "$config_data" ]; then
        echo "  [ OK ] Nenhum arquivo de interesse encontrado na raiz."
    else
        echo "  [ ALERTA ] Arquivos detectados:"
        echo "$config_data" | while IFS="|" read -r name url; do
            # Se for um download_url nulo (acontece com arquivos vazios ou erros de API), pula
            if [ "$url" == "null" ]; then continue; fi
            echo "    - $name"
            scan_file_content "$owner" "$repo" "$name" "$url"
        done
    fi
    echo "--------------------------------------------------"
}

# Função para buscar repositórios de um usuário
check_user_repos() {
    local user=$1
    echo "Buscando repositórios públicos do usuário: $user"
    
    local repos_json=$(curl -s -H "Accept: application/vnd.github.v3+json" \
                         -H "User-Agent: Gemini-CLI-Scanner" \
                         "https://api.github.com/users/$user/repos?per_page=100")

    # Verifica erro
    local error_msg=$(echo "$repos_json" | jq -r 'if type=="object" then .message else empty end')
    if [ ! -z "$error_msg" ] && [ "$error_msg" != "null" ]; then
        echo "  [ ERRO ] Usuário não encontrado ou limite de API atingido. ($error_msg)"
        return
    fi

    local repos=$(echo "$repos_json" | jq -r '.[].full_name')
    
    if [ -z "$repos" ] || [ "$repos" == "null" ]; then
        echo "Nenhum repositório público encontrado para o usuário $user."
        return
    fi

    for full_repo in $repos; do
        local owner=$(echo $full_repo | cut -d'/' -f1)
        local repo=$(echo $full_repo | cut -d'/' -f2)
        check_repo "$owner" "$repo"
    done
}

# Lógica de detecção de input
if [[ $INPUT =~ ^https?://github\.com/([^/]+)/([^/]+)/?$ ]]; then
    OWNER=${BASH_REMATCH[1]}
    REPO=${BASH_REMATCH[2]}
    REPO=${REPO%.git}
    check_repo "$OWNER" "$REPO"
elif [[ $INPUT =~ ^https?://github\.com/([^/]+)/?$ ]]; then
    USER=${BASH_REMATCH[1]}
    check_user_repos "$USER"
elif [[ $INPUT =~ ^[^/]+$ ]]; then
    check_user_repos "$INPUT"
else
    echo "Formato de input inválido."
    exit 1
fi
