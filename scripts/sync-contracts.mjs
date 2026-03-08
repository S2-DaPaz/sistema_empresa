import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, "..");
const contractsDir = path.join(rootDir, "packages", "contracts");
const mobileGeneratedDir = path.join(
  rootDir,
  "mobile",
  "lib",
  "core",
  "contracts",
  "generated"
);

function readJson(fileName) {
  return JSON.parse(fs.readFileSync(path.join(contractsDir, fileName), "utf8"));
}

function writeFile(filePath, contents) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, contents, "utf8");
}

function dartString(value) {
  return `'${String(value).replace(/\\/g, "\\\\").replace(/'/g, "\\'")}'`;
}

function renderPermissionsDart(source) {
  const permissionEntries = Object.entries(source.permissions);
  const roleEntries = Object.entries(source.roleDefaults);

  const permissionLines = permissionEntries
    .map(([key, value]) => `  static const String ${camelize(key)} = ${dartString(value)};`)
    .join("\n");

  const roleLines = roleEntries
    .map(
      ([role, permissions]) =>
        `    ${dartString(role)}: [${permissions.map(dartString).join(", ")}],`
    )
    .join("\n");

  const reservedLines = source.reservedRoleKeys.map(dartString).join(", ");

  return `// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: packages/contracts/permissions.json

class AppPermissions {
${permissionLines}
}

const Map<String, List<String>> kRoleDefaults = {
${roleLines}
};

const List<String> kReservedRoleKeys = [${reservedLines}];
`;
}

function renderDomainOptionsDart(source) {
  const mapLines = Object.entries(source)
    .map(([key, items]) => {
      const values = items
        .map(
          (item) =>
            `      DomainOption(value: ${dartString(item.value)}, label: ${dartString(item.label)}),`
        )
        .join("\n");
      return `  ${dartString(key)}: [\n${values}\n  ],`;
    })
    .join("\n");

  return `// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: packages/contracts/domain-options.json

class DomainOption {
  const DomainOption({required this.value, required this.label});

  final String value;
  final String label;
}

const Map<String, List<DomainOption>> kDomainOptions = {
${mapLines}
};
`;
}

function camelize(value) {
  const normalized = value.toLowerCase();
  return normalized.replace(/_([a-z])/g, (_, char) => char.toUpperCase());
}

function main() {
  const permissions = readJson("permissions.json");
  const domainOptions = readJson("domain-options.json");

  writeFile(
    path.join(mobileGeneratedDir, "permissions.g.dart"),
    renderPermissionsDart(permissions)
  );
  writeFile(
    path.join(mobileGeneratedDir, "domain_options.g.dart"),
    renderDomainOptionsDart(domainOptions)
  );

  process.stdout.write("Contracts synchronized.\n");
}

main();
