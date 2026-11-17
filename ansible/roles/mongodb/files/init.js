// Executado pelo entrypoint do MongoDB somente na PRIMEIRA inicialização
// (diretório de dados vazio). Cria o usuário da aplicação com acesso
// restrito ao banco kubeshop. Baseado em docker/mongodb/init.js do KubeShop.
const fs = require('fs');
const appDb = db.getSiblingDB('kubeshop');
appDb.createUser({
  user: process.env.MONGO_APP_USERNAME,
  pwd: fs.readFileSync(process.env.MONGO_APP_PASSWORD_FILE, 'utf8').trim(),
  roles: [{ role: 'readWrite', db: 'kubeshop' }],
});
