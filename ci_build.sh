#!/usr/bin/env bash
# shellcheck disable=SC2199
# shellcheck source=/dev/null
#
# Copyright (c) 2020 UtsavBalar1231 <utsavbalar1231@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cd /root/project/ci_script/kernel_realme_sdm710

# Export Cross Compiler name
	export COMPILER="ProtonClang-13.0"
# Export Build username
export KBUILD_BUILD_USER="Viciouspup"
export KBUILD_BUILD_HOST="circleci"

# Enviromental Variables
DATE=$(date +"%d.%m.%y")
HOME="/root/project/"
OUT_DIR=out/
if [[ "$@" =~ "lto"* ]]; then
	VERSION="SPIRA-${TYPE}-LTO${DRONE_BUILD_NUMBER}-${DATE}"
else
	VERSION="SPIRAL-${TYPE}-${DRONE_BUILD_NUMBER}-${DATE}"
fi
BRANCH=`git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`
KERNEL_LINK=https://github.com/Rmx1921/kernel_realme_sdm710.git
REF=`echo "$BRANCH" | grep -Eo "[^ /]+\$"`
AUTHOR=`git log $BRANCH -1 --format="%an"`
COMMIT=`git log $BRANCH -1 --format="%h / %s"`
MESSAGE="$AUTHOR@$REF: $KERNEL_LINK/commit/$COMMIT"
# Export Zip name
export ZIPNAME="${VERSION}.zip"

# How much kebabs we need? Kanged from @raphielscape :)
if [[ -z "${KEBABS}" ]]; then
	COUNT="$(grep -c '^processor' /proc/cpuinfo)"
	export KEBABS="$((COUNT * 2))"
fi

# Post to CI channel
#curl -s -X POST https://api.telegram.org/bot${BOT_API_KEY}/sendPhoto -d photo=https://github.com/UtsavBalar1231/xda-stuff/raw/master/banner.png -d chat_id=${CI_CHANNEL_ID}
curl -s -X POST https://api.telegram.org/bot1445481247:AAFmjxDbbXAEFjAgYdyeVj6ZKAq-obPV_64/sendMessage -d text="<code>SPIRAL</code>
Build: <code>${TYPE}</code>
Device: <code>Realme XT(RMX1921)</code>
Compiler: <code>${COMPILER}</code>
Branch: <code>$(git rev-parse --abbrev-ref HEAD)</code>
Commit: <code>$MESSAGE</code>
<i>Build started on Drone Cloud...</i>
Check the build status here: https://cloud.drone.io/viciouspup/kernel_realme_sdm710/${DRONE_BUILD_NUMBER}" -d chat_id=${CI_CHANNEL_ID} -d parse_mode=HTML
curl -s -X POST https://api.telegram.org/bot1445481247:AAFmjxDbbXAEFjAgYdyeVj6ZKAq-obPV_64/sendMessage -d text="Build started for revision ${DRONE_BUILD_NUMBER}" -d chat_id=338913217 -d parse_mode=HTML

START=$(date +"%s")
	# Make defconfig
	make ARCH=arm64 \
		O=${OUT_DIR} \
		RMX1921_defconfig \
		-j${KEBABS}
	# Enable LLD
	scripts/config --file ${OUT_DIR}/.config \
		-e LTO \
		-e LTO_CLANG \
		-d SHADOW_CALL_STACK \
		-e TOOLS_SUPPORT_RELR \
		-e LD_LLD
	# Make silentoldconfig
	cd ${OUT_DIR}
	make O=${OUT_DIR} \
		ARCH=arm64 \
		RMX1921_defconfig \
		-j${KEBABS}
	cd ../
	# Set compiler Path
	PATH=${HOME}/ci_script/proton-clang/bin/:$PATH
	make ARCH=arm64 \
		O=${OUT_DIR} \
		CC="clang" \
		AR="llvm-ar" \
		NM="llvm-nm" \
		LD="ld.lld" \
		STRIP="llvm-strip" \
		OBJCOPY="llvm-objcopy" \
		OBJDUMP="llvm-objdump" \
		OBJSIZE="llvm-size" \
		READELF="llvm-readelf" \
		HOSTCC="clang" \
		HOSTCXX="clang++" \
		HOSTAR="llvm-ar" \
		HOSTLD="ld.lld" \
		CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		-j${KEBABS}

END=$(date +"%s")
DIFF=$(( END - START))
# Import Anykernel3 folder
# cd libufdt-master-utils/src
#python mkdtboimg.py create /drone/src/out/arch/arm64/boot/dtbo.img /drone/src/out/arch/arm64/boot/dts/qcom/*.dtbo
#cd ..
#cd ..
cp $(pwd)/${OUT_DIR}/arch/arm64/boot/Image.gz-dtb $(pwd)/anykernel/
#cp $(pwd)/${OUT_DIR}/arch/arm64/boot/dtbo.img $(pwd)/anykernel/

cd anykernel
zip -r9 ${ZIPNAME} * -x .git .gitignore *.zip
CHECKER=$(ls -l ${ZIPNAME} | awk '{print $5}')
if (($((CHECKER / 1048576)) > 5)); then
	curl -s -X POST https://api.telegram.org/bot1445481247:AAFmjxDbbXAEFjAgYdyeVj6ZKAq-obPV_64/sendMessage -d text="Kernel compiled successfully in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds for SPIRAL" -d chat_id=338913217 -d parse_mode=HTML
	curl -F chat_id="${CI_CHANNEL_ID}" -F document=@"$(pwd)/${ZIPNAME}" https://api.telegram.org/bot1445481247:AAFmjxDbbXAEFjAgYdyeVj6ZKAq-obPV_64/sendDocument
else
	curl -s -X POST https://api.telegram.org/bot1445481247:AAFmjxDbbXAEFjAgYdyeVj6ZKAq-obPV_64/sendMessage -d text="Build Error!!" -d chat_id=338913217
	exit 1;
fi
cd $(pwd)

# Cleanup
rm -fr anykernel/