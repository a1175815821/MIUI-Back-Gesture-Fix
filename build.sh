#!/bin/bash
# 离线构建 LSPosed 模块 APK（不依赖 Gradle）
set -e
set -o pipefail
export MSYS_NO_PATHCONV=1

SDK="C:/Users/Administrator/AppData/Local/Android/Sdk"
BT="$SDK/build-tools/34.0.0"
ANDROID_JAR="$SDK/platforms/android-34/android.jar"
JAVA_HOME_WIN="C:/Program Files/Java/jdk-17.0.3.1"
JAVAC="$JAVA_HOME_WIN/bin/javac.exe"
KEYTOOL="$JAVA_HOME_WIN/bin/keytool.exe"
PY="C:/Users/Administrator/.workbuddy-ai/binaries/python/versions/3.13.12/python.exe"

SRC="C:/Users/Administrator/WorkBuddy AI/2026-10-12-18-56-20/xposed-backfix"
WORK="C:/Users/Administrator/AppData/Local/Temp/wb_backfix"

echo "== 准备无空格工作目录 =="
rm -rf "$WORK"
mkdir -p "$WORK"
cp -r "$SRC"/. "$WORK"/
cp "$SRC/lib/api82.jar" "$WORK/api82.jar"
cd "$WORK"
rm -rf build; mkdir -p build/classes build/dex build/res

echo "== 1/6 javac =="
"$JAVAC" -source 8 -target 8 -encoding UTF-8 -nowarn \
  -cp "$ANDROID_JAR;$WORK/api82.jar" \
  -d build/classes \
  src/io/github/a1175815821/miuibackfix/BackFix.java
echo "javac ok"
find build/classes -name "*.class"

echo "== 2/6 d8 =="
CLS=$(find build/classes -name "*.class" | tr '\n' ' ')
"$BT/d8.bat" --lib "$ANDROID_JAR" --lib "$WORK/api82.jar" --min-api 29 --output build/dex $CLS
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
echo "BUILD OK"
