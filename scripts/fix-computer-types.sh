#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python - <<'PY'
from pathlib import Path

p = Path("src/index.ts")
s = p.read_text()

old = '''export class Agent extends withWorkspace(
  class extends DurableObject<Env> {},
  (self) => ({
    storage: self.ctx.storage,
    backends: [
      new WorkerShellBackend({
        loader: self.env.LOADER,
        workspace: {
          binding: "Agent",
          id: self.ctx.id.toString(),
        },
        ctx: self.ctx,
      }),
    ],
  }),
) {}
'''

new = '''export class Agent extends withWorkspace(
  class extends DurableObject<Env> {},
  (self) => {
    const { ctx, env } = self as unknown as {
      ctx: DurableObjectState;
      env: Env;
    };

    return {
      storage: ctx.storage,
      backends: [
        new WorkerShellBackend({
          loader: env.LOADER,
          workspace: {
            binding: "Agent",
            id: ctx.id.toString(),
          },
          ctx,
        }),
      ],
    };
  },
) {}
'''

if old not in s:
    raise SystemExit("[ERROR] Agent withWorkspace 代码与预期不一致")

s = s.replace(old, new, 1)

old2 = '''    const agent = env.Agent.get(id);

    using ws = await getWorkspace(agent);
'''

new2 = '''    const agent = env.Agent.get(id);

    using ws = await getWorkspace(
      agent as unknown as Parameters<typeof getWorkspace>[0],
    );
'''

if old2 not in s:
    raise SystemExit("[ERROR] getWorkspace 调用代码与预期不一致")

s = s.replace(old2, new2, 1)

p.write_text(s)

print("[OK] src/index.ts 类型边界已按照 Cloudflare Computer 官方 worker-shell 示例修复")
PY

echo
echo "== TypeScript 版本 =="
npm exec tsc -- --version

echo
echo "== Diff check =="
git diff --check

echo
echo "== 当前修改 =="
git status --short

echo
echo "== 关键 diff =="
git diff -- src/index.ts package.json tsconfig.json

echo
echo "========================================"
echo "修改完成"
echo "========================================"
echo
echo "Termux 不执行 wrangler types/tsc。"
echo "请提交并让 GitHub Actions 在 Ubuntu 上验证。"
