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
    tasks = [
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
    for task in tasks:
        common.mac_prod_builder(
            name = "Mac %s|%s" % (task, short_name(task)),
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
            dimensions = {"device_os": "14.1"},
        )

devicelab_staging_config = struct(setup = _setup)
