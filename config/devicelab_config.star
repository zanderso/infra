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

# Default caches for Mac android builders
MAC_ANDROID_DEFAULT_CACHES = [
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
MAC_DEFAULT_CACHES = [
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
    swarming.cache("osx_sdk"),
]

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
    devicelab_prod_config("stable", branches.stable.version, branches.stable.testing_ref)
    devicelab_prod_config("beta", branches.beta.version, branches.beta.testing_ref)
    devicelab_prod_config("dev", branches.dev.version, branches.dev.testing_ref)
    devicelab_prod_config("master", branches.master.version, branches.master.testing_ref)

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

    branched_builder_prefix = "" if branch == "master" else " " + branch

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
            max_concurrent_invocations = 1,
        )

        # DeviceLab has limited resources and we want to bundle
        # as much as possible to ensure we are always testing ToT.
        devicelab_triggering_policy = scheduler.greedy_batching(
            max_batch_size = 20,
            max_concurrent_invocations = 1,
        )
    else:
        triggering_policy = scheduler.greedy_batching(
            max_batch_size = 1,
            max_concurrent_invocations = 3,
        )
        devicelab_triggering_policy = triggering_policy

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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_prod_builder(
        name = "Linux%s gradle_desugar_classes_test|gnap" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_desugar_classes_test",
        },
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
    )

    # Linux prod builders with a device.
    linux_tasks = [
        "analyzer_benchmark",
        "android_defines_test",
        "android_obfuscate_test",
        "android_stack_size_test",
        "android_view_scroll_perf__timeline_summary",
        "animated_placeholder_perf__e2e_summary",
        "animated_placeholder_perf",
        "backdrop_filter_perf__e2e_summary",
        "basic_material_app_android__compile",
        "color_filter_and_fade_perf__e2e_summary",
        "complex_layout_android__compile",
        "complex_layout_android__scroll_smoothness",
        "complex_layout_scroll_perf__devtools_memory",
        "complex_layout_semantics_perf",
        "cubic_bezier_perf__e2e_summary",
        "cubic_bezier_perf_sksl_warmup__e2e_summary",
        "cull_opacity_perf__e2e_summary",
        "fast_scroll_heavy_gridview__memory",
        "flutter_gallery__back_button_memory",
        "flutter_gallery__image_cache_memory",
        "flutter_gallery__memory_nav",
        "flutter_gallery__start_up",
        "flutter_gallery__transition_perf_e2e",
        "flutter_gallery__transition_perf_hybrid",
        "flutter_gallery__transition_perf_with_semantics",
        "flutter_gallery__transition_perf",
        "flutter_gallery_android__compile",
        "flutter_gallery_sksl_warmup__transition_perf_e2e",
        "flutter_gallery_sksl_warmup__transition_perf",
        "flutter_gallery_v2_chrome_run_test",
        "flutter_gallery_v2_web_compile_test",
        "flutter_test_performance",
        "frame_policy_delay_test_android",
        "hot_mode_dev_cycle_linux__benchmark",
        "image_list_jit_reported_duration",
        "image_list_reported_duration",
        "large_image_changer_perf_android",
        "linux_chrome_dev_mode",
        "multi_widget_construction_perf__e2e_summary",
        "multi_widget_construction_perf__timeline_summary",
        "new_gallery__crane_perf",
        "picture_cache_perf__e2e_summary",
        "platform_views_scroll_perf__timeline_summary",
        "routing_test",
        "textfield_perf__e2e_summary",
        "web_size__compile_test",
    ]

    for task in linux_tasks:
        common.linux_prod_builder(
            name = "Linux%s %s|%s" % (branched_builder_prefix, task, short_name(task)),
            recipe = drone_recipe_name,
            console_view_name = console_view_name,
            triggered_by = [trigger_name],
            triggering_policy = devicelab_triggering_policy,
            properties = {
                "dependencies": [
                    {
                        "dependency": "android_sdk",
                    },
                    {
                        "dependency": "chrome_and_driver",
                    },
                    {
                        "dependency": "open_jdk",
                    },
                ],
                "task_name": task,
                "upload_metrics": branch in UPLOAD_METRICS_CHANNELS,
            },
            pool = "luci.flutter.prod",
            os = "Android",
            dimensions = {"device_os": "N"},
            # TODO(keyonghan): adjust the timeout when devicelab linux tasks are stable:
            # https://github.com/flutter/flutter/issues/72383.
            expiration_timeout = timeout.LONG_EXPIRATION,
            execution_timeout = timeout.SHORT,
            caches = LINUX_DEFAULT_CACHES,
        )

    # Linux prod builders.
    linux_vm_tasks = [
        "dartdocs",
        "technical_debt__cost",
        "web_benchmarks_canvaskit",
        "web_benchmarks_html",
    ]
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
            caches = LINUX_DEFAULT_CACHES,
            os = "Linux",
        )

    # Mac host with android phones
    mac_android_tasks = [
        "android_semantics_integration_test",
        "backdrop_filter_perf__timeline_summary",
        "channels_integration_test",
        "color_filter_and_fade_perf__timeline_summary",
        "complex_layout_scroll_perf__memory",
        "complex_layout_scroll_perf__timeline_summary",
        "complex_layout__start_up",
        "cubic_bezier_perf_sksl_warmup__timeline_summary",
        "cubic_bezier_perf__timeline_summary",
        "cull_opacity_perf__timeline_summary",
        "drive_perf_debug_warning",
        "embedded_android_views_integration_test",
        "external_ui_integration_test",
        "fading_child_animation_perf__timeline_summary",
        "fast_scroll_large_images__memory",
        "flavors_test",
        "flutter_view__start_up",
        "fullscreen_textfield_perf__timeline_summary",
        "hello_world_android__compile",
        "hello_world__memory",
        "home_scroll_perf__timeline_summary",
        "hot_mode_dev_cycle__benchmark",
        "hybrid_android_views_integration_test",
        "imagefiltered_transform_animation_perf__timeline_summary",
        "integration_ui_driver",
        "integration_ui_keyboard_resize",
        "integration_ui_screenshot",
        "integration_ui_textfield",
        "microbenchmarks",
        "new_gallery__transition_perf",
        "picture_cache_perf__timeline_summary",
        "platform_channel_sample_test",
        "platform_interaction_test",
        "platform_view__start_up",
        "run_release_test",
        "service_extensions_test",
        "textfield_perf__timeline_summary",
        "tiles_scroll_perf__timeline_summary",
    ]

    for task in mac_android_tasks:
        common.mac_prod_builder(
            name = "Mac_android%s %s|%s" % (branched_builder_prefix, task, short_name(task)),
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
                    {
                        "dependency": "open_jdk",
                    },
                ],
                "task_name": task,
                "upload_metrics": branch in UPLOAD_METRICS_CHANNELS,
            },
            pool = "luci.flutter.prod",
            os = "Mac",
            category = "Mac_android",
            dimensions = {"device_os": "N"},
            expiration_timeout = timeout.LONG_EXPIRATION,
            execution_timeout = timeout.SHORT,
            caches = MAC_ANDROID_DEFAULT_CACHES,
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
                "sdk_version": NEW_XCODE_VERSION,
            },
            "task_name": "module_test_ios",
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
                "sdk_version": NEW_XCODE_VERSION,
            },
            "task_name": "build_ios_framework_module_test",
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
                "sdk_version": NEW_XCODE_VERSION,
            },
            "task_name": "plugin_lint_mac",
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
    )

    # Desktop Windows prod builders
    # Currently Windows is only supported on master and dev.
    if ref in (r"refs/heads/master", r"refs/heads/dev"):
        windows_desktop_tasks = [
            "hot_mode_dev_cycle_win_target__benchmark",
        ]
        for task in windows_desktop_tasks:
            common.windows_prod_builder(
                name = "Windows%s %s|%s" % (branched_builder_prefix, task, short_name(task)),
                recipe = drone_recipe_name,
                console_view_name = console_view_name,
                triggered_by = [trigger_name],
                triggering_policy = triggering_policy,
                properties = {
                    "task_name": task,
                },
                caches = WIN_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
    )
    common.linux_try_builder(
        name = "Linux gradle_desugar_classes_test|gjet",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}],
            "task_name": "gradle_desugar_classes_test",
        },
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
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
        caches = LINUX_DEFAULT_CACHES,
    )

    # Desktop Linux try builders
    linux_desktop_tasks = [
        "hot_mode_dev_cycle_linux_target__benchmark",
    ]
    for task in linux_desktop_tasks:
        common.linux_try_builder(
            name = "Linux %s|%s" % (task, short_name(task)),
            recipe = drone_recipe_name,
            repo = repos.FLUTTER,
            list_view_name = list_view_name,
            properties = {
                "dependencies": [
                    {
                        "dependency": "clang",
                    },
                    {
                        "dependency": "cmake",
                    },
                    {
                        "dependency": "ninja",
                    },
                ],
                "task_name": task,
            },
            caches = LINUX_DEFAULT_CACHES,
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
                "sdk_version": NEW_XCODE_VERSION,
            },
            "task_name": "module_test_ios",
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
                "sdk_version": NEW_XCODE_VERSION,
            },
            "task_name": "build_ios_framework_module_test",
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
                "sdk_version": NEW_XCODE_VERSION,
            },
            "task_name": "plugin_lint_mac",
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
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
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
    )

    # Desktop Windows try builders
    windows_desktop_tasks = [
        "hot_mode_dev_cycle_win_target__benchmark",
    ]
    for task in windows_desktop_tasks:
        common.windows_try_builder(
            name = "Windows %s|%s" % (task, short_name(task)),
            recipe = drone_recipe_name,
            repo = repos.FLUTTER,
            list_view_name = list_view_name,
            properties = {
                "task_name": task,
            },
            caches = WIN_DEFAULT_CACHES,
            os = "Windows-Server",
        )

devicelab_config = struct(setup = _setup)
