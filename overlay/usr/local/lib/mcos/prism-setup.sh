#!/bin/bash
# Creates Prism Launcher's config and the two instances (MCOS = play, MCOS-bench = benchmark)
# on the data partition. Idempotent; never overwrites the user's own settings once created.
. /usr/local/lib/mcos/common.sh
. /etc/mcos/defaults.conf; [ -f /data/mcos.conf ] && . /data/mcos.conf
mkdir -p "$PRISM_DIR/instances"
cfg=$PRISM_DIR/prismlauncher.cfg
if [ ! -f "$cfg" ]; then
cat > "$cfg" <<C
[General]
Language=en_US
ApplicationTheme=dark
IconTheme=pe_colored
JavaPath=$JAVA
IgnoreJavaWizard=true
AutomaticJavaDownload=false
AutomaticJavaSwitch=false
UserAskedAboutAutomaticJavaDownload=true
LastHostname=$(hostname)
MinMemAlloc=$HEAP_MB
MaxMemAlloc=$HEAP_MB
LowMemWarning=false
ShowConsole=false
ShowConsoleOnError=true
CloseAfterLaunch=true
QuitAfterGameStop=false
StatusBarVisible=true
LaunchMaximized=false
UpdateChannel=
AutoUpdate=false
C
fi
sed -i "s/^LastHostname=.*/LastHostname=$(hostname)/" "$cfg"

make_instance() {  # id, display name
  local d=$PRISM_DIR/instances/$1
  mkdir -p "$d/minecraft" "$d/libraries" "$d/patches"
  if [ ! -f "$d/instance.cfg" ]; then
    cat > "$d/instance.cfg" <<I
[General]
ConfigVersion=1.2
InstanceType=OneSix
name=$2
iconKey=default
OverrideJavaLocation=true
JavaPath=$JAVA
OverrideMemory=true
MinMemAlloc=$HEAP_MB
MaxMemAlloc=$HEAP_MB
OverrideJavaArgs=true
JvmArgs=$JVM_FLAGS
OverrideMiscellaneous=true
CloseAfterLaunch=true
QuitAfterGameStop=true
OverrideConsole=true
ShowConsole=false
AutoCloseConsole=true
ShowConsoleOnError=true
I
  fi
  cat > "$d/mmc-pack.json" <<'J'
{
    "components": [
        { "cachedName": "LWJGL 2", "cachedVersion": "2.9.4-nightly-20150209", "cachedVolatile": true,
          "dependencyOnly": true, "uid": "org.lwjgl", "version": "2.9.4-nightly-20150209" },
        { "cachedName": "Minecraft", "cachedVersion": "1.8.9", "important": true,
          "uid": "net.minecraft", "version": "1.8.9" },
        { "cachedName": "OptiFine", "cachedVersion": "1.8.9_HD_U_M5", "uid": "optifine.OptiFine", "version": "1.8.9_HD_U_M5" }
    ],
    "formatVersion": 1
}
J
  # OptiFine as a launchwrapper tweaker - exactly what OptiFine's own installer writes,
  # in Prism's component format. The jars are created at first boot by mcos-optifine.
  cat > "$d/patches/optifine.OptiFine.json" <<'J'
{
    "formatVersion": 1,
    "name": "OptiFine",
    "uid": "optifine.OptiFine",
    "version": "1.8.9_HD_U_M5",
    "requires": [ { "uid": "net.minecraft", "equals": "1.8.9" } ],
    "mainClass": "net.minecraft.launchwrapper.Launch",
    "+tweakers": [ "optifine.OptiFineTweaker" ],
    "libraries": [
        { "name": "optifine:launchwrapper-of:2.2", "MMC-hint": "local" },
        { "name": "optifine:OptiFine:1.8.9_HD_U_M5", "MMC-hint": "local" }
    ]
}
J
}
make_instance "$INSTANCE" "Minecraft 1.8.9 + OptiFine"
make_instance "$BENCH_INSTANCE" "Benchmark (do not play)"
# keep the play instance's JVM flags in sync with defaults/mcos.conf
for i in "$INSTANCE" "$BENCH_INSTANCE"; do
  f=$PRISM_DIR/instances/$i/instance.cfg
  sed -i "s|^JvmArgs=.*|JvmArgs=$JVM_FLAGS|; s|^MinMemAlloc=.*|MinMemAlloc=$HEAP_MB|; s|^MaxMemAlloc=.*|MaxMemAlloc=$HEAP_MB|" "$f"
done
# first-time play settings: fullscreen + the known-good baseline settings
opt=$PRISM_DIR/instances/$INSTANCE/minecraft/options.txt
[ -f "$opt" ] || cp /usr/local/share/mcos/options-play.txt "$opt"
ofo=$PRISM_DIR/instances/$INSTANCE/minecraft/optionsof.txt
[ -f "$ofo" ] || cp /usr/local/share/mcos/optionsof-play.txt "$ofo"
