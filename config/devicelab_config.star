#!/usr/bin/env lucicfg
# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""
Configurations for devicelab tests.

The schedulers pull commits indirectly from GoB repo (https://chromium.googlesource.com/external/github.com/flutter/flutter)
which is mirrored from https://github.com/flutter/flutter.
"""

load("//lib/common.star", "common")
load("//lib/repos.star", "repos")

# Global xcode version for flutter/devicelab tests.
XCODE_VERSION = "11e708"

def _setup(branches):
    for branch in branches:
        devicelab_prod_config(
            branch,
            branches[branch]["version"],
            branches[branch]["testing-ref"],
        )

    devicelab_try_config()

def short_name(task_name):
    """Create a short name for task name."""
    task_name = task_name.replace("__", "_")
    words = task_name.split("_")
    return "".join([w[0] for w in words])[:5]

def devicelab_prod_config(branch, version, ref):
    """Prod configurations for the framework repository.

    Args:
      branch(str): The branch name we are creating configurations for.
      version(str): One of dev|beta|stable.
      ref(str): The git ref we are creating configurations for.
    """

    # Feature toggle for collecting DeviceLab tests on LUCI. This change landed
    # in flutter/flutter#70702 and must roll through before enabling for more
    # branches beyond master (eg dev, beta, stable).
    UPLOAD_METRICS_CHANNELS = ("master")

    # TODO(godofredoc): Merge the recipe names once we remove the old one.
    drone_recipe_name = ("devicelab/devicelab_drone_" + version if version else "devicelab/devicelab_drone")
    luci.recipe(
        name = drone_recipe_name,
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )

    # Defines console views for prod builders
    console_view_name = ("devicelab" if branch == "master" else "%s_devicelab" % branch)
    luci.console_view(
        name = console_view_name,
        repo = repos.FLUTTER,
        refs = [ref],
    )

    # Defines prod schedulers
    trigger_name = branch + "-gitiles-trigger-devicelab"
    luci.gitiles_poller(
        name = trigger_name,
        bucket = "prod",
        repo = repos.FLUTTER,
        refs = [ref],
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

    # Defines framework prod builders

    # Linux prod builders.
    common.linux_prod_builder(
        name = "Linux%s build_aar_module_test|arr" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "build_aar_module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s gradle_non_android_plugin_test|gnap" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_non_android_plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s gradle_plugin_bundle_test|gpb" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_plugin_bundle_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s gradle_plugin_fat_apk_test|gpfa" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_plugin_fat_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s gradle_plugin_light_apk_test|gpla" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_plugin_light_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s module_host_with_custom_build_test|mhwcb" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "module_host_with_custom_build_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s module_custom_host_app_name_test|mchan" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "module_custom_host_app_name_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s module_test|mod" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s plugin_test|plugin" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )

    # Linux prod builders.
    linux_vm_tasks = [
        "web_benchmarks_canvaskit",
        "web_benchmarks_html",
    ]
    branched_builder_prefix = "" if branch == "master" else " " + branch
    for task in linux_vm_tasks:
        common.linux_prod_builder(
            name = "Linux%s %s|%s" % (branched_builder_prefix, task, short_name(task)),
            recipe = drone_recipe_name,
            console_view_name = console_view_name,
            triggered_by = [trigger_name],
            triggering_policy = triggering_policy,
            properties = {
                "dependencies": [
                    {
                        "dependency": "android_sdk",
                    },
                    {
                        "dependency": "chrome_and_driver",
                    },
                ],
                "task_name": task,
                "upload_metrics": branch in UPLOAD_METRICS_CHANNELS,
            },
            caches = [
                swarming.cache(name = "pub_cache", path = ".pub_cache"),
                swarming.cache(name = "android_sdk", path = "android29"),
            ],
            os = "Linux",
        )

    # Mac prod builders.
    common.mac_prod_builder(
        name = "Mac%s build_aar_module_test|aarm" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "build_aar_module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_non_android_plugin_test|gnap" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_non_android_plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_plugin_bundle_test|gpbt" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_plugin_bundle_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_plugin_fat_apk_test|gpfa" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_plugin_fat_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_plugin_light_apk_test|gpla" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_plugin_light_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s module_host_with_custom_build_test|mhwcb" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_host_with_custom_build_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s module_custom_host_app_name_test|mchan" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_custom_host_app_name_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s module_test|mod" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s module_test_ios|mios" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_test_ios",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s build_ios_framework_module_test|bifm" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "build_ios_framework_module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s macos_content_validation_test|mcvt" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "macos_content_validation_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s plugin_lint_mac|plm" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "plugin_lint_mac",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s plugin_test|plugin" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )

    # Windows prod builders
    common.windows_prod_builder(
        name = "Windows%s build_aar_module_test|aarm" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "build_aar_module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_non_android_plugin_test|gnap" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_non_android_plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_plugin_bundle_test|gpbt" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_plugin_bundle_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_plugin_fat_apk_test|gpfa" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_plugin_fat_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_plugin_light_apk_test|gpla" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_plugin_light_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_prod_builder(
        name = "Windows%s module_host_with_custom_build_test|mhwcb" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "module_host_with_custom_build_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_prod_builder(
        name = "Windows%s module_custom_host_app_name_test|mchan" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "module_custom_host_app_name_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_prod_builder(
        name = "Windows%s module_test|mod" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_prod_builder(
        name = "Windows%s plugin_test|plugin" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )

def devicelab_try_config():
    """Try configurations for the framework repository."""

    drone_recipe_name = "devicelab/devicelab_drone"

    # Defines a list view for try builders
    list_view_name = "devicelab-try"
    luci.list_view(
        name = "devicelab-try",
        title = "devicelab try builders",
    )

    # Defines devicelab try builders

    # Linux try builders.
    common.linux_try_builder(
        name = "Linux build_aar_module_test|aarm",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "build_aar_module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux gradle_jetifier_test|gjet",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_jetifier_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux gradle_non_android_plugin_test|gnap",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_non_android_plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux gradle_plugin_bundle_test|gpbt",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_plugin_bundle_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux gradle_plugin_fat_apk_test|gpfa",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_plugin_fat_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux gradle_plugin_light_apk_test|gpla",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_plugin_light_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux module_host_with_custom_build_test|mhwcb",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "module_host_with_custom_build_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux module_custom_host_app_name_test|mchan",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "module_custom_host_app_name_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux module_test|module",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux plugin_test|plugin",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux web_benchmarks_html|wbh",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "web_benchmarks_html",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )

    # Mac try builders.
    common.mac_try_builder(
        name = "Mac build_aar_module_test|aarm",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "build_aar_module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac gradle_non_android_plugin_test|gnap",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_non_android_plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac gradle_plugin_bundle_test|gpbt",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_plugin_bundle_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac gradle_plugin_fat_apk_test|gpfa",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_plugin_fat_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac gradle_plugin_light_apk_test|gpla",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_plugin_light_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac module_host_with_custom_build_test|mhwcb",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_host_with_custom_build_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac module_custom_host_app_name_test|mchan",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_custom_host_app_name_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac module_test|mod",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac module_test_ios|mios",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_test_ios",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac build_ios_framework_module_test|bifm",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "build_ios_framework_module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac macos_content_validation_test|mcvt",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "macos_content_validation_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
        ],
    )

    common.mac_try_builder(
        name = "Mac plugin_lint_mac|plm",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "plugin_lint_mac",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac plugin_test|plugin",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$depot_tools/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )

    # Windows try builders.
    common.windows_try_builder(
        name = "Windows build_aar_module_test|aarm",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "build_aar_module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_try_builder(
        name = "Windows gradle_non_android_plugin_test|gnap",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_non_android_plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_try_builder(
        name = "Windows gradle_plugin_bundle_test|gpbt",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_plugin_bundle_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_try_builder(
        name = "Windows gradle_plugin_fat_apk_test|gpfa",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_plugin_fat_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_try_builder(
        name = "Windows gradle_plugin_light_apk_test|gpla",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_plugin_light_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_try_builder(
        name = "Windows module_host_with_custom_build_test|mhwcb",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "module_host_with_custom_build_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_try_builder(
        name = "Windows module_custom_host_app_name_test|mchan",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "module_custom_host_app_name_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_try_builder(
        name = "Windows module_test|mod",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )
    common.windows_try_builder(
        name = "Windows plugin_test|plugin",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = "Windows-Server",
    )

devicelab_config = struct(setup = _setup)
