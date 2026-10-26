#!/bin/bash
# 离线构建 LSPosed 模块 APK（不依赖 Gradle）
set -e
set -o pipefail
export MSYS_NO_PATHCONV=1

# ---------- 环境配置（均可用环境变量覆盖）----------
# Android SDK：优先 ANDROID_SDK_ROOT / ANDROID_HOME
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-C:/Users/Administrator/AppData/Local/Android/Sdk}}"
BT="$SDK/build-tools/${BUILD_TOOLS_VERSION:-34.0.0}"
ANDROID_JAR="$SDK/platforms/android-34/android.jar"

# JDK 17：优先 JAVA_HOME
JAVA_HOME_WIN="${JAVA_HOME:-C:/Program Files/Java/jdk-17.0.3.1}"
JAVAC="$JAVA_HOME_WIN/bin/javac.exe"
KEYTOOL="$JAVA_HOME_WIN/bin/keytool.exe"

# Python：用于把 classes.dex 打进 zip
if [ -n "$PYTHON" ]; then
  PY="$PYTHON"
elif command -v python3 >/dev/null 2>&1; then
  PY="python3"
elif command -v python >/dev/null 2>&1; then
  PY="python"
else
  echo "!! 找不到 python3，请安装或用 PYTHON=/path/to/python 指定"
  exit 1
fi

# 工程根目录 = 本脚本所在目录（自动转 Windows 风格，供 d8/aapt2 等 Windows 程序使用）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v cygpath >/dev/null 2>&1; then
  SRC="$(cygpath -m "$SCRIPT_DIR")"
else
  SRC="$SCRIPT_DIR"
fi

# 构建目录：d8/aapt2 对含空格路径处理有问题，这里保证无空格
WORK="${TMPDIR:-/tmp}/wb_backfix"
if command -v cygpath >/dev/null 2>&1; then
  WORK="$(cygpath -m "$WORK")"
fi
case "$WORK" in
  *" "*) WORK="C:/wb_backfix_build" ;;
esac

# ---------- 前置检查 ----------
for f in "$JAVAC" "$ANDROID_JAR" "$BT/aapt2.exe"; do
  [ -e "$f" ] || { echo "!! 缺少：$f"; echo "   请检查 SDK / JAVA_HOME（当前 SDK=$SDK）"; exit 1; }
done
echo "SDK      = $SDK"
echo "SRC      = $SRC"
echo "WORK     = $WORK"
echo ""

echo "== 准备无空格工作目录 =="
rm -rf "$WORK"
mkdir -p "$WORK"
cp -r "$SRC"/. "$WORK"/
cd "$WORK"
rm -rf build; mkdir -p build/classes build/dex build/res

echo "== 1/6 javac =="
"$JAVAC" -source 8 -target 8 -encoding UTF-8 -nowarn \
  -cp "$ANDROID_JAR;$WORK/lib/api82.jar" \
  -d build/classes \
  src/io/github/a1175815821/miuibackfix/BackFix.java
echo "javac ok"
find build/classes -name "*.class"

echo "== 2/6 d8 =="
CLS=$(find build/classes -name "*.class" | tr '\n' ' ')
"$BT/d8.bat" --lib "$ANDROID_JAR" --lib "$WORK/lib/api82.jar" --min-api 29 --output build/dex $CLS
ls -la build/dex

echo "== 3/6 aapt2 compile =="
"$BT/aapt2.exe" compile --dir res -o build/res/res.zip

echo "== 4/6 aapt2 link =="
"$BT/aapt2.exe" link -o build/base.apk -I "$ANDROID_JAR" \
  --manifest AndroidManifest.xml \
  -A assets \
  build/res/res.zip
ls -la build/base.apk

echo "== 5/6 打包 classes.dex =="
"$PY" - "$WORK" <<'PYEOF'
import sys, zipfile, os, shutil
work = sys.argv[1]
src = os.path.join(work, "build", "base.apk")
dst = os.path.join(work, "build", "unsigned.apk")
zin = zipfile.ZipFile(src, "r")
zout = zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED)
for item in zin.infolist():
    zout.writestr(item, zin.read(item.filename))
zout.write(os.path.join(work, "build", "dex", "classes.dex"), "classes.dex")
zout.close(); zin.close()
print("packed ->", dst, os.path.getsize(dst))
PYEOF

echo "== 6/6 zipalign + sign =="
"$BT/zipalign.exe" -f 4 build/unsigned.apk build/aligned.apk

# 使用固定签名密钥：同一包名的后续版本必须用同一把 key 签名，
# 否则老用户无法覆盖升级（只能先卸载）。
KS="$SRC/keystore/miuibackfix.jks"
KS_ALIAS="miuibackfix"
KS_PASS="${KS_PASS:-miuibackfix}"
if [ ! -f "$KS" ]; then
  echo "!! 未找到签名密钥，生成新的：$KS"
  echo "!! 请务必备份该文件，丢失后将无法发布可覆盖升级的新版本"
  mkdir -p "$(dirname "$KS")"
  "$KEYTOOL" -genkeypair -keystore "$KS" -alias "$KS_ALIAS" -keyalg RSA -keysize 2048 \
    -validity 10000 -storepass "$KS_PASS" -keypass "$KS_PASS" \
    -dname "CN=MIUI Back Gesture Fix, OU=dev, O=a1175815821, L=CN, ST=CN, C=CN" >/dev/null 2>&1
fi
"$BT/apksigner.bat" sign --ks "$KS" --ks-key-alias "$KS_ALIAS" \
  --ks-pass "pass:$KS_PASS" --key-pass "pass:$KS_PASS" \
  --out build/miuibackfix.apk build/aligned.apk
"$BT/apksigner.bat" verify --print-certs build/miuibackfix.apk | head -3
ls -la build/miuibackfix.apk

# 把产物放回工程目录，方便直接取用（build/ 已在 .gitignore 中）
mkdir -p "$SRC/build"
cp build/miuibackfix.apk "$SRC/build/miuibackfix.apk"
echo ""
echo "BUILD OK"
echo "产物：$SRC/build/miuibackfix.apk"
echo "SHA256：$(sha256sum "$SRC/build/miuibackfix.apk" | cut -d' ' -f1)"
