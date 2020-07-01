# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Helper functions for Flutter LUCI configs."""

def _merge_dicts(a, b):
    """Return the result of merging two dicts.

    If matching values are both dicts or both lists, they will be merged (non-recursively).

    Args:
      a: first dict.
      b: second dict (takes priority).

    Returns:
      Merged dict.
    """
    a = dict(a)
    for k, bv in b.items():
        av = a.get(k)
        if type(av) == "dict" and type(bv) == "dict":
            a[k] = dict(av)
            a[k].update(bv)
        elif type(av) == "list" and type(bv) == "list":
            a[k] = av + bv
        else:
            a[k] = bv
    return a

helpers = struct(merge_dicts = _merge_dicts)
