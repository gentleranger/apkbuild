#!/bin/bash

checksudo(){
  if [ ! $(groups "$USER" | grep -q '\b\(sudo\|wheel\)\b') ]; then
    printf "\nUser '$USER' does not have sudo priviledges\n"
    printf "If you think this is a miskate, then report it on github\n"
    exit 1
  fi
}

if [ "$UID" -eq 0 ]; then
  printf "Running this script as root is not secure !"
  exit 1
fi

if [ -f /etc/os-release ]; then
  . /etc/os-release
else
  printf "Can't determine distribution family\n"
  printf "Report this issue on github\n"
  exit 1
fi

if [ $(grep "arch" /etc/os-release 1> /dev/null; echo "$?") = "0" ]; then
  export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
  cat >>"$HOME"/.bashrc<< EOF
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk" 
EOF
  if ! pacman -Q jdk17-openjdk &>/dev/null || ! pacman -Q libarchive &> /dev/null; then
    checksudo
    printf "Archlinux based distribution detected.\n"
    sudo -K
    sudo true
    printf "Updating the system...\n"
    sudo pacman -Syu --noconfirm
    printf "\nInstalling required packages...\n"
    sudo pacman -S --noconfirm jdk17-openjdk libarchive
    sudo -K
  fi
elif [ $(grep "debian" /etc/os-release 1> /dev/null; echo "$?") = "0" ]; then
  export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
  cat >>"$HOME"/.bashrc<< EOF
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
EOF
  if ! apt list --installed openjdk-17-jdk &>/dev/null || ! apt list --installed libarchive-tools &>/dev/null; then
    checksudo
    printf "Debian based distribution detected.\n"
    sudo -K
    sudo true
    printf "Updating the system...\n"
    sudo apt update -qq
    sudo apt upgrade -y -qq
    printf "\nInstalling the required packages...\n"
    sudo apt install -y -qq openjdk-17-jdk libarchive-tools
    sudo -K
  fi
else
  printf "Distribution family '$ID_LIKE' not recognized\n"
  printf "Report this issue on github\n"
  exit 1
fi

read -rp "Enter your Reddit Username: " username
read -srp "Enter your Reddit API key: " apiKey
redirectUri="alephzero://localhost"
userAgent="android:dev.itnerd.alephzero:"
androidSdk="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
sdkChecksum="2d2d50857e4eb553af5a6dc3ad507a17adf43d115264b1afc116f95c92e5e258"
githubRepo="https://github.com/Docile-Alligator/Infinity-For-Reddit.git"
apiUtils="$HOME/Infinity/app/src/main/java/ml/docilealligator/infinityforreddit/utils/APIUtils.java"
buildGradle="$HOME/Infinity/app/build.gradle"
apk="$HOME"/Infinity/app/build/outputs/apk/release/app*.apk

wget -q --show-progress "$androidSdk" -O "$HOME"/android-sdk.zip
sync
if [ "$(sha256sum "$HOME"/android-sdk.zip | awk '{print $1}')" = "$sdkChecksum" ]; then
  printf "Checksums Match !\n"
else
  printf "Checksums don't match :(\n"
  sleep 1
  printf "Removing corrupted file...\n"
  rm "$HOME"/android-sdk.zip
  sync
  exit 1
fi
mkdir -pv "$HOME"/android-sdk/cmdline-tools
bsdtar -xf "$HOME"/android-sdk.zip -C "$HOME"/android-sdk/cmdline-tools
mv "$HOME"/android-sdk/cmdline-tools/cmdline-tools "$HOME"/android-sdk/cmdline-tools/tools
sync

export ANDROID_SDK_ROOT="$HOME/android-sdk"
export PATH="$PATH:$HOME/android-sdk/cmdline-tools/tools/bin"
cat >>"$HOME"/.bashrc<< EOF
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export PATH="$PATH:$HOME/android-sdk/cmdline-tools/tools/bin"
EOF

echo yes | sdkmanager "platforms;android-30" "build-tools;30.0.3"
git clone --depth=1 "$githubRepo" "$HOME"/Infinity

password=$(head -c 150 /dev/urandom | tr -dc 'a-zA-Z0-9~`!@#%^&*()-+={[}]|\:;"<,>.?/' | head -c 30)
mkdir -pv "$HOME"/keystore
keytool -genkey -v \
-keystore "$HOME"/keystore/alephzero.jks \
-alias alephzero \
-keyalg RSA \
-keysize 2048 \
-validity 10000 \
-storepass "$password" \
-keypass "$password" \
-dname "CN=itnerd, OU=itnerd, O=itnerd, L=Kolkata, ST=West Bengal, C=IN"

sed -i "s|NOe2iKrPPzwscA|$apiKey|g" "$apiUtils"
sed -i "s|infinity://localhost|$redirectUri|g" "$apiUtils"
sed -i "s|android:ml.docilealligator.infinityforreddit:|$userAgent|g" "$apiUtils"
sed -i "s|/u/Hostilenemy|/u/$username|g" "$apiUtils"

sed -i "/buildTypes {/i\\
    signingConfigs {\n\
        release{\n\
            storeFile file(\"$HOME/keystore/alephzero.jks\")\n\
            storePassword \"$password\"\n\
            keyAlias \"alephzero\"\n\
            keyPassword \"$password\"\n\
        }\n\
    }" "$buildGradle"

sed -i "/minifyEnabled false/i\\
            signingConfig signingConfigs.release" "$buildGradle"

sed -i "/disable 'MissingTranslation'/a\\
        baseline = file(\"lint-baseline.xml\")" "$buildGradle"

cd "$HOME"/Infinity || exit 1
./gradlew updateLintBaseline
./gradlew assembleRelease

if ! ls $apk 1> /dev/null 2>&1; then
  printf "Apk not found !!\n"
  exit 1
else
  mv $apk "$HOME/Downloads/Infinity.apk"
  printf "Compiled apk can be found in the ~/Downloads folder.\n"
  password=""
  username=""
  apiKey=""
  exit 0
fi
