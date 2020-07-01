# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Console and view utilities."""

def _console_view(name, repo, refs = ["refs/heads/master"], exclude_ref = None):
    luci.console_view(
        name = name,
        repo = repo,
        refs = refs,
        exclude_ref = exclude_ref,
    )
    return name

consoles = struct(console_view = _console_view)
