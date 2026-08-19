import { execFileSync } from "node:child_process";

const projectRoot = new URL("../", import.meta.url);

function run(args) {
  execFileSync(process.execPath, args, { cwd: projectRoot, stdio: "inherit" });
}

run(["node_modules/next/dist/bin/next", "build"]);
run(["--test", "tests/frame-flow.test.mjs", "tests/journey.test.mjs", "tests/realms.test.mjs"]);
