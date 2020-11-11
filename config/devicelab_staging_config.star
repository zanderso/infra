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
    common.mac_prod_builder(
        name = "Mac backdrop_filter_perf_ios__timeline_summary|bfpits",
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
            "task_name": "backdrop_filter_perf_ios__timeline_summary",
        },
        pool = "luci.flutter.staging",
        os = "Mac-10.15.7",
        dimensions = {"device_os": "14.1"},
    )

devicelab_staging_config = struct(setup = _setup)
