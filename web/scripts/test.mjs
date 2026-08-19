import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const projectRoot = new URL("../", import.meta.url);
const vinextCli = fileURLToPath(new URL("../node_modules/vinext/dist/cli.js", import.meta.url));

function run(args) {
  execFileSync(process.execPath, args, { cwd: projectRoot, stdio: "inherit" });
}

run([vinextCli, "build"]);
run(["--test", "tests/frame-flow.test.mjs", "tests/journey.test.mjs", "tests/realms.test.mjs", "tests/rendered-html.test.mjs"]);
