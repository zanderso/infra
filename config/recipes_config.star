#!/usr/bin/env lucicfg
# Copyright 2019 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""
Configurations for the recipes repository.

This is mainly for bundling the recipes at https://flutter.googlesource.com/recipes/
into a CIPD bundle.

The documentation about recipe bundle:
https://chrome-internal.googlesource.com/infra/infra_internal/+/master/doc/recipe_bundler.md
"""

load("//lib/accounts.star", "accounts")
load("//lib/builder_groups.star", "builder_groups")
load("//lib/common.star", "common")
load("//lib/repos.star", "repos")

def _setup():
    console_name = "recipes"
    luci.console_view(name = console_name, repo = repos.FLUTTER_RECIPES)

    executable = luci.recipe(
        name = "recipes",
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
        use_bbagent = True,
    )

    # Builder configuration to validate recipe changes in presubmit.
    common.builder(
        name = "recipes-unittest-only",
        builder_group = builder_groups.recipes_try,
        # This builder is very quick to run, so we run it on every CQ attempt to
        # minimize the chances of expectation file conflicts between CLs that land
        # around the same time.
        cq_disable_reuse = True,
        executable = executable,
        execution_timeout = 10 * time.minute,
        location_regexp_exclude = [
            common.LOCATION_REGEXP_MARKDOWN,
            common.LOCATION_REGEXP_OWNERS,
        ],
        properties = {
            "remote": repos.FLUTTER_RECIPES,
            "unittest_only": True,
        },
        service_account = accounts.FLUTTER_TRY,
    )

    # Builder configuration to run led tasks of all affected recipes.
    common.builder(
        name = "recipes-with-led",
        builder_group = builder_groups.recipes_try,
        executable = executable,
        execution_timeout = 180 * time.minute,
        properties = {
            "remote": repos.FLUTTER_RECIPES,
            "unittest_only": False,
        },
        service_account = accounts.FLUTTER_TRY,
    )

    # Autoroller builder. This is used to roll flutter recipes dependencies.
    common.builder(
        name = "recipe-deps-roller",
        builder_group = builder_groups.recipes_prod,
        executable = luci.recipe(
            name = "recipe_autoroller",
            cipd_package =
                "infra/recipe_bundles/chromium.googlesource.com/infra/infra",
            cipd_version = "git_revision:905c1df843d7771bf3adc0cf21f58eb9498ff063",
        ),
        execution_timeout = 20 * time.minute,
        properties = {
            "db_gcs_bucket": "flutter-recipe-roller-db",
            "projects": {
                "flutter": "https://flutter.googlesource.com/recipes",
            }.items(),
        },
        schedule = "0 2,13 * * *",
        console_category = console_name,
        console_short_name = "aroll",
    )

    # Recipes builder. This is used to create a bundle of the cipd package.
    common.builder(
        name = "recipes-bundler",
        builder_group = builder_groups.recipes_prod,
        executable = luci.recipe(
            name = "recipe_bundler",
            cipd_package =
                "infra/recipe_bundles/chromium.googlesource.com/infra/infra",
            cipd_version = "git_revision:647d5e58ec508f13ccd054f1516e78d7ca3bd540",
        ),
        execution_timeout = 20 * time.minute,
        properties = {
            "package_name_prefix": "flutter/recipe_bundles",
            "package_name_internal_prefix": "flutter_internal/recipe_bundles",
            "recipe_bundler_vers": "git_revision:2ed88b2c854578b512e1c0486824175fe0d7aab6",
            "repo_specs": [
                "flutter.googlesource.com/recipes=FETCH_HEAD,refs/heads/master",
            ],
        }.items(),
        console_category = console_name,
        console_short_name = "bdlr",
    )

recipes_config = struct(setup = _setup)
