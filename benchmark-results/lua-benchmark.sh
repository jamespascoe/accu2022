#!/bin/bash

set -eu

pushd /home/pascoej/development/lua-bindings-build
for ver in 9 10 11 12;
do
  echo "Running Lua benchmarks for clang-$ver"
  rm -rf *
  CC=clang-$ver CXX=clang++-$ver cmake -G "Ninja" -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_CXX_STANDARD=17 /home/pascoej/development/lua-bindings-shootout/
  ninja -j8
  ./x64/bin/lua_bindings_shootout 2>&1 > /home/pascoej/development/lua-bindings-shootout/results-release-$ver.txt
done
popd
