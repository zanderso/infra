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
load("//lib/timeout.star", "timeout")

# Global xcode version for flutter/devicelab tests.
XCODE_VERSION = "11e708"
NEW_XCODE_VERSION = "12c5020f"

# Linux caches
LINUX_DEFAULT_CACHES = [
    # Android SDK
    swarming.cache(name = "android_sdk", path = "android"),
    # Chrome
    swarming.cache(name = "chrome_and_driver", path = "chrome"),
    # OpenJDK
    swarming.cache(name = "openjdk", path = "java"),
    # PubCache
    swarming.cache(name = "pub_cache", path = ".pub-cache"),
    # Flutter SDK code
    swarming.cache(name = "flutter_sdk", path = "flutter sdk"),
]

# Mac caches
MAC_CORE_CACHES = [
    # Android SDK
    swarming.cache(name = "android_sdk", path = "android"),
    # Chrome
    swarming.cache(name = "chrome_and_driver", path = "chrome"),
    # OpenJDK
    swarming.cache(name = "openjdk", path = "java"),
    # PubCache
    swarming.cache(name = "pub_cache", path = ".pub-cache"),
    # Flutter SDK code
    swarming.cache(name = "flutter_sdk", path = "flutter sdk"),
    # Xcode
    swarming.cache("xcode_binary"),
]

# This is to support two versions of xcode efficiently.
MAC_DEFAULT_CACHES = MAC_CORE_CACHES + [swarming.cache(name = "osx_sdk", path = "osx_sdk")]
MAC_NEWXCODE_CACHES = MAC_CORE_CACHES + [swarming.cache(name = "new_osx_sdk", path = "osx_sdk")]

# Windows caches
WIN_DEFAULT_CACHES = [
    # Android SDK
    swarming.cache(name = "android_sdk", path = "android"),
    # Chrome
    swarming.cache(name = "chrome_and_driver", path = "chrome"),
    # OpenJDK
    swarming.cache(name = "openjdk", path = "java"),
    # PubCache
    swarming.cache(name = "pub_cache", path = ".pub-cache"),
    # Flutter SDK code
    swarming.cache(name = "flutter_sdk", path = "flutter sdk"),
]

def _setup(branches):
    framework_prod_config(
        "stable",
        branches.stable.version,
        branches.stable.testing_ref,
        branches.stable.release_ref,
    )
    framework_prod_config(
        "beta",
        branches.beta.version,
        branches.beta.testing_ref,
        branches.beta.release_ref,
    )
    framework_prod_config(
        "dev",
        branches.dev.version,
        branches.dev.testing_ref,
        branches.dev.release_ref,
    )
    framework_prod_config(
        "master",
        branches.master.version,
        branches.master.testing_ref,
        branches.master.release_ref,
    )

    framework_try_config()

