#!/bin/bash

ANDROID_NDK_HOME=/home/ekibun/android-ndk-r21e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

abi="$2_$3"

builddir=$DIR/build/.make/$abi/$1

if [ -d $builddir ]; then
  rm -r $builddir
fi
mkdir -p $builddir

if [ $1 == "fdk-aac" ]; then
  cd $DIR/$1/

  ./autogen.sh
  make distclean
fi

cd $builddir

CONFIGURE=$DIR/$1/configure

COMMON_CONFIG="\
  --enable-pic \
  --enable-static \
  --disable-shared \
  --prefix=$DIR/build/$abi/ \
"

case $1 in
  "ffmpeg")
    export PKG_CONFIG_PATH="$DIR/build/$abi/lib/pkgconfig"
    COMMON_CONFIG="\
      ${COMMON_CONFIG} \
      --pkg-config=pkg-config \
      --enable-gpl \
      --enable-nonfree \
      --enable-libfdk-aac \
      --enable-libx264 \
      --enable-libx265 \
      --disable-programs \
      --disable-encoders \
      --disable-muxers \
      --disable-avdevice \
      --disable-protocols \
      --disable-doc \
      --disable-filters \
      --disable-avfilter \
      --enable-cross-compile \
    "
    ;;
  "fdk-aac")
    ;;
  "x264")
    COMMON_CONFIG="\
      ${COMMON_CONFIG} \
      --disable-cli \
    "
    ;;
  "x265")
    COMMON_CONFIG="\
      -DCMAKE_INSTALL_PREFIX=$DIR/build/$abi/ \
      -DENABLE_SHARED=0 \
      -DENABLE_CLI=0 \
      -S $DIR/$1/source \
    "
    ;;
  *)
    exit 1
esac

case $2 in
  "win32")
    case $3 in
      "x86")
        CROSS_PREFIX=i686-w64-mingw32
        ;;
      "x86_64")
        CROSS_PREFIX=x86_64-w64-mingw32
        ;;
      *)
        exit 1
    esac
    case $1 in
      "ffmpeg")
        $CONFIGURE \
          $COMMON_CONFIG \
            --arch=$3 \
            --target-os=mingw32 \
            --cross-prefix=$CROSS_PREFIX- \
            --extra-cflags="-I$DIR/build/$abi/include" \
            --extra-libs="-lstdc++" \
            --extra-ldflags="-L$DIR/build/$abi/lib -fPIC"
        ;;
      "fdk-aac")
        $CONFIGURE \
          $COMMON_CONFIG \
          --host=$CROSS_PREFIX
        ;;
      "x264")
        $CONFIGURE \
          $COMMON_CONFIG \
          --cross-prefix=$CROSS_PREFIX- \
          --host=$CROSS_PREFIX
        ;;
      "x265")
        cmake \
          -DCMAKE_SYSTEM_NAME=Windows \
          -DCMAKE_C_COMPILER=$CROSS_PREFIX-gcc \
          -DCMAKE_CXX_COMPILER=$CROSS_PREFIX-g++ \
          -DCMAKE_RC_COMPILER=$CROSS_PREFIX-windres \
          -DCMAKE_ASM_YASM_COMPILER=yasm \
          $COMMON_CONFIG
        ;;
      *)
        exit 1
    esac
    ;;
  "android")
    MIN_API=24
    ARCH_ROOT="$ANDROID_NDK_HOME/platforms/android-$MIN_API/arch-$3"
    TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
    case $3 in
      "arm")
        CC_PREFIX="$TOOLCHAIN/bin/armv7a-linux-androideabi$MIN_API"
        HOST=arm-linux-androideabi
        ;;
      "arm64")
        CC_PREFIX="$TOOLCHAIN/bin/aarch64-linux-android$MIN_API"
        HOST=aarch64-linux-android
        ;;
      "x86")
        CC_PREFIX="$TOOLCHAIN/bin/i686-linux-android$MIN_API"
        HOST=i686-linux-android
        ;;
      "x86_64")
        CC_PREFIX="$TOOLCHAIN/bin/x86_64-linux-android$MIN_API"
        HOST=x86_64-linux-android
        ;;
      *)
        exit 1
    esac
    case $1 in
      "ffmpeg")
        $CONFIGURE \
          $COMMON_CONFIG \
          --arch=$3 \
          --target-os=$2 \
          --cc=$CC_PREFIX-clang \
          --cxx=$CC_PREFIX-clang++ \
          --cross-prefix="$TOOLCHAIN/bin/$HOST-" \
          --disable-asm \
          --extra-cflags="-DANDROID -I$DIR/build/$abi/include" \
          --extra-ldflags="-lstdc++ -lm -L$DIR/build/$abi/lib -Wl,-rpath-link=$ARCH_ROOT/usr/lib -fPIC"
        sed -i "s/#define HAVE_INET_ATON 0/#define HAVE_INET_ATON 1/" config.h
        sed -i "s/#define getenv(x) NULL/\\/\\/ #define getenv(x) NULL/" config.h
        ;;
      "fdk-aac")
        export AR=$TOOLCHAIN/bin/$HOST-ar
        export AS=$TOOLCHAIN/bin/$HOST-as
        export LD=$TOOLCHAIN/bin/$HOST-ld
        export RANLIB=$TOOLCHAIN/bin/$HOST-ranlib
        export STRIP=$TOOLCHAIN/bin/$HOST-strip
        export CC="${CC_PREFIX}-clang -U__ANDROID__"
        export CXX="${CC_PREFIX}-clang++ -U__ANDROID__"
        export LDFLAGS="-Wl,-rpath-link=$ARCH_ROOT/usr/lib -fPIC"
        $CONFIGURE \
          $COMMON_CONFIG \
          --with-pic=yes \
          --target=android \
          --host=$HOST
        ;;
      "x264")
        export CC="${CC_PREFIX}-clang"
        export CXX="${CC_PREFIX}-clang++"
        $CONFIGURE \
          $COMMON_CONFIG \
          --cross-prefix="$TOOLCHAIN/bin/$HOST-" \
          --extra-cflags="-DANDROID -I$DIR/build/$abi/include" \
          --extra-ldflags="-lm -L$DIR/build/$abi/lib -Wl,-rpath-link=$ARCH_ROOT/usr/lib -fPIC" \
          --host=$HOST
        ;;
      "x265")
        if [ $3 =~ arm ]; then
          $COMMON_CONFIG=\
            -DCROSS_COMPILE_ARM=1 \
            $COMMON_CONFIG
        fi
        cmake \
          -DCMAKE_SYSTEM_NAME=Linux \
          -DCMAKE_SYSTEM_PROCESSOR=$2 \
          -DCMAKE_C_COMPILER="${CC_PREFIX}-clang" \
          -DCMAKE_CXX_COMPILER="${CC_PREFIX}-clang++" \
          -DCMAKE_FIND_ROOT_PATH="$ANDROID_NDK_HOME/sysroot" \
          $COMMON_CONFIG
        ;;
      *)
        exit 1
    esac
    ;;
  *)
    exit 1
esac

make -j8
make install
