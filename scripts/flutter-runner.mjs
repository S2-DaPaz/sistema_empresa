import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const mobileDir = path.join(__dirname, "..", "mobile");
const [, , ...args] = process.argv;
if (args.length === 0) {
  console.error("Usage: node scripts/flutter-runner.mjs <flutter-args...>");
  process.exit(1);
}

const child =
  process.platform === "win32"
    ? spawn("cmd.exe", ["/d", "/s", "/c", "flutter.bat", ...args], {
        cwd: mobileDir,
        stdio: "inherit"
      })
    : spawn("flutter", args, {
        cwd: mobileDir,
        stdio: "inherit"
      });

child.on("exit", (code) => {
  process.exit(code ?? 1);
});
