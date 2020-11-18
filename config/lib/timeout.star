# Copyright 2019 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Timeout definitions to use across all the configs."""

timeout = struct(
    SHORT = 30 * time.minute,
    MEDIUM = 60 * time.minute,
    LONG = 90 * time.minute,
    XL = 180 * time.minute,
    # EXPIRATION is used to set builder expiration_timeout, which controls
    # how long to wait for a build to be picked up before canceling.
    LONG_EXPIRATION = 12 * 60 * time.minute,
)
