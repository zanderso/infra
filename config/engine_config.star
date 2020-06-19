#!/usr/bin/env lucicfg
# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""
Configurations for the flutter engine repository.

The schedulers pull commits indirectly from GoB repo
(https://chromium.googlesource.com/external/github.com/flutter/engine)
which is mirrored from https://github.com/flutter/engine.

Try jobs use github directly but are also registered with luci-cq
to take advantage of led recipe builder tests.
"""

load("//lib/common.star", "common")
load("//lib/repos.star", "repos")

FUCHSIA_CTL_VERSION = 'version:0.0.23'


def _setup(branches):
    """Default configurations for branches and repos."""
    platform_args = {
        'linux': {},
        'mac': {
            'caches':
            [swarming.cache(name='flutter_cocoapods', path='cocoapods')],
        },
        'windows': {},
    }

    for branch in branches:
        engine_recipes(branches[branch]['version'])
        engine_prod_config(
            platform_args,
            branch,
            branches[branch]['version'],
            branches[branch]['ref'],
        )

    engine_try_config(platform_args)


def full_recipe_name(recipe_name, version):
    """Creates a recipe name for recipe and version.

    Args:
      recipe_name: This is a string with the recipe base name.
      version: A string with the build version. E.g. dev, beta, stable.

    Returns:
      A string with the recipe's full name.
    """
    return recipe_name if not version else '%s_%s' % (recipe_name, version)


def engine_recipes(version):
    """Creates a luci recipe for a given code version."""
    for name in ['engine', 'web_engine', 'engine_builder']:
        luci.recipe(
            name=full_recipe_name(name, version),
            cipd_package=
            'flutter/recipe_bundles/flutter.googlesource.com/recipes',
            cipd_version='refs/heads/master',
        )


def engine_properties(build_host=False,
                      build_fuchsia=False,
                      build_android_debug=False,
                      build_android_aot=False,
                      build_android_vulkan=False,
                      build_ios=False,
                      needs_jazzy=False,
                      ios_debug=False,
                      ios_profile=False,
                      ios_release=False,
                      build_android_jit_release=False,
                      no_bitcode=False):
    """Creates build properties for engine based on parameters."""
    properties = {
        'build_host': build_host,
        'build_fuchsia': build_fuchsia,
        'build_android_debug': build_android_debug,
        'build_android_aot': build_android_aot,
        'build_android_vulkan': build_android_vulkan,
        'build_ios': build_ios,
        'build_android_jit_release': build_android_jit_release,
    }
    if (build_ios):
        properties['ios_debug'] = ios_debug
        properties['ios_profile'] = ios_profile
        properties['ios_release'] = ios_release
        properties['no_bitcode'] = no_bitcode
    if (needs_jazzy):
        properties['jazzy_version'] = '0.9.5'
    if (build_fuchsia):
        properties['fuchsia_ctl_version'] = FUCHSIA_CTL_VERSION
    return properties


def builder_name(pattern, branch):
    """Create a builder name using a string patter and branch."""
    return pattern % ('' if branch == 'master' else ' ' + branch)


def engine_prod_config(platform_args, branch, version, ref):
    """Creates prod engine configurations."""
    # Defines console views for prod builders
    console_view_name = ('engine' if branch == 'master' else '%s_engine' %
                         branch)
    luci.console_view(
        name=console_view_name,
        repo=repos.ENGINE,
        refs=[ref],
    )

    # Defines prod schedulers
    trigger_name = branch + '-gitiles-trigger-engine'
    luci.gitiles_poller(
        name=trigger_name,
        bucket='prod',
        repo=repos.ENGINE,
        refs=[ref],
    )

    # Defines triggering policy
    if branch == 'master':
        triggering_policy = scheduler.greedy_batching(
            max_concurrent_invocations=6)
    else:
        triggering_policy = scheduler.greedy_batching(
            max_batch_size=1, max_concurrent_invocations=3)

    # Defines web engine prod builders
    common.linux_prod_builder(
        name=builder_name('Linux%s Web Engine|lwe', branch),
        recipe=full_recipe_name('web_engine', version),
        console_view_name=console_view_name,
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['linux'],
    )
    common.mac_prod_builder(
        name=builder_name('Mac%s Web Engine|mwe', branch),
        recipe=full_recipe_name('web_engine', version),
        console_view_name=console_view_name,
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['mac'],
    )
    common.windows_prod_builder(
        name=builder_name('Windows%s Web Engine|wwe', branch),
        recipe=full_recipe_name('web_engine', version),
        console_view_name=console_view_name,
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['windows'],
    )
    # Defines engine Linux builders
    common.linux_prod_builder(
        name=builder_name('Linux%s Host Engine|host', branch),
        recipe=full_recipe_name('engine', version),
        console_view_name=console_view_name,
        properties=engine_properties(build_host=True),
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['linux'],
    )
    common.linux_prod_builder(
        name=builder_name('Linux%s Fuchsia|fsc', branch),
        recipe=full_recipe_name('engine', version),
        console_view_name=console_view_name,
        properties=engine_properties(build_fuchsia=True),
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['linux'],
    )
    common.linux_prod_builder(
        name=builder_name('Linux%s Android Debug Engine|dbg', branch),
        recipe=full_recipe_name('engine', version),
        console_view_name=console_view_name,
        properties=engine_properties(build_android_debug=True,
                                     build_android_vulkan=True,
                                     build_android_jit_release=True),
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['linux'],
    )
    common.linux_prod_builder(
        name=builder_name('Linux%s Android AOT Engine|aot', branch),
        recipe=full_recipe_name('engine', version),
        console_view_name=console_view_name,
        properties=engine_properties(build_android_aot=True),
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['linux'],
    )
    common.linux_prod_builder(
        name=builder_name('Linux%s Engine Drone|drn', branch),
        recipe=full_recipe_name('engine_builder', version),
        console_view_name=None,
        no_notify=True,
    )
    # Defines engine mac builders.
    common.mac_prod_builder(
        name=builder_name('Mac%s Host Engine|host', branch),
        recipe=full_recipe_name('engine', version),
        console_view_name=console_view_name,
        properties=engine_properties(build_host=True),
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['mac'],
    )
    common.mac_prod_builder(
        name=builder_name('Mac%s Android Debug Engine|dbg', branch),
        recipe=full_recipe_name('engine', version),
        console_view_name=console_view_name,
        properties=engine_properties(
            build_android_debug=True,
            build_android_vulkan=True,
        ),
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['mac'],
    )
    common.mac_prod_builder(
        name=builder_name('Mac%s Android AOT Engine|aot', branch),
        recipe=full_recipe_name('engine', version),
        console_view_name=console_view_name,
        properties=engine_properties(build_android_aot=True),
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['mac'],
    )
    common.mac_prod_builder(
        name=builder_name('Mac%s iOS Engine|ios', branch),
        recipe=full_recipe_name('engine', version),
        console_view_name=console_view_name,
        properties=engine_properties(
            build_ios=True,
            ios_debug=True,
            needs_jazzy=True,
        ),
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['mac'],
    )
    common.mac_prod_builder(
        name=builder_name('Mac%s iOS Engine Profile|ios', branch),
        recipe=full_recipe_name('engine', version),
        console_view_name=console_view_name,
        properties=engine_properties(
            build_ios=True,
            ios_profile=True,
            needs_jazzy=True,
        ),
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['mac'],
    )
    common.mac_prod_builder(
        name=builder_name('Mac%s iOS Engine Release|ios', branch),
        recipe=full_recipe_name('engine', version),
        console_view_name=console_view_name,
        properties=engine_properties(
            build_ios=True,
            ios_release=True,
            needs_jazzy=True,
        ),
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['mac'],
    )
    common.mac_prod_builder(
        name=builder_name('Mac%s Engine Drone|drn', branch),
        recipe=full_recipe_name('engine_builder', version),
        console_view_name=None,
        no_notify=True,
    )
    # Defines engine Windows builders
    common.windows_prod_builder(
        name=builder_name('Windows%s Host Engine|host', branch),
        recipe=full_recipe_name('engine', version),
        console_view_name=console_view_name,
        properties=engine_properties(build_host=True),
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['windows'],
    )
    common.windows_prod_builder(
        name=builder_name('Windows%s Android AOT Engine|aot', branch),
        recipe=full_recipe_name('engine', version),
        console_view_name=console_view_name,
        properties=engine_properties(build_android_aot=True),
        triggered_by=[trigger_name],
        triggering_policy=triggering_policy,
        **platform_args['windows'],
    )
    common.windows_prod_builder(name=builder_name('Windows%s Engine Drone|drn',
                                                  branch),
                                recipe=full_recipe_name(
                                    'engine_builder', version),
                                console_view_name=None,
                                no_notify=True)


def engine_try_config(platform_args):
    # Defines a list view for try builders
    list_view_name = 'engine-try'
    luci.list_view(
        name='engine-try',
        title='Engine try builders',
    )

    # Web Engine (all) try builders.
    common.linux_try_builder(
        name='Linux Web Engine|lwe',
        recipe='web_engine',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        **platform_args['linux'],
    )
    common.mac_try_builder(
        name='Mac Web Engine|mwe',
        recipe='web_engine',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        **platform_args['mac'],
    )
    common.windows_try_builder(
        name='Windows Web Engine|wwe',
        recipe='web_engine',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        **platform_args['windows'],
    )
    # Engine Linux try builders.
    common.linux_try_builder(
        name='Linux Host Engine|host',
        recipe='engine',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        properties=engine_properties(build_host=True),
        **platform_args['linux'],
    )
    common.linux_try_builder(
        name='Linux Fuchsia|fsc',
        recipe='engine',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        properties=engine_properties(build_fuchsia=True),
        **platform_args['linux'],
    )
    common.linux_try_builder(
        name='Linux Android Debug Engine|dbg',
        recipe='engine',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        properties=engine_properties(build_android_debug=True,
                                     build_android_vulkan=True),
        **platform_args['linux'],
    )
    common.linux_try_builder(
        name='Linux Android AOT Engine|aot',
        recipe='engine',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        properties=engine_properties(build_android_aot=True),
        **platform_args['linux'],
    )
    common.linux_try_builder(
        name='Linux Engine Drone|drn',
        recipe='engine_builder',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        **platform_args['linux'],
    )
    # Engine Linux try builders.
    common.mac_try_builder(
        name='Mac Host Engine|host',
        recipe='engine',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        properties=engine_properties(build_host=True),
        **platform_args['mac'],
    )
    common.mac_try_builder(
        name='Mac Android Debug Engine|dbg',
        recipe='engine',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        properties=engine_properties(
            build_android_debug=True,
            build_android_vulkan=True,
        ),
        **platform_args['mac'],
    )
    common.mac_try_builder(
        name='Mac Android AOT Engine|aot',
        recipe='engine',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        properties=engine_properties(build_android_aot=True, ),
        **platform_args['mac'],
    )
    common.mac_try_builder(
        name='Mac iOS Engine|ios',
        recipe='engine',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        properties=engine_properties(
            build_ios=True,
            ios_debug=True,
            needs_jazzy=True,
            no_bitcode=True,
        ),
        **platform_args['mac'],
    )
    common.mac_try_builder(
        name='Mac Engine Drone|drn',
        recipe='engine_builder',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        **platform_args['mac'],
    )
    # Engine Windows try builders.
    common.windows_try_builder(
        name='Windows Host Engine|host',
        recipe='engine',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        properties=engine_properties(build_host=True),
        **platform_args['windows'],
    )
    common.windows_try_builder(
        name='Windows Android AOT Engine|aot',
        recipe='engine',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
        properties=engine_properties(build_android_aot=True),
        **platform_args['windows'],
    )
    common.windows_try_builder(
        name='Windows Engine Drone|drn',
        recipe='engine_builder',
        repo=repos.ENGINE,
        list_view_name=list_view_name,
    )


engine_config = struct(setup=_setup, )
