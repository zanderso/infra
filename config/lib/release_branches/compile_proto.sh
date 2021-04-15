#!/usr/bin/env bash

if ! type protoc >/dev/null 2>&1; then
  PROTOC_LINK='https://grpc.io/docs/protoc-installation'
  2>&1 echo "You must have the protoc compiler, see: $PROTOC_LINK"
  exit 1
fi

# Capture absolute path to the containing directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd)"

protoc --descriptor_set_out="$DIR/branches.bin" \
  --proto_path="$DIR" \
  "$DIR/branches.proto"
