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
        max_concurrent_invocations = 2,
    )
    # Defines framework prod builders

    # Mac prod builders.
    mac_tasks = [
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
        "smoke_catalina_start_up_ios",
        "tiles_scroll_perf_ios__timeline_summary",
    ]
    for task in mac_tasks:
        common.mac_prod_builder(
            name = "Mac %s|%s" % (task, short_name(task)),
            recipe = drone_recipe_name,
            console_view_name = console_view_name,
            triggered_by = [trigger_name],
            triggering_policy = triggering_policy,
            properties = {
                "$depot_tools/osx_sdk": {
                    "sdk_version": "12B5044c",  # 12.2
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
                    {
                        "dependency": "swift",
                        "version": "mcKOF86ehMsd3HNodm9m11lOTQ04p58iHeQ5uK-d8C4C",
                    },
                ],
                "task_name": task,
            },
            pool = "luci.flutter.staging",
            os = "Mac-10.15.7",
            dimensions = {"device_os": "iOS"},
            execution_timeout = timeout.SHORT,
            expiration_timeout = timeout.LONG_EXPIRATION,
        )

    # Linux prod builders.
    linux_tasks = [
        "analyzer_benchmark",
        "android_defines_test",
        "android_obfuscate_test",
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
        "dartdocs",
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
        "technical_debt__cost",
        "textfield_perf__e2e_summary",
        "web_size__compile_test",
    ]

    for task in linux_tasks:
        common.linux_prod_builder(
            name = "Linux %s|%s" % (task, short_name(task)),
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
        )

devicelab_staging_config = struct(setup = _setup)
