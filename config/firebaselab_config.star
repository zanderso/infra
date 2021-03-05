#!/usr/bin/env lucicfg
# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""
Configurations for firebaselab tests.

The schedulers pull commits indirectly from GoB repo (https://chromium.googlesource.com/external/github.com/flutter/flutter)
which is mirrored from https://github.com/flutter/flutter.
"""

load("//lib/common.star", "common")
load("//lib/repos.star", "repos")

# Global OS variables
LINUX_OS = "Linux"

def _setup(branches):
    firebaselab_prod_config(
        "stable",
        branches.stable.version,
        branches.stable.testing_ref,
    )
    firebaselab_prod_config(
        "beta",
        branches.beta.version,
        branches.beta.testing_ref,
    )
    firebaselab_prod_config(
        "dev",
        branches.dev.version,
        branches.dev.testing_ref,
    )
    firebaselab_prod_config(
        "master",
        branches.master.version,
        branches.master.testing_ref,
    )

    firebaselab_try_config()

def firebaselab_prod_config(branch, version, ref):
    """Prod configurations for the framework repository.

    Args:
      branch(str): The branch name we are creating configurations for.
      version(str): One of dev|beta|stable.
      ref(str): The git ref we are creating configurations for.
    """

    # TODO(godofredoc): Merge the recipe names once we remove the old one.
    recipe_name = ("firebaselab/firebaselab_" + version if version else "firebaselab/firebaselab")
    luci.recipe(
        name = recipe_name,
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )

    # Defines console views for prod builders
    console_view_name = ("firebaselab" if branch == "master" else "%s_firebaselab" % branch)
    luci.console_view(
        name = console_view_name,
        repo = repos.FLUTTER,
        refs = [ref],
    )

    # Defines prod schedulers
    trigger_name = branch + "-gitiles-trigger-firebaselab"
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

    # Defines firebaselab prod builders

    # Linux prod builders.
    common.linux_prod_builder(
        name = "Linux%s firebase_release_smoke_test|frst" % ("" if branch == "master" else " " + branch),
        recipe = recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}],
            "task_name": "release_smoke_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = LINUX_OS,
    )
    common.linux_prod_builder(
        name = "Linux%s firebase_abstract_method_smoke_test|fast" % ("" if branch == "master" else " " + branch),
        recipe = recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}],
            "task_name": "abstract_method_smoke_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = LINUX_OS,
    )
    common.linux_prod_builder(
        name = "Linux%s firebase_android_embedding_v2_smoke_test|faevst" % ("" if branch == "master" else " " + branch),
        recipe = recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}],
            "task_name": "android_embedding_v2_smoke_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = LINUX_OS,
    )

def firebaselab_try_config():
    """Try configurations for the framework repository."""

    recipe_name = "firebaselab/firebaselab"

    # Defines a list view for try builders
    list_view_name = "firebaselab-try"
    luci.list_view(
        name = "firebaselab-try",
        title = "firebaselab try builders",
    )

    # Defines firebase try builders

    # Linux try builders.
    common.linux_try_builder(
        name = "Linux firebase_release_smoke_test|frst",
        recipe = recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}],
            "task_name": "release_smoke_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = LINUX_OS,
    )
    common.linux_try_builder(
        name = "Linux firebase_abstract_method_smoke_test|fast",
        recipe = recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}],
            "task_name": "abstract_method_smoke_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = LINUX_OS,
    )
    common.linux_try_builder(
        name = "Linux firebase_android_embedding_v2_smoke_test|faevst",
        recipe = recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}],
            "task_name": "android_embedding_v2_smoke_test",
        },
        caches = [
            swarming.cache(name = "pub_cache", path = ".pub_cache"),
            swarming.cache(name = "android_sdk", path = "android29"),
        ],
        os = LINUX_OS,
    )

firebaselab_config = struct(setup = _setup)
