# GitHub Config Scanner & Secret Hunter 🛡️🔍

Este projeto contém um utilitário em Bash rodando dentro de um container Alpine Linux para identificar arquivos de configuração e **caçar credenciais expostas** na raiz de repositórios do GitHub.

O scanner utiliza a API do GitHub para analisar os metadados e o conteúdo bruto dos arquivos sem a necessidade de realizar o `git clone`.

## 🚀 Como utilizar

### 1. Build da Imagem Docker

No diretório raiz do projeto, execute:

```bash
docker build -t config-scanner .
```

### 2. Executando os Testes

O container agora é mais robusto e aceita três formatos de entrada:

#### Opção A: Apenas o nome de usuário
Busca todos os repositórios públicos do perfil.
```bash
docker run --rm config-scanner user1b
```

#### Opção B: URL do perfil
```bash
docker run --rm config-scanner https://github.com/user1b
```

#### Opção C: URL de um repositório específico
```bash
docker run --rm config-scanner https://github.com/user/repositorio-ex
```

## 🛠️ O que ele faz?

1.  **Detecção de Arquivos**: Localiza extensões perigosas na raiz (`.json`, `.yaml`, `.conf`, `.properties`, etc).
2.  **Secret Hunting**: Ao encontrar um arquivo de configuração, o script baixa o conteúdo e busca por padrões de credenciais como:
    *   `password`, `passwd`, `pwd`
    *   `user`, `username`, `admin`
    *   `secret`, `key`, `token`
    *   `auth`, `credentials`
    *   `version`

### Exemplo de Saída Positiva:
```text
Analisando repositório: usuario/projeto
  [ ALERTA ] Arquivos de configuração encontrados:
    - config.properties
    [!] Possíveis credenciais em 'config.properties':
        -> db.password=root123
        -> api_key: "aiSzaSy..."
```

## ⚠️ Observações Importantes

- **API Rate Limit**: O GitHub permite 60 requisições/hora para usuários não autenticados. Se você rodar o scanner para um usuário com muitos repositórios, o limite pode ser atingido rapidamente.
- **Deep Scan**: A busca de segredos é baseada em `grep`. Ela é excelente para flagar exposições óbvias, mas não substitui ferramentas de análise estática profissional (SAST).
