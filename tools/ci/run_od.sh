#!/bin/bash
set -eo pipefail
dotnet $HOME/OpenDream/DMCompiler/bin/Release/net7.0/DMCompiler.dll --suppress-unimplemented baystation12.dme