def framework_prod_config(branch, version, testing_ref, release_ref):
    """Prod configurations for the framework repository.

    Args:
      branch(str): The branch name we are creating configurations for.
      version(str): One of dev|beta|stable.
      testing_ref(str): The git ref we are creating configurations for.
      release_ref(str): The git ref used for releases.
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
        refs = [testing_ref],
    )

    # Defines prod schedulers
    trigger_name = branch + "-gitiles-trigger-framework"
    luci.gitiles_poller(
        name = trigger_name,
        bucket = "prod",
        repo = repos.FLUTTER,
        refs = [testing_ref],
    )

    # Defines triggering policy
    if branch == "master":
        triggering_policy = scheduler.greedy_batching(
            max_batch_size = 3,
            max_concurrent_invocations = 3,
        )
    else:
        triggering_policy = scheduler.greedy_batching(
            max_batch_size = 1,
            max_concurrent_invocations = 3,
        )

    # Select which firebase project to upload the docs to.
    firebase_project = ""
    if branch == "master":
        firebase_project = "master-docs-flutter-dev"
    if branch == "stable":
        firebase_project = "docs-flutter-dev"

    # Defines framework prod builders
    #
    # Builders defined only for release refs
    if release_ref in (r"refs/heads/stable", r"refs/heads/beta", r"refs/heads/dev"):
        common.mac_prod_builder(
            name = "Mac %s verify_binaries_codesigned|vbcs" % branch,
            recipe = new_recipe_name,
            console_view_name = console_view_name,
            # This is only signed on the release branch, not candidate branch
            triggered_by = [branch + "-gitiles-trigger-packaging"],
            triggering_policy = triggering_policy,
            properties = {
                "validation": "verify_binaries_codesigned",
                "validation_name": "Verify binaries codesigned",
                "dependencies": [{"dependency": "xcode"}],
                "$depot_tools/osx_sdk": {
                    "sdk_version": XCODE_VERSION,
                },
                "$flutter/osx_sdk": {
                    "sdk_version": XCODE_VERSION,
                },
            },
            caches = [
                swarming.cache(name = "pub_cache", path = ".pub_cache"),
            ],
        )

    # Linux platform sharded tests
    common.linux_prod_builder(
        name = "Linux%s build_tests|bld_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "build_tests",
            "subshards": ["1_2", "2_2"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}, {"dependency": "clang"}, {"dependency": "cmake"}, {"dependency": "ninja"}],
        },
        caches = LINUX_DEFAULT_CACHES,
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
            "dependencies": [{"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_prod_builder(
        name = "Linux%s tool_tests|tool_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "tool_tests",
            "subshards": ["general", "commands"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_prod_builder(
        name = "Linux%s tool_integration_tests|tool_tests_int" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "tool_integration_tests",
            "subshards": ["1_3", "2_3", "3_3"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_prod_builder(
        name = "Linux%s web_tool_tests|web_tt" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "web_tool_tests",
            "subshard": "web",
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
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
            "dependencies": [{"dependency": "chrome_and_driver"}, {"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
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
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_prod_builder(
        name = "Linux%s web_long_running_tests|web_lrt" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "web_long_running_tests",
            "subshards": ["1_3", "2_3", "3_3"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_prod_builder(
        name = "Linux%s SDK Drone|frwdrn" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = None,
        no_notify = True,
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
            "dependencies": [{"dependency": "dashing"}, {"dependency": "firebase"}],
            "firebase_project": firebase_project,
            "release_ref": release_ref or "refs/heads/master",
        },
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_prod_builder(
        name = "Linux%s web_e2e_test|web_e2e" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "validation": "web_e2e_test",
            "validation_name": "Web e2e tests",
            "dependencies": [{"dependency": "chrome_and_driver"}],
        },
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_prod_builder(
        name = "Linux%s flutter_plugins|fltplgns" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "flutter_plugins",
            "subshard": "analyze",
            "dependencies": [],
        },
        caches = LINUX_DEFAULT_CACHES,
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
            "subshards": ["1_3", "2_3", "3_3"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
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
            "dependencies": [{"dependency": "goldctl"}],
        },
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
    )
    common.windows_prod_builder(
        name = "Windows%s tool_tests|tool_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "tool_tests",
            "subshards": ["general", "commands"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
        # TODO(fujino): https://github.com/flutter/flutter/issues/75003
        execution_timeout = timeout.LONG,
    )
    common.windows_prod_builder(
        name = "Windows%s tool_integration_tests|tool_tests_int" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "tool_integration_tests",
            "subshards": ["1_3", "2_3", "3_3"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
        # TODO(fujino): https://github.com/flutter/flutter/issues/75003
        execution_timeout = timeout.LONG,
    )
    common.windows_prod_builder(
        name = "Windows%s web_tool_tests|web_tt" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "web_tool_tests",
            "subshard": "web",
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
    )
    common.windows_prod_builder(
        name = "Windows%s SDK Drone|frwdrn" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = None,
        no_notify = True,
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
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
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
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
            "subshards": ["1_3", "2_3", "3_3"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "xcode"}, {"dependency": "gems"}, {"dependency": "goldctl"}],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": NEW_XCODE_VERSION,
            },
        },
        dimensions = {"device_type": "none"},
        caches = MAC_NEWXCODE_CACHES,
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
            "dependencies": [{"dependency": "goldctl"}],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
        },
        dimensions = {"device_type": "none"},
        caches = MAC_DEFAULT_CACHES,
    )
    common.mac_prod_builder(
        name = "Mac%s tool_tests|tool_tests" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "tool_tests",
            "subshards": ["general", "commands"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "xcode"}, {"dependency": "gems"}, {"dependency": "goldctl"}],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
        },
        dimensions = {"device_type": "none"},
        caches = MAC_DEFAULT_CACHES,
    )
    common.mac_prod_builder(
        name = "Mac%s tool_integration_tests|tool_tests_int" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "tool_integration_tests",
            "subshards": ["1_3", "2_3", "3_3"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "xcode"}, {"dependency": "gems"}, {"dependency": "goldctl"}],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
        },
        dimensions = {"device_type": "none"},
        caches = MAC_DEFAULT_CACHES,
    )
    common.mac_prod_builder(
        name = "Mac%s web_tool_tests|web_tt" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "shard": "web_tool_tests",
            "subshard": "web",
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "xcode"}, {"dependency": "goldctl"}],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
        },
        dimensions = {"device_type": "none"},
        caches = MAC_DEFAULT_CACHES,
    )
    common.mac_prod_builder(
        name = "Mac%s SDK Drone|frwdrn" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = None,
        no_notify = True,
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
    )

    # Mac adhoc tests
    common.mac_prod_builder(
        name = "Mac%s customer_testing|cst_test" % ("" if branch == "master" else " " + branch),
        recipe = new_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "validation": "customer_testing",
            "validation_name": "Customer testing",
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
        },
        dimensions = {"device_type": "none"},
        caches = MAC_DEFAULT_CACHES,
    )

def framework_try_config():
    """Try configurations for the framework repository."""

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
            "subshards": ["1_2", "2_2"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}, {"dependency": "clang"}, {"dependency": "cmake"}, {"dependency": "ninja"}],
        },
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_try_builder(
        name = "Linux framework_tests|frwk_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "framework_tests",
            "subshards": ["libraries", "misc", "widgets"],
            "dependencies": [{"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_try_builder(
        name = "Linux tool_tests|tool_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "shard": "tool_tests",
            "subshards": ["general", "commands"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_try_builder(
        name = "Linux tool_integration_tests|tool_tests_int",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "shard": "tool_integration_tests",
            "subshards": ["1_3", "2_3", "3_3"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_try_builder(
        name = "Linux web_tool_tests|web_tt",
        recipe = "flutter/flutter_drone",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "web_tool_tests",
            "subshard": "web",
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_try_builder(
        name = "Linux web_tests|web_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "web_tests",
            "subshards": ["0", "1", "2", "3", "4", "5", "6", "7_last"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_try_builder(
        name = "Linux web_long_running_tests|web_lrt",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "web_long_running_tests",
            "subshards": ["1_3", "2_3", "3_3"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_try_builder(
        name = "Linux web_integration_tests|web_int",
        recipe = "flutter/flutter_drone",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "web_integration_tests",
            "subshards": [],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "goldctl"}],
        },
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_try_builder(
        name = "Linux SDK Drone|frwkdrn",
        recipe = "flutter/flutter_drone",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_try_builder(
        name = "Linux flutter_plugins|fltplgns",
        recipe = "flutter/flutter_drone",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "flutter_plugins",
            "subshard": "analyze",
            "dependencies": [],
        },
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_try_builder(
        name = "Linux web_e2e_test|web_e2e",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "validation": "web_e2e_test",
            "validation_name": "Web e2e tests",
            "dependencies": [{"dependency": "chrome_and_driver"}],
        },
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
    )

    # Mac platform
    common.mac_try_builder(
        name = "Mac build_tests|bld_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "shard": "build_tests",
            "subshards": ["1_3", "2_3", "3_3"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "xcode"}, {"dependency": "gems"}, {"dependency": "goldctl"}],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": NEW_XCODE_VERSION,
            },
        },
        dimensions = {"device_type": "none"},
        caches = MAC_NEWXCODE_CACHES,
    )
    common.mac_try_builder(
        name = "Mac framework_tests|frwk_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "framework_tests",
            "subshards": ["libraries", "misc", "widgets"],
            "dependencies": [{"dependency": "goldctl"}],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
        },
        dimensions = {"device_type": "none"},
        caches = MAC_DEFAULT_CACHES,
    )
    common.mac_try_builder(
        name = "Mac tool_tests|tool_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "shard": "tool_tests",
            "subshards": ["general", "commands"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "xcode"}, {"dependency": "gems"}, {"dependency": "goldctl"}],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
        },
        dimensions = {"device_type": "none"},
        caches = MAC_DEFAULT_CACHES,
    )
    common.mac_try_builder(
        name = "Mac tool_integration_tests|tool_tests_int",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "shard": "tool_integration_tests",
            "subshards": ["1_3", "2_3", "3_3"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "xcode"}, {"dependency": "gems"}, {"dependency": "goldctl"}],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
        },
        dimensions = {"device_type": "none"},
        caches = MAC_DEFAULT_CACHES,
    )
    common.mac_try_builder(
        name = "Mac web_tool_tests|web_tt",
        recipe = "flutter/flutter_drone",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "web_tool_tests",
            "subshard": "web",
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "xcode"}, {"dependency": "goldctl"}],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
        },
        dimensions = {"device_type": "none"},
        caches = MAC_DEFAULT_CACHES,
    )
    common.mac_try_builder(
        name = "Mac SDK Drone|frwkdrn",
        recipe = "flutter/flutter_drone",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
    )

    # Mac adhoc test
    common.mac_try_builder(
        name = "Mac customer_testing|cst_test",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "validation": "customer_testing",
            "validation_name": "Customer testing",
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
        },
        dimensions = {"device_type": "none"},
        caches = MAC_DEFAULT_CACHES,
    )

    # Windows platform
    common.windows_try_builder(
        name = "Windows build_tests|bld_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "build_tests",
            "subshards": ["1_3", "2_3", "3_3"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
    )
    common.windows_try_builder(
        name = "Windows framework_tests|frwk_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "framework_tests",
            "subshards": ["libraries", "misc", "widgets"],
            "dependencies": [{"dependency": "goldctl"}],
        },
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
    )
    common.windows_try_builder(
        name = "Windows tool_tests|tool_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "shard": "tool_tests",
            "subshards": ["general", "commands"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
        # TODO(fujino): https://github.com/flutter/flutter/issues/75003
        execution_timeout = timeout.LONG,
    )
    common.windows_try_builder(
        name = "Windows tool_integration_tests|tool_tests_int",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "shard": "tool_integration_tests",
            "subshards": ["1_3", "2_3", "3_3"],
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
        # TODO(fujino): https://github.com/flutter/flutter/issues/75003
        execution_timeout = timeout.LONG,
    )
    common.windows_try_builder(
        name = "Windows web_tool_tests|web_tt",
        recipe = "flutter/flutter_drone",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "shard": "web_tool_tests",
            "subshard": "web",
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}, {"dependency": "goldctl"}],
        },
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
    )
    common.windows_try_builder(
        name = "Windows SDK Drone|frwkdrn",
        recipe = "flutter/flutter_drone",
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
    )

    # Windows adhoc tests
    common.windows_try_builder(
        name = "Windows customer_testing|cst_tests",
        recipe = "flutter/flutter",
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "validation": "customer_testing",
            "validation_name": "Customer testing",
        },
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
    )

framework_config = struct(setup = _setup)
