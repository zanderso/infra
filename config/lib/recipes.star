# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Settings for recipes.


# Recipe definitions.
def _recipe(
        name,
        cipd_package='flutter/recipe_bundles/flutter.googlesource.com/recipes',
        cipd_version='refs/heads/master'):
    return luci.recipe(
        name=name,
        cipd_package=cipd_package,
        cipd_version=cipd_version,
    )


recipes = struct(recipe=_recipe)
