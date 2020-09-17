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

def _setup(branches):
    for branch in branches:
        devicelab_prod_config(
            branch,
            branches[branch]["version"],
            branches[branch]["testing-ref"],
        )

    devicelab_try_config()

def devicelab_prod_config(branch, version, ref):
    """Prod configurations for the framework repository.

    Args:
      branch(str): The branch name we are creating configurations for.
      version(str): One of dev|beta|stable.
      ref(str): The git ref we are creating configurations for.
    """

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
        name = "Linux%s build_aar_module_test|aar_module" % ("" if branch == "master" else " " + branch),
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
        name = "Linux%s gradle_fast_start_test|gradle_fast_start" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_fast_start_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s gradle_jetifier_test|gradle_jetifier" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_jetifier_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s gradle_non_android_plugin_test|gradle_non_android_plugin" % ("" if branch == "master" else " " + branch),
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
        name = "Linux%s gradle_plugin_bundle_test|gradle_plugin_bundle_test" % ("" if branch == "master" else " " + branch),
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
        name = "Linux%s gradle_plugin_fat_apk_test|gradle_plugin_fat_apk" % ("" if branch == "master" else " " + branch),
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
        name = "Linux%s gradle_plugin_light_apk_test|gradle_plugin_light_apk" % ("" if branch == "master" else " " + branch),
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
        name = "Linux%s gradle_r8_test|gradle_r8" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_r8_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_prod_builder(
        name = "Linux%s module_host_with_custom_build_test|module_host_with_custom_build" % ("" if branch == "master" else " " + branch),
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
        name = "Linux%s module_custom_host_app_name_test|module_custom_host_app_name" % ("" if branch == "master" else " " + branch),
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
        name = "Linux%s module_test|module" % ("" if branch == "master" else " " + branch),
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
        name = "Linux%s plugin_dependencies_test|plugin_dependencies" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "plugin_dependencies_test",
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
    common.linux_prod_builder(
        name = "Linux%s web_benchmarks_html|web_benchmarks_html" % ("" if branch == "master" else " " + branch),
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

    # Mac prod builders.
    common.mac_prod_builder(
        name = "Mac%s build_aar_module_test|aar_module" % ("" if branch == "master" else " " + branch),
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
            "task_name": "build_aar_module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_fast_start_test|gradle_fast_start" % ("" if branch == "master" else " " + branch),
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
            "task_name": "gradle_fast_start_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_jetifier_test|gradle_jetifier" % ("" if branch == "master" else " " + branch),
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
            "task_name": "gradle_jetifier_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_non_android_plugin_test|gradle_non_android_plugin" % ("" if branch == "master" else " " + branch),
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
            "task_name": "gradle_non_android_plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_plugin_bundle_test|gradle_plugin_bundle_test" % ("" if branch == "master" else " " + branch),
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
            "task_name": "gradle_plugin_bundle_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_plugin_fat_apk_test|gradle_plugin_fat_apk" % ("" if branch == "master" else " " + branch),
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
            "task_name": "gradle_plugin_fat_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_plugin_light_apk_test|gradle_plugin_light_apk" % ("" if branch == "master" else " " + branch),
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
            "task_name": "gradle_plugin_light_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_r8_test|gradle_r8" % ("" if branch == "master" else " " + branch),
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
            "task_name": "gradle_r8_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s module_host_with_custom_build_test|module_host_with_custom_build" % ("" if branch == "master" else " " + branch),
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
            "task_name": "module_host_with_custom_build_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s module_custom_host_app_name_test|module_custom_host_app_name" % ("" if branch == "master" else " " + branch),
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
            "task_name": "module_custom_host_app_name_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s module_test|module" % ("" if branch == "master" else " " + branch),
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
            "task_name": "module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s plugin_dependencies_test|plugin_dependencies" % ("" if branch == "master" else " " + branch),
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
            "task_name": "plugin_dependencies_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s module_test_ios|module_ios" % ("" if branch == "master" else " " + branch),
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
            "task_name": "module_test_ios",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s build_ios_framework_module_test|build_ios_framework_module" % ("" if branch == "master" else " " + branch),
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
            "task_name": "build_ios_framework_module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_prod_builder(
        name = "Mac%s plugin_lint_mac|plugin_lint_mac" % ("" if branch == "master" else " " + branch),
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
            "task_name": "plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )

    # Windows prod builders
    common.windows_prod_builder(
        name = "Windows%s build_aar_module_test|aar_module" % ("" if branch == "master" else " " + branch),
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
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_fast_start_test|gradle_fast_start" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_fast_start_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_jetifier_test|gradle_jetifier" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_jetifier_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_non_android_plugin_test|gradle_non_android_plugin" % ("" if branch == "master" else " " + branch),
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
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_plugin_bundle_test|gradle_plugin_bundle_test" % ("" if branch == "master" else " " + branch),
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
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_plugin_fat_apk_test|gradle_plugin_fat_apk" % ("" if branch == "master" else " " + branch),
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
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_plugin_light_apk_test|gradle_plugin_light_apk" % ("" if branch == "master" else " " + branch),
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
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_r8_test|gradle_r8" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_r8_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.windows_prod_builder(
        name = "Windows%s module_host_with_custom_build_test|module_host_with_custom_build" % ("" if branch == "master" else " " + branch),
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
    )
    common.windows_prod_builder(
        name = "Windows%s module_custom_host_app_name_test|module_custom_host_app_name" % ("" if branch == "master" else " " + branch),
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
    )
    common.windows_prod_builder(
        name = "Windows%s module_test|module" % ("" if branch == "master" else " " + branch),
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
    )
    common.windows_prod_builder(
        name = "Windows%s plugin_dependencies_test|plugin_dependencies" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "plugin_dependencies_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
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
        name = "Linux build_aar_module_test|aar_module",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
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
        name = "Linux gradle_fast_start_test|gradle_fast_start",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_fast_start_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux gradle_jetifier_test|gradle_jetifier",
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
        name = "Linux gradle_non_android_plugin_test|gradle_non_android_plugin",
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
        name = "Linux gradle_plugin_bundle_test|gradle_plugin_bundle_test",
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
        name = "Linux gradle_plugin_fat_apk_test|gradle_plugin_fat_apk",
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
        name = "Linux gradle_plugin_light_apk_test|gradle_plugin_light_apk",
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
        name = "Linux gradle_r8_test|gradle_r8",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_r8_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.linux_try_builder(
        name = "Linux module_host_with_custom_build_test|module_host_with_custom_build",
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
        name = "Linux module_custom_host_app_name_test|module_custom_host_app_name",
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
        name = "Linux plugin_dependencies_test|plugin_dependencies",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "plugin_dependencies_test",
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
        name = "Linux web_benchmarks_html|web_benchmarks_html",
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

    # Mac try builders.
    common.mac_try_builder(
        name = "Mac build_aar_module_test|aar_module",
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
            "task_name": "build_aar_module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac gradle_fast_start_test|gradle_fast_start",
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
            "task_name": "gradle_fast_start_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac gradle_jetifier_test|gradle_jetifier",
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
            "task_name": "gradle_jetifier_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac gradle_non_android_plugin_test|gradle_non_android_plugin",
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
            "task_name": "gradle_non_android_plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac gradle_plugin_bundle_test|gradle_plugin_bundle_test",
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
            "task_name": "gradle_plugin_bundle_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac gradle_plugin_fat_apk_test|gradle_plugin_fat_apk",
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
            "task_name": "gradle_plugin_fat_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac gradle_plugin_light_apk_test|gradle_plugin_light_apk",
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
            "task_name": "gradle_plugin_light_apk_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac gradle_r8_test|gradle_r8",
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
            "task_name": "gradle_r8_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac module_host_with_custom_build_test|module_host_with_custom_build",
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
            "task_name": "module_host_with_custom_build_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac module_custom_host_app_name_test|module_custom_host_app_name",
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
            "task_name": "module_custom_host_app_name_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac module_test|module",
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
            "task_name": "module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac plugin_dependencies_test|plugin_dependencies",
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
            "task_name": "plugin_dependencies_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac module_test_ios|module_ios",
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
            "task_name": "module_test_ios",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac build_ios_framework_module_test|build_ios_framework_module",
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
            "task_name": "build_ios_framework_module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.mac_try_builder(
        name = "Mac plugin_lint_mac|plugin_lint_mac",
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
            "task_name": "plugin_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )

    # Windows try builders.
    common.windows_try_builder(
        name = "Windows build_aar_module_test|aar_module",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "build_aar_module_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.windows_try_builder(
        name = "Windows gradle_fast_start_test|gradle_fast_start",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_fast_start_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.windows_try_builder(
        name = "Windows gradle_jetifier_test|gradle_jetifier",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_jetifier_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.windows_try_builder(
        name = "Windows gradle_non_android_plugin_test|gradle_non_android_plugin",
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
    )
    common.windows_try_builder(
        name = "Windows gradle_plugin_bundle_test|gradle_plugin_bundle_test",
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
    )
    common.windows_try_builder(
        name = "Windows gradle_plugin_fat_apk_test|gradle_plugin_fat_apk",
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
    )
    common.windows_try_builder(
        name = "Windows gradle_plugin_light_apk_test|gradle_plugin_light_apk",
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
    )
    common.windows_try_builder(
        name = "Windows gradle_r8_test|gradle_r8",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_r8_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
    )
    common.windows_try_builder(
        name = "Windows module_host_with_custom_build_test|module_host_with_custom_build",
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
    )
    common.windows_try_builder(
        name = "Windows module_custom_host_app_name_test|module_custom_host_app_name",
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
    )
    common.windows_try_builder(
        name = "Windows module_test|module",
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
    )
    common.windows_try_builder(
        name = "Windows plugin_dependencies_test|plugin_dependencies",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "plugin_dependencies_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
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
    )

devicelab_config = struct(setup = _setup)
