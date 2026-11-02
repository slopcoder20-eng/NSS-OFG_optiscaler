#!/bin/bash
 
# SPDX-FileCopyrightText: Copyright 2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
# SPDX-License-Identifier: MIT

set -e

echo "Checking pre-requisites..."

                             
if ! command -v cmake &> /dev/null; then
    echo "Cannot find path to cmake. Is CMake installed? Exiting..."
    exit 1
else
    echo "   CMake      - Ready."
fi

echo
echo "Building SDK Model Parser Tool"
echo

                                                
rm -rf build
rm -rf bin
mkdir -p build

                      
rm -rf CMakeFiles
rm -f CMakeCache.txt

cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
                                      
cmake --build . --verbose --parallel 4

cd ..

echo ""
echo " Build finished"

echo "Copy the Model_Parser executable to ../binary_store/"
rsync -avzh --progress bin/Model_Parser ../binary_store/