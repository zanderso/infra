#!/usr/bin/env lucicfg
# Copyright 2019 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""
Configurations for the framework repository.

The schedulers pull commits indirectly from GoB repo (https://chromium.googlesource.com/external/github.com/flutter/flutter)
which is mirrored from https://github.com/flutter/flutter.
"""

load("//lib/common.star", "common")
load("//lib/repos.star", "repos")

def _setup(branches):
    platfrom_args = {
        "linux": {
            "properties": {
                "shard": "framework_tests",
            },
        },
        "mac": {
            "properties": {
                "shard": "framework_tests",
                "cocoapods_version": "1.6.0",
            },
            "caches": [swarming.cache(name = "flutter_cocoapods", path = "cocoapods")],
        },
        "windows": {
            "properties": {
                "shard": "framework_tests",
            },
        },
    }

    for branch in branches:
        framework_prod_config(
            platfrom_args,
            branch,
            branches[branch]["version"],
            branches[branch]["testing-ref"],
        )

    framework_try_config(platfrom_args)

def framework_prod_config(platform_args, branch, version, ref):
    """Prod configurations for the framework repository.

    Args:
      platform_args(dict): Dictionary with default properties with platform as
        key.
      branch(str): The branch name we are creating configurations for.
      version(str): One of dev|beta|stable.
      ref(str): The git ref we are creating configurations for.
    """
    recipe_name = ("flutter_" + version if version else "flutter")
    luci.recipe(
        name = recipe_name,
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )

    # Defines console views for prod builders
    console_view_name = ("framework" if branch == "master" else "%s_framework" % branch)
    luci.console_view(
        name = console_view_name,
        repo = repos.FLUTTER,
        refs = [ref],
    )

    # Defines prod schedulers
    trigger_name = branch + "-gitiles-trigger-framework"
    luci.gitiles_poller(
        name = trigger_name,
        bucket = "prod",
        repo = repos.FLUTTER,
        refs = [ref],
    )

    # Defines triggering policy
    if branch == "master":
        triggering_policy = scheduler.greedy_batching(
            max_concurrent_invocations = 6,
        )
    else:
        triggering_policy = scheduler.greedy_batching(
            max_batch_size = 1,
            max_concurrent_invocations = 3,
        )

    # Defines framework prod builders
    common.linux_prod_builder(
        name = "Linux%s|frwk" % ("" if branch == "master" else " " + branch),
        recipe = recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        **platform_args["linux"]
    )
    common.mac_prod_builder(
        name = "Mac%s|frwk" % ("" if branch == "master" else " " + branch),
        recipe = recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        **platform_args["mac"]
    )
    common.windows_prod_builder(
        name = "Windows%s|frwk" % ("" if branch == "master" else " " + branch),
        recipe = recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        **platform_args["windows"]
    )

def framework_try_config(platform_args):
    """Try configurations for the framework repository.

    Args:
      platform_args(dict): Dictionary with default properties with platform as
        key.
    """

    # Defines a list view for try builders
    list_view_name = "framework-try"
    luci.list_view(
        name = "framework-try",
        title = "Framework try builders",
    )

    # Defines framework try builders
    common.linux_try_builder(
        name = "Linux|frwk",
        recipe = "flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        add_cq = True,
        **platform_args["linux"]
    )
    common.mac_try_builder(
        name = "Mac|frwk",
        recipe = "flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        **platform_args["mac"]
    )
    common.windows_try_builder(
        name = "Windows|frwk",
        recipe = "flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        add_cq = True,
        **platform_args["windows"]
    )

framework_config = struct(setup = _setup)
