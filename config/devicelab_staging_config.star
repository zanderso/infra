#!/usr/bin/env lucicfg
# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""
Configurations for devicelab staging tests.

The schedulers pull commits indirectly from GoB repo (https://chromium.googlesource.com/external/github.com/flutter/flutter)
which is mirrored from https://github.com/flutter/flutter.
"""

load("//lib/common.star", "common")
load("//lib/repos.star", "repos")
load("//lib/timeout.star", "timeout")

# Default caches for Linux builders
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

# Default caches for Mac builders
MAC_DEFAULT_CACHES = [
    # Pub cache
    swarming.cache(name = "pub_cache", path = ".pub-cache"),
    # Flutter SDK code
    swarming.cache(name = "flutter_sdk", path = "flutter sdk"),
    # Xcode
    swarming.cache("xcode_binary"),
    swarming.cache("osx_sdk"),
]

def _setup():
    devicelab_staging_prod_config()

def short_name(task_name):
    """Create a short name for task name."""
    task_name = task_name.replace("__", "_")
    words = task_name.split("_")
    return "".join([w[0] for w in words])[:5]

def devicelab_staging_prod_config():
    """Staging configurations for the framework repository."""
    drone_recipe_name = "devicelab/devicelab_drone"
    luci.recipe(
        name = drone_recipe_name,
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )

    # Defines console views.
    console_view_name = "devicelab_staging"
    luci.console_view(
        name = console_view_name,
        repo = repos.FLUTTER,
        refs = [r"refs/heads/master"],
    )

    # Defines schedulers for staging builders.
    trigger_name = "master-gitiles-trigger-devicelab-staging"
    luci.gitiles_poller(
        name = trigger_name,
        bucket = "prod",
        repo = repos.FLUTTER,
        refs = [r"refs/heads/master"],
    )

    # Defines triggering policy
    triggering_policy = scheduler.greedy_batching(
        max_batch_size = 20,
        max_concurrent_invocations = 1,
    )
    # Defines framework prod builders

    # Mac prod builders.
    mac_ios_tasks = [
        "backdrop_filter_perf_ios__timeline_summary",
        "basic_material_app_ios__compile",
        "channels_integration_test_ios",
        "complex_layout_ios__compile",
        "complex_layout_ios__start_up",
        "complex_layout_scroll_perf_ios__timeline_summary",
        "external_ui_integration_test_ios",
        "flavors_test_ios",
        "flutter_gallery__transition_perf_e2e_ios",
        "flutter_gallery_ios__compile",
        "flutter_gallery_ios__start_up",
        "flutter_gallery_ios__transition_perf",
        "flutter_view_ios__start_up",
        "hello_world_ios__compile",
        "hot_mode_dev_cycle_macos_target__benchmark",
        "integration_ui_ios_driver",
        "integration_ui_ios_keyboard_resize",
        "integration_ui_ios_screenshot",
        "integration_ui_ios_textfield",
        "ios_app_with_extensions_test",
        "ios_content_validation_test",
        "ios_defines_test",
        "ios_platform_view_tests",
        "large_image_changer_perf_ios",
        "macos_chrome_dev_mode",
        "microbenchmarks_ios",
        "new_gallery_ios__transition_perf",
        "platform_channel_sample_test_ios",
        "platform_channel_sample_test_swift",
        "platform_interaction_test_ios",
        "platform_view_ios__start_up",
        "platform_views_scroll_perf_ios__timeline_summary",
        "post_backdrop_filter_perf_ios__timeline_summary",
        "simple_animation_perf_ios",
        "smoke_catalina_hot_mode_dev_cycle_ios__benchmark",
        "tiles_scroll_perf_ios__timeline_summary",
    ]
    for task in mac_ios_tasks:
        common.mac_prod_builder(
            name = "Mac_ios_staging %s|%s" % (task, short_name(task)),
            recipe = drone_recipe_name,
            console_view_name = console_view_name,
            triggered_by = [trigger_name],
            triggering_policy = triggering_policy,
            properties = {
                "$flutter/devicelab_osx_sdk": {
                    "sdk_version": "12c33",  # 12.3
                },
                "dependencies": [
                    {
                        "dependency": "xcode",
                    },
                    {
                        "dependency": "gems",
                    },
                    {
                        "dependency": "ios_signing",
                    },
                ],
                "task_name": task,
            },
            pool = "luci.flutter.staging",
            os = "iOS-14.4",
            execution_timeout = timeout.LONG,
            expiration_timeout = timeout.LONG_EXPIRATION,
            caches = MAC_DEFAULT_CACHES,
        )

    mac_ios32_tasks = [
        "native_ui_tests_ios32",
        "flutter_gallery__transition_perf_e2e_ios32",
    ]
    for task in mac_ios32_tasks:
        common.mac_prod_builder(
            name = "Mac_staging %s|%s" % (task, short_name(task)),
            recipe = drone_recipe_name,
            console_view_name = console_view_name,
            triggered_by = [trigger_name],
            triggering_policy = triggering_policy,
            properties = {
                "$flutter/osx_sdk": {
                    "sdk_version": "12c33",  # 12.3
                },
                "$flutter/devicelab_osx_sdk": {
                    "sdk_version": "12c33",  # 12.3
                },
                "dependencies": [
                    {
                        "dependency": "xcode",
                    },
                    {
                        "dependency": "gems",
                    },
                    {
                        "dependency": "ios_signing",
                    },
                ],
                "task_name": task,
            },
            pool = "luci.flutter.staging",
            os = "iOS-9.3.6",
            execution_timeout = timeout.LONG,
            expiration_timeout = timeout.LONG_EXPIRATION,
            caches = MAC_DEFAULT_CACHES,
        )

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
            name = "Mac_android_staging %s|%s" % (task, short_name(task)),
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
            },
            pool = "luci.flutter.staging",
            os = "Mac",
            category = "Mac_android",
            dimensions = {"device_os": "N"},
            expiration_timeout = timeout.LONG_EXPIRATION,
            execution_timeout = timeout.SHORT,
            caches = MAC_ANDROID_DEFAULT_CACHES,
        )

    # Linux prod builders.
    linux_tasks = [
        "analyzer_benchmark",
        "android_defines_test",
        "android_obfuscate_test",
        "android_view_scroll_perf__timeline_summary",
        "animated_placeholder_perf__e2e_summary",
    ]

    for task in linux_tasks:
        common.linux_prod_builder(
            name = "Linux_staging %s|%s" % (task, short_name(task)),
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
            },
            pool = "luci.flutter.staging",
            os = "Android",
            dimensions = {"device_os": "N"},
            expiration_timeout = timeout.LONG_EXPIRATION,
            caches = LINUX_DEFAULT_CACHES,
        )

devicelab_staging_config = struct(setup = _setup)
