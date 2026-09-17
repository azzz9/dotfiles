#!/usr/bin/env node

import { readdir, readFile } from "node:fs/promises";
import { join, relative, resolve } from "node:path";

const repoRoot = resolve(process.argv[2] ?? process.cwd());
const skillRoot = join(repoRoot, "config/ai/pstack/skills");
const contractPath = join(repoRoot, "config/ai/pstack/runtime.md");
const agentsPath = join(repoRoot, "config/ai/AGENTS.md");
const nixPath = join(repoRoot, "hosts/default.nix");
const errors = [];

const bannedPatterns = [
  ["editor-specific rule path", /~\/\.cursor(?:\/|\b)|\.cursor\/skills/i],
  ["legacy model rule", /pstack-models\.mdc/i],
  ["Cursor delegation field", /\bsubagent_type\b/i],
  ["background delegation field", /\brun_in_background\b/i],
  ["legacy task tool syntax", /`?Task`?\s+(?:call|tool)\b/i],
  ["legacy readonly field", /\breadonly\s*:\s*(?:true|false)\b/i],
  ["legacy cloud environment field", /\benvironment\s*:\s*["']cloud["']/i],
  ["legacy history path", /agent-transcripts/i],
  ["legacy deslop command", /\/deslop\b/i],
  ["legacy control tool", /\bcontrol-(?:cli|ui)\b/i],
  ["runtime-specific question tool", /\bAskQuestion\b/i],
  ["runtime-specific question field", /\ballow_multiple\b/i],
  ["legacy reviewer name", /Comment Sicko/i],
  ["legacy branch field", /\bcloud_base_branch\b/i],
  ["runtime-specific loop command", /\/loop\b/i],
  ["fixed unavailable model", /\b(?:grok-4\.6-fast-xhigh|claude-fable-5-1-thinking-max|gpt-5\.6-sol-max|claude-opus-5-thinking-xhigh)\b/i],
];

const allowedFrontmatterKeys = new Set([
  "name",
  "description",
  "disable-model-invocation",
  "user-invocable",
  "argument-hint",
  "allowed-tools",
  "metadata",
]);

function addError(file, message) {
  errors.push(`${relative(repoRoot, file)}: ${message}`);
}

async function exists(path) {
  try {
    await readFile(path, "utf8");
    return true;
  } catch {
    return false;
  }
}

async function markdownFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...(await markdownFiles(path)));
    else if (entry.isFile() && entry.name.endsWith(".md")) files.push(path);
  }
  return files;
}

function checkFrontmatter(file, text) {
  const lines = text.split(/\r?\n/);
  if (lines[0] !== "---") {
    addError(file, "SKILL.md must start with YAML frontmatter");
    return;
  }

  const closing = lines.findIndex((line, index) => index > 0 && line === "---");
  if (closing < 0) {
    addError(file, "frontmatter has no closing delimiter");
    return;
  }

  const keys = new Set();
  for (const line of lines.slice(1, closing)) {
    if (!line.trim() || line.trimStart().startsWith("#")) continue;
    const match = line.match(/^([A-Za-z][A-Za-z0-9_-]*):(?:\s|$)/);
    if (!match) continue;
    const key = match[1];
    if (keys.has(key)) addError(file, `duplicate frontmatter key ${key}`);
    keys.add(key);
    if (!allowedFrontmatterKeys.has(key)) {
      addError(file, `unsupported frontmatter key ${key}`);
    }
  }

  for (const required of ["name", "description"]) {
    if (!keys.has(required)) addError(file, `missing frontmatter key ${required}`);
  }
}

function checkLegacyPatterns(file, text) {
  for (const [label, pattern] of bannedPatterns) {
    const match = text.match(pattern);
    if (!match) continue;
    const line = text.slice(0, match.index).split(/\r?\n/).length;
    addError(file, `${label} at line ${line}`);
  }
}

function quotedNames(block) {
  return [...block.matchAll(/"([^"]+)"/g)].map((match) => match[1]);
}

async function checkDeployment() {
  const nix = await readFile(nixPath, "utf8").catch(() => "");
  if (!nix) {
    addError(nixPath, "cannot read Home Manager deployment file");
    return;
  }

  const localBlock = nix.match(/localSkillNames\s*=\s*\[(.*?)\];/s)?.[1] ?? "";
  for (const required of ["dotfiles-context", "nix-home-manager"]) {
    if (!quotedNames(localBlock).includes(required)) {
      addError(nixPath, `local skill ${required} is not deployed`);
    }
  }

  const pstackBlock = nix.match(/pstackSkillNames\s*=\s*\[(.*?)\];/s)?.[1] ?? "";
  const deployed = new Set(quotedNames(pstackBlock));
  const directories = (await readdir(skillRoot, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .filter((name) => name !== "scripts");
  for (const name of directories) {
    if (!deployed.has(name)) addError(nixPath, `pstack skill ${name} is not deployed`);
  }

  if (!nix.includes('".agents/pstack/runtime.md"')) {
    addError(nixPath, "shared runtime contract is not deployed to .agents");
  }

  if (!nix.includes("copilotPstackSkillSources")) {
    addError(nixPath, "Copilot pstack compatibility sources are not configured");
  }

  if (!nix.includes("sed -i '/^disable-model-invocation: true$/d' \"$out/SKILL.md\"")) {
    addError(nixPath, "Copilot pstack sources do not remove the incompatible invocation flag");
  }
}

async function main() {
  if (!(await exists(contractPath))) addError(contractPath, "runtime contract is missing");

  const agents = await readFile(agentsPath, "utf8").catch(() => "");
  if (!agents.includes("config/ai/pstack/runtime.md")) {
    addError(agentsPath, "AGENTS.md does not route pstack operations through the runtime contract");
  }

  let files;
  try {
    files = await markdownFiles(skillRoot);
  } catch (error) {
    addError(skillRoot, `cannot scan skill tree: ${error.message}`);
    files = [];
  }

  for (const file of files) {
    const text = await readFile(file, "utf8");
    checkLegacyPatterns(file, text);
    if (file.endsWith("/SKILL.md")) checkFrontmatter(file, text);
  }

  const auditScript = join(skillRoot, "poteto-mode/scripts/worktree-audit.sh");
  const auditText = await readFile(auditScript, "utf8").catch(() => "");
  for (const [label, pattern] of bannedPatterns.slice(0, 2).concat([bannedPatterns[4]])) {
    if (pattern.test(auditText)) addError(auditScript, `${label} remains in runtime helper`);
  }

  await checkDeployment();

  if (errors.length > 0) {
    console.error(`runtime compatibility: FAIL (${errors.length} issue${errors.length === 1 ? "" : "s"})`);
    for (const error of errors) console.error(`- ${error}`);
    process.exitCode = 1;
    return;
  }

  console.log(`runtime compatibility: PASS (${files.length} markdown files checked)`);
}

await main();
