const {
  SQLITE_INITIAL_SCHEMA,
  POSTGRES_INITIAL_SCHEMA
} = require("../schema");

module.exports = {
  id: "001_initial_schema",
  description: "Cria o schema base da aplicação.",
  sql: {
    sqlite: SQLITE_INITIAL_SCHEMA,
    postgres: POSTGRES_INITIAL_SCHEMA
  }
};
