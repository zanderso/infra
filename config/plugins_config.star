#!/usr/bin/env lucicfg
# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""
Configurations for the plugins repository.
"""

load("//lib/common.star", "common")
load("//lib/repos.star", "repos")
load("//lib/timeout.star", "timeout")

WIN_DEFAULT_CACHES = [
    # Visual Studio
    swarming.cache(name = "vsbuild", path = "vsbuild"),
    # Pub cache
    swarming.cache(name = "pub_cache", path = ".pub-cache"),
]

def _setup(branches):
    """Set default configurations for builders, and setup recipes."""
    platform_args = {
        "windows": {
            "caches": WIN_DEFAULT_CACHES,
            "os": "Windows",
        },
        "linux": {
            "os": "Linux",
        },
    }
    plugins_define_recipes()
    plugins_try_config(platform_args)
    plugins_product_tagged_config_setup(platform_args)
    plugins_prod_config(
        "master",
        branches.master.version,
        branches.master.testing_ref,
        branches.master.release_ref,
        platform_args,
    )

def plugins_define_recipes():
    """Defines recipes for plugins repo."""
    luci.recipe(
        name = "plugins/plugins",
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )
    luci.recipe(
        name = "plugins/plugins_publish",
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
    )

def plugins_try_config(platform_args):
    """Detailed builder configures for different platforms.

    Args:
        platform_args (dict): The platform arguments passed to luci builders.
            For example:
            {
                "windows": {
                    "caches": [swarming.cache(name = "pub_cache", path = ".pub-cache")],
                }
            }
    """

    # Defines a list view for try builders
    list_view_name = "plugins-try"
    luci.list_view(
        name = list_view_name,
        title = "Plugins try builders",
    )

    # Defines plugins Windows platform try builders
    common.windows_try_builder(
        name = "Windows Plugins|windows",
        recipe = "plugins/plugins",
        list_view_name = list_view_name,
        repo = repos.PLUGINS,
        execution_timeout = timeout.SHORT,
        **platform_args["windows"]
    )

######### plugins prod config
def plugins_prod_config(branch, version, testing_ref, release_ref, platform_args):
    """Prod configurations for the plugins repository.

    Args:
      branch(str): The branch name we are creating configurations for.
      version(str): One of master|dev|beta|stable.
      testing_ref(str): The git ref we are creating configurations for.
      release_ref(str): The git ref used for releases.
      platform_args (dict): The platform arguments passed to luci builders.
            For example:
            {
                "windows": {
                    "caches": [swarming.cache(name = "pub_cache", path = ".pub-cache")],
                }
            }
    """
    recipe_name = ("plugins/plugins_" + version if version else "plugins/plugins")
    if branch != "master":
        luci.recipe(
            name = recipe_name,
            cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
            cipd_version = "refs/heads/master",
            use_bbagent = True,
        )

    # Defines console views for prod builders
    console_view_name = ("plugins" if branch == "master" else "%s_plugins" % branch)
    luci.console_view(
        name = console_view_name,
        repo = repos.PLUGINS,
        refs = [testing_ref],
    )

    # Defines prod schedulers
    trigger_name = branch + "-gitiles-trigger-plugins"
    luci.gitiles_poller(
        name = trigger_name,
        bucket = "prod",
        repo = repos.PLUGINS,
        refs = [testing_ref],
    )

    # Defines triggering policy
    if branch == "master":
        triggering_policy = scheduler.greedy_batching(
            max_batch_size = 1,
            max_concurrent_invocations = 3,
        )
    else:
        triggering_policy = scheduler.greedy_batching(
            max_batch_size = 1,
            max_concurrent_invocations = 3,
        )

    # Defines build priority, release builds should be prioritized.
    priority = 30 if branch == "master" else 29

    # Defines plugins Windows plugins builders
    common.windows_prod_builder(
        name = "Windows %s Plugins master channel|windows" % branch,
        recipe = recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        repo = repos.PLUGINS,
        execution_timeout = timeout.SHORT,
        **platform_args["windows"]
    )
    common.windows_prod_builder(
        name = "Windows %s Plugins stable channel|windows" % branch,
        recipe = recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        repo = repos.PLUGINS,
        execution_timeout = timeout.SHORT,
        properties = {"channel": "stable"},
        **platform_args["windows"]
    )

def plugins_product_tagged_config_setup(platform_args):
    """Builder configures for prod tasks, which were only triggered with tag changes.

    Args:
        platform_args (dict): The platform arguments passed to luci builders.
            For example:
            {
                "linux": {
                    "os": "Linux",
                },
            }
    """

    trigger_name = "gitiles-trigger-plugins-tagged"
    ref = "refs/tags/.+"

    # poll for any tags change
    luci.gitiles_poller(
        name = trigger_name,
        bucket = "prod",
        repo = repos.PLUGINS,
        refs = [ref],
    )

    console_view_name = "plugins_tagged"
    luci.console_view(
        name = console_view_name,
        repo = repos.PLUGINS,
        refs = [ref],
    )

    publish_recipe_name = "plugins/plugins_publish"

    # Defines builders
    common.linux_prod_builder(
        name = "Linux Publish Plugins|publish",
        recipe = publish_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        execution_timeout = timeout.SHORT,
        **platform_args["linux"]
    )

plugins_config = struct(setup = _setup)
