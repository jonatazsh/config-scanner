# Dockerfile de teste para detecção de versões e segredos
FROM node:14.17.0

# Simulação de má prática: credenciais em variáveis de ambiente
ENV ADMIN_USERNAME=manager
ENV ADMIN_PASSWORD=admin12345
ENV API_TOKEN=9876543210abcdef

WORKDIR /app
COPY . .

RUN echo "Iniciando build da versão 1.5.0"
RUN npm install

CMD ["npm", "start"]
