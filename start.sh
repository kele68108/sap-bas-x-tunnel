#!/usr/bin/env bash
set -e
# ==========================================
# 卸载逻辑：运行 bash start.sh uninstall 触发
# ==========================================
if [ "$1" == "uninstall" ]; then
    echo "[SYSTEM] 开始执行 start (X-Tunnel) 卸载程序..."
    # 1. 杀掉占用 8080 和 8880 TCP 端口的进程
    fuser -k -9 8080/tcp 8880/tcp >/dev/null 2>&1
    lsof -ti:8080,8880 | xargs kill -9 >/dev/null 2>&1
    # 2. 清理隔离目录
    rm -rf ./tmp_xt >/dev/null 2>&1
    # 3. 抹除 ~/.bashrc 中的自启项
    sed -i '/start.sh/d' ~/.bashrc
    echo "[SYSTEM] 卸载完成！start 隧道已彻底从系统中清除。"
    exit 0
fi
# =========================================================
# SAP BAS / 本地沙盒 纯 Bash 隧道启动脚本 (后台不死版)
# =========================================================

# 1. 变量直填区 (统一调整为独立的 FILE_PATH 逻辑)
FILE_PATH="./tmp_xt"
PORT="8080"
X_TOKEN="kele666"
ARGO_TOKEN="eyJhIjoiNTA0NmI1ODdjNmU0YmRhN2FlNTM2ZGZjZGVjM2M1NDkiLCJ0IjoiNTUyMGMwOGUtZDBhNS00ZjUxLTkxYjUtODg0NGE3NzYxN2I0IiwicyI6IllqQXhNR00wTnpJdFl6WXwWUzAwTkdKaUxUZ3lNREF0T0RSaE1UY3pNVFF6WXpOayJ9"   

# 内部端口，不用改
INTERNAL_PORT=8880

if [ -z "$ARGO_TOKEN" ] || [ "$ARGO_TOKEN" == "这里填入你的Cloudflare_Tunnel_Token" ]; then
    echo "[SYSTEM] 严重错误：请先在脚本代码中填入真实的 ARGO_TOKEN！"
    exit 1
fi

# --- 2. 环境准备 (建立专属隔离单间，防止与其他脚本抢占) ---
if [ ! -d "$FILE_PATH" ]; then
    mkdir -p "$FILE_PATH"
else
    rm -f "$FILE_PATH"/* 2>/dev/null
fi

# 3. 启动极简 HTTP 服务，占用 $PORT 端口
echo "[SYSTEM] 启动 HTTP 健康检查探针，监听端口: $PORT"
nohup python3 -c "
import http.server, socketserver
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'BAS Tunnel Service is running.')
try:
    socketserver.TCPServer(('', $PORT), Handler).serve_forever()
except Exception as e:
    pass
" >/dev/null 2>&1 &

# 4. 生成随机字符串并归入隔离目录
XT_NAME=$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)
CF_NAME=$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)
XT_PATH="${FILE_PATH}/${XT_NAME}"
CF_PATH="${FILE_PATH}/${CF_NAME}"

XT_URL="https://github.com/kele68108/sap-x-tunnel/raw/refs/heads/main/x-tunnel-linux-amd64"
CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"

# 5. 下载核心组件并赋权
echo "[SYSTEM] 正在下载核心组件..."
curl -sL -o "$XT_PATH" "$XT_URL"
curl -sL -o "$CF_PATH" "$CF_URL"

echo "[SYSTEM] 赋予执行权限..."
chmod 755 "$XT_PATH" "$CF_PATH"

# 6. 启动核心进程 (转入后台运行)
echo "[SYSTEM] 启动 X-Tunnel，监听本地端口: $INTERNAL_PORT"
nohup "$XT_PATH" -l "ws://127.0.0.1:${INTERNAL_PORT}" -token "$X_TOKEN" >/dev/null 2>&1 &

echo "[SYSTEM] 启动 Cloudflare Argo Tunnel..."
nohup "$CF_PATH" tunnel --edge-ip-version auto run --token "$ARGO_TOKEN" >/dev/null 2>&1 &

# 7. 阅后即焚魔法 (精准清理自身隔离区的文件)
(
    sleep 90  
    rm -f "$XT_PATH" "$CF_PATH"
) >/dev/null 2>&1 &

# 8. 事了拂衣去
echo ""
echo "=================================================="
echo "所有服务已成功剥离并潜入后台运行！"
echo "脚本即将退出。"
echo "脚本卸载命令 bash start.sh uninstall"
echo "=================================================="
