#!/usr/bin/env lucicfg
# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""
This loads the protobuf corresponding to release branch data.

See //infra/config/lib/release_branches/README.md for more information.
"""

proto.new_descriptor_set(
    name = "release_branches",
    blob = io.read_file("./branches.bin"),
).register()

load("@proto//branches.proto", _release_branches_pb = "release_branches")

release_branches = proto.from_jsonpb(
    _release_branches_pb.Branches,
    io.read_file("./branches.json"),
)
