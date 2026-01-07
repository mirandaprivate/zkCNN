#!/bin/bash

# 切换到项目根目录 (zkCNN)
cd "$(dirname "$0")/.."

echo "Current directory: $(pwd)"

# 验证我们在正确的目录
if [ ! -f "CMakeLists.txt" ]; then
    echo "Error: CMakeLists.txt not found in $(pwd)"
    echo "Please run this script from the zkCNN/script directory"
    exit 1
fi

# 彻底清理构建目录
echo "Cleaning build directory..."
rm -rf cmake-build-release
mkdir -p cmake-build-release

# 进入构建目录
cd cmake-build-release
echo "In build directory: $(pwd)"

# 运行CMake
echo "Running cmake..."
cmake -DCMAKE_BUILD_TYPE=Release ..

# 检查CMake是否成功
if [ $? -ne 0 ]; then
    echo "CMake failed!"
    exit 1
fi

# 编译 (强制所有目标)
echo "Running make..."
make -j$(nproc)

# 检查make是否成功
if [ $? -ne 0 ]; then
    echo "Make failed!"
    exit 1
fi

# 返回项目根目录
cd ..

# 解压数据文件
if [ ! -d "./data" ]; then
    if [ -f "data.tar.gz" ]; then
        echo "Extracting data.tar.gz..."
        tar -xzvf data.tar.gz
    else
        echo "Warning: data.tar.gz not found"
    fi
fi

echo "Build completed successfully!"
