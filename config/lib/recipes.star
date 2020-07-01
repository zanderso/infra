# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Settings for recipes."""

# Recipe definitions.
def _recipe(
        name,
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
        use_bbagent = False):
    return luci.recipe(
        name = name,
        cipd_package = cipd_package,
        cipd_version = cipd_version,
        use_bbagent = use_bbagent,
    )

recipes = struct(recipe = _recipe)
