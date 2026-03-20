const migration001 = require("./001-initial-schema");
const migration002 = require("./002-current-schema-backfill");
const migration003 = require("./003-background-jobs");

const migrations = [migration001, migration002, migration003];

module.exports = { migrations };
