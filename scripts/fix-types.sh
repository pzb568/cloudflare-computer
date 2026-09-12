#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "========================================"
echo " Cloudflare Computer TypeScript 修复"
echo "========================================"

echo
echo "== 1. 检查 src/index.ts =="

if grep -q '^export interface Env' src/index.ts; then
    echo "[ERROR] src/index.ts 仍然存在手写 Env"
    echo "请检查文件后再执行"
    exit 1
fi

echo "[OK] 未发现手写 Env"

echo
echo "== 2. 检查 @types/node =="

if npm ls @types/node --depth=0 >/dev/null 2>&1; then
    echo "[OK] @types/node 已安装"
else
    echo "[INFO] 安装 @types/node"
    npm install -D @types/node --ignore-scripts
fi

echo
echo "== 3. 检查 tsconfig.json =="

python - <<'PY'
import json
from pathlib import Path

p = Path("tsconfig.json")
data = json.loads(p.read_text())

compiler = data.setdefault("compilerOptions", {})
types = compiler.setdefault("types", [])

required = [
    "./worker-configuration.d.ts",
    "node",
]

changed = False

for item in required:
    if item not in types:
        types.append(item)
        changed = True

if changed:
    p.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    )
    print("[OK] tsconfig.json 已更新")
else:
    print("[OK] tsconfig.json 已正确配置")
PY

echo
echo "== 4. 检查当前平台 =="

if [ -n "${TERMUX_VERSION:-}" ] || [ -d "/data/data/com.termux" ]; then
    echo "[INFO] 检测到 Termux / Android"
    echo "[INFO] 跳过本地 wrangler types"
    echo "[INFO] Wrangler types 将由 GitHub Actions 在 Ubuntu 上生成"
else
    echo "[INFO] 非 Termux 环境"
    echo "[INFO] 生成 Wrangler 类型"
    npx wrangler types
fi

echo
echo "== 5. 当前 Git 修改 =="

git status --short

echo
echo "== 6. 关键 diff =="

git diff -- \
    src/index.ts \
    tsconfig.json \
    package.json \
    package-lock.json

echo
echo "========================================"
echo " 本地修改完成"
echo "========================================"
echo
echo "注意："
echo "Termux/Android 不运行 wrangler types。"
echo "请通过 GitHub Actions 执行："
echo
echo "  npx wrangler types"
echo "  npx tsc --noEmit"
echo
