/**
 * Smart Harness Recognize Extension
 *
 * 在项目里按优先级检测配置目录，命中第一个就只用它：
 *
 *   .pi  ->  .github  ->  .claude  ->  .qoder
 *
 * 每个来源提供两样东西：
 *   - 指令文件列表（内容追加到系统提示词，always-on）
 *   - skills 目录（注册为 pi skills，按需 read，progressive disclosure）
 *
 * 查找规则：从当前工作目录向上遍历到 git 仓库根（非 git 仓库则到文件系统根），
 * 每个祖先目录内按 .pi -> .github -> .claude -> .qoder 优先级，取第一个"目录
 * 存在"的来源。最近祖先优先，同目录内 .pi 优先。只加载命中的那一个。
 *
 * 安装：放到 ~/.pi/agent/extensions/ 或 项目 .pi/extensions/，然后 /reload。
 * 无外部依赖，零配置文件。
 */

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// ===========================================================================
// 配置：直接改这里。列表项可以是精确相对路径，也可以是 glob（* / ** / ?）。
// 路径相对各自 harness 目录。空数组 = 该来源不加载任何指令文件（仍加载 skills）。
// autoLoadSkills: false = 该 harness 的 skills 目录不由此扩展加载（留给 pi 自动
// 发现，例如 .pi/skills 会被 pi 自己加载，重复返回反而冗余）。其余 harness
// 默认 true = skills 目录由本扩展按需加载（pi 不会自动发现它们）。
// ===========================================================================

const HARNESS_CONFIG = [
  {
    folder: ".pi",
    label: "pi",
    instructions: ["AGENTS.md"],
    autoLoadSkills: false, // .pi/skills 由 pi 自动加载，本扩展不再重复返回
    // instructions: ["AGENTS.md", "rules/**/*.md"],   // 示例：再加 rules 下所有 md
  },
  {
    folder: ".github",
    label: "GitHub Copilot",
    // instructions: ["copilot-instructions.md"],
    instructions: ["copilot-instructions.md", "instructions/cpp_codestyle.instructions.md", "instructions/proto_codestyle.instructions.md"],
    autoLoadSkills: true,
  },
  {
    folder: ".claude",
    label: "Claude",
    instructions: ["CLAUDE.md"],
    autoLoadSkills: true,
  },
  {
    folder: ".qoder",
    label: "Qoder",
    instructions: ["AGENTS.md"],
    autoLoadSkills: true,
  },
] as const;

const SKILLS_SUBDIR = "skills";

// ---------------------------------------------------------------------------
// 最小 glob 实现（无依赖）
//   *    匹配除 / 外的任意字符
//   **   匹配任意字符（含 /）；紧随其后的 / 会被吞掉
//   ?    匹配除 / 外的单个字符
// ---------------------------------------------------------------------------

function globToRegex(pattern: string): RegExp {
  let re = "^";
  let i = 0;
  while (i < pattern.length) {
    const c = pattern[i];
    if (c === "*") {
      if (pattern[i + 1] === "*") {
        re += ".*";
        i += 2;
        if (pattern[i] === "/") i += 1;
      } else {
        re += "[^/]*";
        i += 1;
      }
    } else if (c === "?") {
      re += "[^/]";
      i += 1;
    } else if ("\\.+^$()|[]{}".includes(c)) {
      re += "\\" + c;
      i += 1;
    } else {
      re += c;
      i += 1;
    }
  }
  return new RegExp(re + "$");
}

const GLOB_CHARS = new Set(["*", "?", "[", "{"]);
function isGlob(p: string): boolean {
  return [...p].some((c) => GLOB_CHARS.has(c));
}

function listFilesRelative(dir: string): string[] {
  const out: string[] = [];
  const walk = (base: string, relBase: string) => {
    let entries: fs.Dirent[];
    try {
      entries = fs.readdirSync(base, { withFileTypes: true });
    } catch {
      return;
    }
    for (const e of entries) {
      const rel = relBase ? `${relBase}/${e.name}` : e.name;
      if (e.isDirectory()) walk(path.join(base, e.name), rel);
      else if (e.isFile()) out.push(rel);
    }
  };
  walk(dir, "");
  return out;
}

