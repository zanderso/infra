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
        "mac": {
            "properties": {
                "shard": "framework_tests",
                "cocoapods_version": "1.6.0",
            },
            "caches": [swarming.cache(name = "flutter_cocoapods", path = "cocoapods")],
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

    # TODO(godofredoc): Merge the recipe names once we remove the old one.
    recipe_name = ("flutter_" + version if version else "flutter")
    new_recipe_name = ("flutter/flutter_" + version if version else "flutter/flutter")
    drone_recipe_name = ("flutter/flutter_drone_" + version if version else "flutter/flutter_drone")
    luci.recipe(
        name = recipe_name,
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )
    luci.recipe(
        name = "flutter/flutter_drone",
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )
    luci.recipe(
        name = new_recipe_name,
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )
    luci.recipe(
        name = drone_recipe_name,
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )
    luci.recipe(
        name = "devicelab",
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

    # Linux platform sharded tests
    common.linux_prod_builder(
        name = "Linux%s build_tests|bld_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "build_tests",
            "subshards": ["0", "1_last"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s framework_tests|frwk_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "framework_tests",
            "subshards": ["libraries", "misc", "widgets"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s hostonly_devicelab_tests|hst_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "hostonly_devicelab_tests",
            "subshards": ["0", "1", "2", "3_last"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s tool_tests|tool_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "tool_tests",
            "subshards": ["general", "commands", "integration"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s web_integration_tests|web_int" % ("" if branch == "master" else " " + branch),
        recipe = "flutter/flutter_drone",
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "web_integration_tests",
            "subshards": [],
            "dependencies": [{"dependency": "chrome_and_driver"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s web_tests|web_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "web_tests",
            "subshards": ["0", "1", "2", "3", "4", "5", "6", "7_last"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s SDK Drone|frwdrn" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = None,
        no_notify = True,
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )

    # Linux platform adhoc tests
    common.linux_prod_builder(
        name = "Linux%s analyze|anlz" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "validation": "analyze",
            "validation_name": "Analyze",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s customer_testing|cst_test" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "validation": "customer_testing",
            "validation_name": "Customer testing",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s docs|docs" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "validation": "docs",
            "validation_name": "Docs",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s fuchsia_precache|pcache" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "validation": "fuchsia_precache",
            "validation_name": "Fuchsia precache",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s web_smoke_test|web_smk" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "validation": "web_smoke_test",
            "validation_name": "Web smoke tests",
            "dependencies": [{"dependency": "chrome_and_driver"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )

    # Windows platform
    common.windows_prod_builder(
        name = "Windows%s build_tests|bld_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "build_tests",
            "subshards": ["0", "1_last"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.windows_prod_builder(
        name = "Windows%s framework_tests|frwk_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "framework_tests",
            "subshards": ["libraries", "misc", "widgets"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.windows_prod_builder(
        name = "Windows%s hostonly_devicelab_tests|hst_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "hostonly_devicelab_tests",
            "subshards": ["0", "1", "2", "3_last"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.windows_prod_builder(
        name = "Windows%s tool_tests|tool_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "tool_tests",
            "subshards": ["general", "commands", "integration"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.windows_prod_builder(
        name = "Windows%s SDK Drone|frwdrn" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = None,
        no_notify = True,
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )

    # Windows adhoc tests
    common.windows_prod_builder(
        name = "Windows%s customer_testing|cst_test" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "validation": "customer_testing",
            "validation_name": "Customer testing",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )

    # Mac builders
    common.mac_prod_builder(
        name = "Mac%s build_tests|bld_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "build_tests",
            "subshards": ["0", "1_last"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s framework_tests|frwk_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "framework_tests",
            "subshards": ["libraries", "misc", "widgets"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s tool_tests|tool_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "tool_tests",
            "subshards": ["general", "commands", "integration"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s SDK Drone|frwdrn" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = None,
        no_notify = True,
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
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

    # Linux platform
    common.linux_try_builder(
        name = "Linux build_tests|bld_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "build_tests",
            "subshards": ["0", "1_last"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux framework_tests|frwk_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "framework_tests",
            "subshards": ["libraries", "misc", "widgets"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.linux_try_builder(
        name = "Linux hostonly_devicelab_tests|hst_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "hostonly_devicelab_tests",
            "subshards": ["0", "1", "2", "3_last"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux tool_tests|tool_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "tool_tests",
            "subshards": ["general", "commands", "integration"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux web_tests|web_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "web_tests",
            "subshards": ["0", "1", "2", "3", "4", "5", "6", "7_last"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux web_integration_tests|web_int",
        recipe = "flutter/flutter_drone",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "web_integration_tests",
            "subshards": [],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux SDK Drone|frwkdrn",
        recipe = "flutter/flutter_drone",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )

    # Only runs the devicelab tasks (in the manifest.yaml) that are not benchmarks.
    common.try_builder(
        name = "testonly_devicelab_tests|tst_tests",
        recipe = "devicelab",
        os = "Linux",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {"role": "scheduler"},
    )

    # Linux platform adhoc tests
    common.linux_try_builder(
        name = "Linux analyze|anlz",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "validation": "analyze",
            "validation_name": "Analyze",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.linux_try_builder(
        name = "Linux customer_testing|cst_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "validation": "customer_testing",
            "validation_name": "Customer testing",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.linux_try_builder(
        name = "Linux docs|docs",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "validation": "docs",
            "validation_name": "Docs",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.linux_try_builder(
        name = "Linux fuchsia_precache|pcache",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "validation": "fuchsia_precache",
            "validation_name": "Fuchsia precache",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.linux_try_builder(
        name = "Linux web_smoke_test|web_smk",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "validation": "web_smoke_test",
            "validation_name": "Web smoke tests",
            "dependencies": [{"dependency": "chrome_and_driver"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )

    # Mac platform
    common.mac_try_builder(
        name = "Mac|frwk",
        recipe = "flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        **platform_args["mac"]
    )

    # Windows platform
    common.windows_try_builder(
        name = "Windows build_tests|bld_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "build_tests",
            "subshards": ["0", "1_last"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.windows_try_builder(
        name = "Windows framework_tests|frwk_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "framework_tests",
            "subshards": ["libraries", "misc", "widgets"],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.windows_try_builder(
        name = "Windows hostonly_devicelab_tests|hst_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "hostonly_devicelab_tests",
            "subshards": ["0", "1", "2", "3_last"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.windows_try_builder(
        name = "Windows tool_tests|tool_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "tool_tests",
            "subshards": ["general", "commands", "integration"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.windows_try_builder(
        name = "Windows SDK Drone|frwkdrn",
        recipe = "flutter/flutter_drone",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )

    # Windows adhoc tests
    common.windows_try_builder(
        name = "Windows customer_testing|cst_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "validation": "customer_testing",
            "validation_name": "Customer testing",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )

framework_config = struct(setup = _setup)