function expandEntry(harnessDir: string, entry: string): string[] {
  const clean = entry.replace(/\\/g, "/").replace(/^\.?\//, "");
  const abs = path.resolve(harnessDir, clean);

  if (!isGlob(clean)) {
    try {
      if (fs.existsSync(abs) && fs.statSync(abs).isFile()) return [abs];
    } catch {
      /* ignore */
    }
    return [];
  }

  const regex = globToRegex(clean);
  const matched: string[] = [];
  for (const rel of listFilesRelative(harnessDir)) {
    if (!regex.test(rel)) continue;
    const full = path.join(harnessDir, ...rel.split("/"));
    try {
      if (fs.statSync(full).isFile()) matched.push(full);
    } catch {
      /* ignore */
    }
  }
  return matched;
}

// ---------------------------------------------------------------------------
// 来源解析
// ---------------------------------------------------------------------------

function findGitRoot(cwd: string): string | undefined {
  let dir = cwd;
  while (true) {
    if (fs.existsSync(path.join(dir, ".git"))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) return undefined;
    dir = parent;
  }
}

function ancestorDirs(cwd: string, stop: string | undefined): string[] {
  const dirs: string[] = [];
  let dir = cwd;
  while (true) {
    dirs.push(dir);
    if (dir === stop) break;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return dirs;
}

interface ResolvedSource {
  folder: string;
  label: string;
  rootDir: string;
  harnessDir: string;
  instructionFiles: string[];
  /** 本扩展负责加载 skills 目录的绝对路径；undefined = 该 harness 的 skills 不由本扩展加载 */
  skillsDir: string | undefined;
}

function resolveSource(cwd: string): ResolvedSource | undefined {
  const stop = findGitRoot(cwd);
  for (const dir of ancestorDirs(cwd, stop)) {
    for (const sc of HARNESS_CONFIG) {
      const harnessDir = path.join(dir, sc.folder);
      if (!fs.existsSync(harnessDir) || !fs.statSync(harnessDir).isDirectory()) continue;

      const files: string[] = [];
      const seen = new Set<string>();
      for (const entry of sc.instructions) {
        for (const abs of expandEntry(harnessDir, entry)) {
          if (!seen.has(abs)) {
            seen.add(abs);
            files.push(abs);
          }
        }
      }

      const skillsDir = path.join(harnessDir, SKILLS_SUBDIR);
      const autoLoadSkills = (sc as { autoLoadSkills?: boolean }).autoLoadSkills ?? true;
      const hasSkills = autoLoadSkills && fs.existsSync(skillsDir) && fs.statSync(skillsDir).isDirectory();

      return {
        folder: sc.folder,
        label: sc.label,
        rootDir: dir,
        harnessDir,
        instructionFiles: files,
        skillsDir: hasSkills ? skillsDir : undefined,
      };
    }
  }
  return undefined;
}

interface SkillInfo {
  /** skill 名（frontmatter name 优先，否则目录名 / 文件名） */
  name: string;
  /** 传给 pi 的 skillPaths 项：SKILL.md 或根 .md 的绝对路径 */
  mdPath: string;
}

/** 从 SKILL.md / 根 .md 的 frontmatter 里读 name，读不到回退到目录名/文件名。 */
function readSkillName(mdPath: string, fallback: string): string {
  try {
    const md = fs.readFileSync(mdPath, "utf-8");
    const m = md.match(/^---\s*([\s\S]*?)\s---/);
    if (m) {
      const nm = m[1].match(/^name:\s*(.+?)\s*$/m);
      if (nm) return nm[1].trim();
    }
  } catch {
    /* ignore */
  }
  return fallback;
}

/** 枚举一个 skills 目录下的所有 skill，返回 {name, mdPath} 列表。 */
function getSkillInfos(skillsDir: string): SkillInfo[] {
  let entries: fs.Dirent[];
  try {
    entries = fs.readdirSync(skillsDir, { withFileTypes: true });
  } catch {
    return [];
  }
  const infos: SkillInfo[] = [];
  for (const e of entries) {
    if (e.isDirectory()) {
      const skillMd = path.join(skillsDir, e.name, "SKILL.md");
      if (!fs.existsSync(skillMd)) continue;
      infos.push({ name: readSkillName(skillMd, e.name), mdPath: skillMd });
    } else if (e.isFile() && e.name.endsWith(".md")) {
      const mdPath = path.join(skillsDir, e.name);
      infos.push({ name: readSkillName(mdPath, e.name.replace(/\.md$/, "")), mdPath });
    }
  }
  return infos;
}

/** 默认全局 skills 目录（跨平台）：~/.pi/agent/skills 和 ~/.agents/skills */
function getGlobalSkillsDirs(): string[] {
  const home = os.homedir();
  return [path.join(home, ".pi", "agent", "skills"), path.join(home, ".agents", "skills")];
}

/**
 * 收集"已被加载"的 skill 名集合：枚举 pi 默认会自动发现的所有 skills 目录，
 * 包括全局 ~/.pi/agent/skills、~/.agents/skills，以及项目侧 <cwd 及其祖先到
 * git 根>下的 .pi/skills 和 .agents/skills。命中任一即视为冲突，跳过加载。
 */
function getAlreadyLoadedSkillNames(cwd: string, excludeDir?: string): Set<string> {
  const dirs: string[] = [...getGlobalSkillsDirs()];
  for (const d of ancestorDirs(cwd, findGitRoot(cwd))) {
    dirs.push(path.join(d, ".pi", "skills"));
    dirs.push(path.join(d, ".agents", "skills"));
  }
  const names = new Set<string>();
  for (const dir of dirs) {
    if (excludeDir && path.resolve(dir) === path.resolve(excludeDir)) continue;
    for (const info of getSkillInfos(dir)) names.add(info.name);
  }
  return names;
}

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

export default function smartHarnessRecognizeExtension(pi: ExtensionAPI) {
  pi.on("resources_discover", async (event, ctx) => {
    const cwd = event.cwd ?? process.cwd();
    const source = resolveSource(cwd);
    if (!source) return;

    const instNames = source.instructionFiles.map((abs) => path.basename(abs));
    const skillInfos = source.skillsDir ? getSkillInfos(source.skillsDir) : [];
    const existingNames = getAlreadyLoadedSkillNames(cwd, source.skillsDir);

    const loaded: SkillInfo[] = [];
    const skipped: string[] = [];
    for (const info of skillInfos) {
      if (existingNames.has(info.name)) skipped.push(info.name);
      else loaded.push(info);
    }

    // 打印（TUI 模式）：仅当命中了非 .pi 来源且有实际内容时才打印，
    // 避免无内容时的 "0 instructions and 0 skills" 噪音，也不打印 .pi 目录下的东西
    if (ctx.hasUI && source.folder !== ".pi" && (instNames.length > 0 || loaded.length > 0 || skipped.length > 0)) {
      const loadedNames = loaded.map((i) => i.name);
      let msg = `[Extra Harness] ${instNames.length} instructions and ${loadedNames.length} skills from ${source.label}: [${instNames.join(", ")}] [${loadedNames.join(", ")}]`;
      if (skipped.length > 0) {
        msg += ` skipped ${skipped.length} skills because of conflict [${skipped.join(", ")}]`;
      }
      ctx.ui.notify(msg, "info");
    }

    // 只把不冲突的 skill 路径交给 pi 加载
    if (loaded.length === 0) return;
    return { skillPaths: loaded.map((i) => i.mdPath) };
  });

  pi.on("before_agent_start", async (event) => {
    const cwd = (event as any).systemPromptOptions?.cwd ?? process.cwd();
    const source = resolveSource(cwd);
    if (!source || source.instructionFiles.length === 0) return;

    const blocks: string[] = [];
    for (const abs of source.instructionFiles) {
      let content: string;
      try {
        content = fs.readFileSync(abs, "utf-8").trim();
      } catch {
        continue;
      }
      if (!content) continue;
      const rel = path.relative(source.harnessDir, abs) || abs;
      blocks.push(`### ${rel}\n\n${content}`);
    }
    if (blocks.length === 0) return;

    const header = `## Project Instructions (via ${source.label} harness at ${source.rootDir})`;
    return {
      systemPrompt: event.systemPrompt + `\n\n${header}\n\n${blocks.join("\n\n---\n\n")}\n`,
    };
  });
}
