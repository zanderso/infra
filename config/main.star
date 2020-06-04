#!/usr/bin/env lucicfg
# Copyright 2019 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""
LUCI project configuration for the production instance of LUCI.

After modifying this file execute it ('./main.star') to regenerate the configs.

This file uses a Python-like syntax known as Starlark:
https://docs.bazel.build/versions/master/skylark/language.html

The documentation for lucicfg can be found here:
https://chromium.googlesource.com/infra/luci/luci-go/+/refs/heads/master/lucicfg/doc/README.md
"""

load("//lib/common.star", "common")
load("//lib/consoles.star", "consoles")
load("//lib/helpers.star", "helpers")
load("//lib/repos.star", "repos")
load("//lib/recipes.star", "recipes")
load("//recipes_config.star", "recipes_config")
load("//framework_config.star", "framework_config")

BRANCHES = {
    'stable': {
        'ref': r'refs/heads/flutter-1\.17-candidate\.3',
        # To be interpolated into recipe names e.g. 'flutter/flutter_' + BRANCHES['stable']['version']
        'version': 'v1_17_0',
    },
    'beta': {
        'ref': r'refs/heads/flutter-1\.18-candidate\.11',
        'version': '1_18_0',
    },
    'dev': {
        # Don't match the last number of the branch name or else this will have
        # to be updated for every dev release.
        'ref': r'refs/heads/flutter-1\.19-candidate\..+',
        'version': None,
    },
    'master': {
        'ref': r'refs/heads/master',
        'version': None,
    },
}

FUCHSIA_CTL_VERSION = 'version:0.0.23'

lucicfg.config(config_dir="generated/flutter",
               tracked_files=["**/*"],
               fail_on_warnings=True)

luci.project(
    name='flutter',
    config_dir="luci",
    buildbucket='cr-buildbucket.appspot.com',
    logdog='luci-logdog.appspot.com',
    milo='luci-milo.appspot.com',
    scheduler='luci-scheduler.appspot.com',
    swarming='chromium-swarm.appspot.com',
    notify='luci-notify.appspot.com',
    acls=[
        acl.entry(
            roles=[
                acl.BUILDBUCKET_READER,
                acl.LOGDOG_READER,
                acl.PROJECT_CONFIGS_READER,
                acl.SCHEDULER_READER,
            ],
            groups='all',
        ),
        acl.entry(
            roles=[
                acl.BUILDBUCKET_TRIGGERER,
                acl.SCHEDULER_TRIGGERER,
            ],
            groups='project-flutter-prod-schedulers',
        ),
        acl.entry(
            roles=[
                acl.BUILDBUCKET_OWNER,
                acl.SCHEDULER_OWNER,
            ],
            groups='project-flutter-admins',
        ),
        acl.entry(
            acl.LOGDOG_WRITER,
            groups='luci-logdog-chromium-writers',
        ),
        acl.entry(
            roles=[acl.CQ_COMMITTER, acl.CQ_DRY_RUNNER],
            groups=["project-flutter-try-schedulers"],
        ),
    ],
)

luci.logdog(gs_bucket='chromium-luci-logdog')

luci.milo(
    logo=
    'https://storage.googleapis.com/chrome-infra-public/logo/flutter-logo.svg',
    favicon='https://storage.googleapis.com/flutter_infra/favicon.ico',
)

luci.bucket(
    name='prod',
    acls=[
        acl.entry(acl.BUILDBUCKET_TRIGGERER,
                  groups='project-flutter-prod-schedulers'),
        acl.entry(acl.SCHEDULER_TRIGGERER,
                  groups='project-flutter-prod-schedulers'),
    ],
)

luci.bucket(
    name='try',
    acls=[
        acl.entry(acl.BUILDBUCKET_TRIGGERER,
                  groups='project-flutter-try-schedulers')
    ],
)

# Common recipe group configurations.
common.cq_group(repos.FLUTTER_RECIPES)

luci.builder.defaults.dimensions.set({
    "cpu": common.TARGET_X64,
    "os": "Linux",
})

luci.builder.defaults.properties.set({
    '$kitchen': {
        'emulate_gce': True
    },
    '$build/goma': {
        'use_luci_auth': True
    },
    '$recipe_engine/isolated': {
        "server": "https://isolateserver.appspot.com"
    },
    '$recipe_engine/swarming': {
        "server": "https://chromium-swarm.appspot.com"
    },
    'mastername':
    'client.flutter',
    'goma_jobs':
    '200',
    'android_sdk_license':
    '\n24333f8a63b6825ea9c5514f83c2829b004d1fee',
    'android_sdk_preview_license':
    '\n84831b9409646a918e30573bab4c9c91346d8abd',
})

############################ End Global Defaults ############################

recipes_config.setup()

framework_config.setup(BRANCHES)

######################### Console Definitions #################################

console_names = struct(
    engine=consoles.console_view(
        'engine',
        repos.ENGINE,
    ),
    stable_engine=consoles.console_view(
        'stable_engine',
        repos.ENGINE,
        [BRANCHES['stable']['ref']],
    ),
    beta_engine=consoles.console_view(
        'beta_engine',
        repos.ENGINE,
        [BRANCHES['beta']['ref']],
    ),
    dev_engine=consoles.console_view(
        'dev_engine',
        repos.ENGINE,
        [BRANCHES['dev']['ref']],
    ),
    packaging=consoles.console_view(
        'packaging',
        repos.FLUTTER,
        refs=['refs/heads/beta', 'refs/heads/dev', 'refs/heads/stable'],
        exclude_ref='refs/heads/master',
    ),
)

########################## Engine builders ###################################
common_web_engine_builders = {
    'recipe': 'web_engine',
    'list_view_name': 'engine-try',
}

common_scheduled_web_engine_builders = helpers.merge_dicts(
    common_web_engine_builders, {
        'console_view_name':
        'engine',
        'list_view_name':
        'engine',
        'triggered_by': ['master-gitiles-trigger-engine'],
        'triggering_policy':
        scheduler.greedy_batching(max_batch_size=1,
                                  max_concurrent_invocations=3)
    })

common.linux_try_builder(name='Linux Web Engine|lwe',
                         **common_web_engine_builders)
common.mac_try_builder(name='Mac Web Engine|mwe', **common_web_engine_builders)
common.windows_try_builder(name='Windows Web Engine|wwe',
                           **common_web_engine_builders)
common.linux_prod_builder(name='Linux Web Engine|lwe',
                          **common_scheduled_web_engine_builders)

common.mac_prod_builder(name='Mac Web Engine|mwe',
                        **common_scheduled_web_engine_builders)
common.windows_prod_builder(name='Windows Web Engine|wwe',
                            **common_scheduled_web_engine_builders)
###############################################################################

# Gitiles pollers

luci.gitiles_poller(
    name='master-gitiles-trigger-engine',
    bucket='prod',
    repo=repos.ENGINE,
)

luci.gitiles_poller(
    name='stable-gitiles-trigger-engine',
    bucket='prod',
    repo=repos.ENGINE,
    refs=[BRANCHES['stable']['ref']],
)

luci.gitiles_poller(
    name='beta-gitiles-trigger-engine',
    bucket='prod',
    repo=repos.ENGINE,
    refs=[BRANCHES['beta']['ref']],
)

luci.gitiles_poller(
    name='dev-gitiles-trigger-engine',
    bucket='prod',
    repo=repos.ENGINE,
    refs=[BRANCHES['dev']['ref']],
)

luci.gitiles_poller(
    name='gitiles-trigger-dev-packaging',
    bucket='prod',
    repo=repos.FLUTTER,
    refs=['refs/heads/dev'],
)

luci.gitiles_poller(
    name='gitiles-trigger-beta-packaging',
    bucket='prod',
    repo=repos.FLUTTER,
    refs=['refs/heads/beta'],
)

luci.gitiles_poller(
    name='gitiles-trigger-stable-packaging',
    bucket='prod',
    repo=repos.FLUTTER,
    refs=['refs/heads/stable'],
)


# Recipe definitions.
def recipe(name):
    luci.recipe(
        name=name,
        cipd_package='flutter/recipe_bundles/flutter.googlesource.com/recipes',
        cipd_version='refs/heads/master',
    )


recipe('cocoon')
recipe('engine')
recipe('engine_' + BRANCHES['stable']['version'])
recipe('engine_' + BRANCHES['beta']['version'])
recipe('engine_builder')
recipe('engine_builder_' + BRANCHES['stable']['version'])
recipe('engine_builder_' + BRANCHES['beta']['version'])
recipe('ios-usb-dependencies')
recipe('web_engine')
recipe('fuchsia_ctl')

luci.list_view(
    name='cocoon-try',
    title='Cocoon try builders',
)
luci.list_view(
    name='engine-try',
    title='Engine try builders',
)
luci.list_view(
    name='fuchsia_ctl-try',
    title='fuchsia_ctl try builders',
)

# Builder-defining functions

COMMON_LINUX_COCOON_BUILDER_ARGS = {
    'recipe': 'cocoon',
    'console_view_name': 'cocoon',
    'list_view_name': 'cocoon-try',
    'caches': [swarming.cache(name='dart_pub_cache', path='.pub-cache')],
}

common.linux_try_builder(name='Cocoon|cocoon',
                         **COMMON_LINUX_COCOON_BUILDER_ARGS)

COMMON_ENGINE_BUILDER_ARGS = {
    'recipe': 'engine',
    'console_view_name': 'engine',
    'list_view_name': 'engine-try',
}

COMMON_SCHEDULED_ENGINE_BUILDER_ARGS = helpers.merge_dicts(
    COMMON_ENGINE_BUILDER_ARGS, {
        'triggered_by': ['master-gitiles-trigger-engine'],
        'triggering_policy':
        scheduler.greedy_batching(max_batch_size=1,
                                  max_concurrent_invocations=3)
    })

COMMON_STABLE_ENGINE_BUILDER_ARGS = helpers.merge_dicts(
    COMMON_ENGINE_BUILDER_ARGS, {
        'console_view_name':
        console_names.stable_engine,
        'recipe':
        'engine_' + BRANCHES['stable']['version'],
        'triggered_by': ['stable-gitiles-trigger-engine'],
        'triggering_policy':
        scheduler.greedy_batching(max_batch_size=1,
                                  max_concurrent_invocations=3)
    })

COMMON_BETA_ENGINE_BUILDER_ARGS = helpers.merge_dicts(
    COMMON_ENGINE_BUILDER_ARGS, {
        'console_view_name':
        console_names.beta_engine,
        'recipe':
        'engine_' + BRANCHES['beta']['version'],
        'triggered_by': ['beta-gitiles-trigger-engine'],
        'triggering_policy':
        scheduler.greedy_batching(max_batch_size=1,
                                  max_concurrent_invocations=3)
    })

COMMON_DEV_ENGINE_BUILDER_ARGS = helpers.merge_dicts(
    COMMON_ENGINE_BUILDER_ARGS, {
        'console_view_name':
        console_names.dev_engine,
        'triggered_by': ['dev-gitiles-trigger-engine'],
        'triggering_policy':
        scheduler.greedy_batching(max_batch_size=1,
                                  max_concurrent_invocations=3)
    })


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


common.linux_prod_builder(name='Linux Host Engine|host',
                          properties=engine_properties(build_host=True),
                          **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux Fuchsia|fsc',
                          properties=engine_properties(build_fuchsia=True),
                          **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux Android Debug Engine|dbg',
                          properties=engine_properties(
                              build_android_debug=True,
                              build_android_vulkan=True,
                              build_android_jit_release=True),
                          **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux Android AOT Engine|aot',
                          properties=engine_properties(build_android_aot=True),
                          **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux Engine Drone|drn',
                          recipe='engine_builder',
                          console_view_name=None,
                          no_notify=True)

common.linux_prod_builder(name='Linux stable Host Engine|host',
                          properties=engine_properties(build_host=True),
                          **COMMON_STABLE_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux stable Fuchsia|fsc',
                          properties=engine_properties(build_fuchsia=True),
                          **COMMON_STABLE_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux stable Android Debug Engine|dbg',
                          properties=engine_properties(
                              build_android_debug=True,
                              build_android_vulkan=True,
                              build_android_jit_release=True),
                          **COMMON_STABLE_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux stable Android AOT Engine|aot',
                          properties=engine_properties(build_android_aot=True),
                          **COMMON_STABLE_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux stable Engine Drone|drn',
                          recipe='engine_builder_' +
                          BRANCHES['stable']['version'],
                          console_view_name=None,
                          no_notify=True)

common.linux_prod_builder(name='Linux beta Host Engine|host',
                          properties=engine_properties(build_host=True),
                          **COMMON_BETA_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux beta Fuchsia|fsc',
                          properties=engine_properties(build_fuchsia=True),
                          **COMMON_BETA_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux beta Android Debug Engine|dbg',
                          properties=engine_properties(
                              build_android_debug=True,
                              build_android_vulkan=True,
                              build_android_jit_release=True),
                          **COMMON_BETA_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux beta Android AOT Engine|aot',
                          properties=engine_properties(build_android_aot=True),
                          **COMMON_BETA_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux beta Engine Drone|drn',
                          recipe='engine_builder_' +
                          BRANCHES['beta']['version'],
                          console_view_name=None,
                          no_notify=True)

common.linux_prod_builder(name='Linux dev Host Engine|host',
                          properties=engine_properties(build_host=True),
                          **COMMON_DEV_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux dev Fuchsia|fsc',
                          properties=engine_properties(build_fuchsia=True),
                          **COMMON_DEV_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux dev Android Debug Engine|dbg',
                          properties=engine_properties(
                              build_android_debug=True,
                              build_android_vulkan=True,
                              build_android_jit_release=True),
                          **COMMON_DEV_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux dev Android AOT Engine|aot',
                          properties=engine_properties(build_android_aot=True),
                          **COMMON_DEV_ENGINE_BUILDER_ARGS)
common.linux_prod_builder(name='Linux dev Engine Drone|drn',
                          console_view_name=None,
                          recipe='engine_builder',
                          no_notify=True)

common.linux_try_builder(name='Linux Host Engine|host',
                         properties=engine_properties(build_host=True),
                         **COMMON_ENGINE_BUILDER_ARGS)
common.linux_try_builder(name='Linux Fuchsia|fsc',
                         properties=engine_properties(build_fuchsia=True),
                         **COMMON_ENGINE_BUILDER_ARGS)
common.linux_try_builder(name='Linux Android Debug Engine|dbg',
                         properties=engine_properties(
                             build_android_debug=True,
                             build_android_vulkan=True),
                         **COMMON_ENGINE_BUILDER_ARGS)
common.linux_try_builder(name='Linux Android AOT Engine|aot',
                         properties=engine_properties(build_android_aot=True),
                         **COMMON_ENGINE_BUILDER_ARGS)
common.linux_try_builder(name='Linux Engine Drone|drn',
                         recipe='engine_builder',
                         list_view_name='engine-try')

common.mac_prod_builder(name='Mac Host Engine|host',
                        properties=engine_properties(build_host=True),
                        **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac Android Debug Engine|dbg',
                        properties=engine_properties(
                            build_android_debug=True,
                            build_android_vulkan=True),
                        **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac Android AOT Engine|aot',
                        properties=engine_properties(build_android_aot=True),
                        **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac iOS Engine|ios',
                        properties=engine_properties(build_ios=True,
                                                     ios_debug=True,
                                                     needs_jazzy=True),
                        **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac iOS Engine Profile|ios',
                        properties=engine_properties(build_ios=True,
                                                     ios_profile=True,
                                                     needs_jazzy=True),
                        **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac iOS Engine Release|ios',
                        properties=engine_properties(build_ios=True,
                                                     ios_release=True,
                                                     needs_jazzy=True),
                        **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac Engine Drone|drn',
                        recipe='engine_builder',
                        console_view_name=None,
                        no_notify=True)

# Mac Engine Stable Builders
common.mac_prod_builder(name='Mac stable Host Engine|host',
                        properties=engine_properties(build_host=True),
                        **COMMON_STABLE_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac stable Android Debug Engine|dbg',
                        properties=engine_properties(
                            build_android_debug=True,
                            build_android_vulkan=True),
                        **COMMON_STABLE_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac stable Android AOT Engine|aot',
                        properties=engine_properties(build_android_aot=True),
                        **COMMON_STABLE_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac stable iOS Engine|ios',
                        properties=engine_properties(build_ios=True,
                                                     ios_debug=True,
                                                     needs_jazzy=True),
                        **COMMON_STABLE_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac stable iOS Engine Profile|ios',
                        properties=engine_properties(build_ios=True,
                                                     ios_profile=True,
                                                     needs_jazzy=True),
                        **COMMON_STABLE_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac stable iOS Engine Release|ios',
                        properties=engine_properties(build_ios=True,
                                                     ios_release=True,
                                                     needs_jazzy=True),
                        **COMMON_STABLE_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac stable Engine Drone|drn',
                        recipe='engine_builder',
                        console_view_name=None,
                        no_notify=True)

# Mac Engine Beta Builders
common.mac_prod_builder(name='Mac beta Host Engine|host',
                        properties=engine_properties(build_host=True),
                        **COMMON_BETA_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac beta Android Debug Engine|dbg',
                        properties=engine_properties(
                            build_android_debug=True,
                            build_android_vulkan=True),
                        **COMMON_BETA_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac beta Android AOT Engine|aot',
                        properties=engine_properties(build_android_aot=True),
                        **COMMON_BETA_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac beta iOS Engine|ios',
                        properties=engine_properties(build_ios=True,
                                                     ios_debug=True,
                                                     needs_jazzy=True),
                        **COMMON_BETA_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac beta iOS Engine Profile|ios',
                        properties=engine_properties(build_ios=True,
                                                     ios_profile=True,
                                                     needs_jazzy=True),
                        **COMMON_BETA_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac beta iOS Engine Release|ios',
                        properties=engine_properties(build_ios=True,
                                                     ios_release=True,
                                                     needs_jazzy=True),
                        **COMMON_BETA_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac beta Engine Drone|drn',
                        recipe='engine_builder',
                        console_view_name=None,
                        no_notify=True)

# Mac Engine Dev Builders
common.mac_prod_builder(name='Mac dev Host Engine|host',
                        properties=engine_properties(build_host=True),
                        **COMMON_DEV_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac dev Android Debug Engine|dbg',
                        properties=engine_properties(
                            build_android_debug=True,
                            build_android_vulkan=True),
                        **COMMON_DEV_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac dev Android AOT Engine|aot',
                        properties=engine_properties(build_android_aot=True),
                        **COMMON_DEV_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac dev iOS Engine|ios',
                        properties=engine_properties(build_ios=True,
                                                     ios_debug=True,
                                                     needs_jazzy=True),
                        **COMMON_DEV_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac dev iOS Engine Profile|ios',
                        properties=engine_properties(build_ios=True,
                                                     ios_profile=True,
                                                     needs_jazzy=True),
                        **COMMON_DEV_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac dev iOS Engine Release|ios',
                        properties=engine_properties(build_ios=True,
                                                     ios_release=True,
                                                     needs_jazzy=True),
                        **COMMON_DEV_ENGINE_BUILDER_ARGS)
common.mac_prod_builder(name='Mac dev Engine Drone|drn',
                        recipe='engine_builder',
                        console_view_name=None,
                        no_notify=True)

common.mac_try_builder(name='Mac Host Engine|host',
                       properties=engine_properties(build_host=True),
                       **COMMON_ENGINE_BUILDER_ARGS)
common.mac_try_builder(name='Mac Android Debug Engine|dbg',
                       properties=engine_properties(build_android_debug=True,
                                                    build_android_vulkan=True),
                       **COMMON_ENGINE_BUILDER_ARGS)
common.mac_try_builder(name='Mac Android AOT Engine|aot',
                       properties=engine_properties(build_android_aot=True),
                       **COMMON_ENGINE_BUILDER_ARGS)
common.mac_try_builder(name='Mac iOS Engine|ios',
                       properties=engine_properties(build_ios=True,
                                                    ios_debug=True,
                                                    needs_jazzy=True,
                                                    no_bitcode=True),
                       **COMMON_ENGINE_BUILDER_ARGS)
common.mac_try_builder(name='Mac Engine Drone|drn',
                       recipe='engine_builder',
                       list_view_name='engine-try')

common.windows_prod_builder(name='Windows Host Engine|host',
                            properties=engine_properties(build_host=True),
                            **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
common.windows_prod_builder(
    name='Windows Android AOT Engine|aot',
    properties=engine_properties(build_android_aot=True),
    **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
common.windows_prod_builder(name='Windows Engine Drone|drn',
                            recipe='engine_builder',
                            console_view_name=None,
                            no_notify=True)

common.windows_prod_builder(name='Windows stable Host Engine|host',
                            properties=engine_properties(build_host=True),
                            **COMMON_STABLE_ENGINE_BUILDER_ARGS)
common.windows_prod_builder(
    name='Windows stable Android AOT Engine|aot',
    properties=engine_properties(build_android_aot=True),
    **COMMON_STABLE_ENGINE_BUILDER_ARGS)
common.windows_prod_builder(name='Windows stable Engine Drone|drn',
                            recipe='engine_builder',
                            console_view_name=None,
                            no_notify=True)

common.windows_prod_builder(name='Windows beta Host Engine|host',
                            properties=engine_properties(build_host=True),
                            **COMMON_BETA_ENGINE_BUILDER_ARGS)
common.windows_prod_builder(
    name='Windows beta Android AOT Engine|aot',
    properties=engine_properties(build_android_aot=True),
    **COMMON_BETA_ENGINE_BUILDER_ARGS)
common.windows_prod_builder(name='Windows beta Engine Drone|drn',
                            recipe='engine_builder',
                            console_view_name=None,
                            no_notify=True)

common.windows_prod_builder(name='Windows dev Host Engine|host',
                            properties=engine_properties(build_host=True),
                            **COMMON_DEV_ENGINE_BUILDER_ARGS)
common.windows_prod_builder(
    name='Windows dev Android AOT Engine|aot',
    properties=engine_properties(build_android_aot=True),
    **COMMON_DEV_ENGINE_BUILDER_ARGS)
common.windows_prod_builder(name='Windows dev Engine Drone|drn',
                            recipe='engine_builder',
                            console_view_name=None,
                            no_notify=True)

common.windows_try_builder(name='Windows Host Engine|host',
                           properties=engine_properties(build_host=True),
                           **COMMON_ENGINE_BUILDER_ARGS)
common.windows_try_builder(
    name='Windows Android AOT Engine|aot',
    properties=engine_properties(build_android_aot=True),
    **COMMON_ENGINE_BUILDER_ARGS)
common.windows_try_builder(name='Windows Engine Drone|drn',
                           recipe='engine_builder',
                           list_view_name='engine-try')

DEV_PACKAGING_BUILDER_ARGS = {
    'recipe': 'flutter',
    'console_view_name': console_names.packaging,
    'triggered_by': ['gitiles-trigger-dev-packaging'],
}

BETA_PACKAGING_BUILDER_ARGS = {
    'recipe': 'flutter_' + BRANCHES['beta']['version'],
    'console_view_name': console_names.packaging,
    'triggered_by': ['gitiles-trigger-beta-packaging'],
}

STABLE_PACKAGING_BUILDER_ARGS = {
    'recipe': 'flutter_' + BRANCHES['stable']['version'],
    'console_view_name': console_names.packaging,
    'triggered_by': ['gitiles-trigger-stable-packaging'],
}

common.linux_prod_builder(name='Linux Flutter Dev Packaging|dev',
                          **DEV_PACKAGING_BUILDER_ARGS)
common.mac_prod_builder(name='Mac Flutter Dev Packaging|dev',
                        **DEV_PACKAGING_BUILDER_ARGS)
common.windows_prod_builder(name='Windows Flutter Dev Packaging|dev',
                            **DEV_PACKAGING_BUILDER_ARGS)

common.linux_prod_builder(name='Linux Flutter Beta Packaging|beta',
                          **BETA_PACKAGING_BUILDER_ARGS)
common.mac_prod_builder(name='Mac Flutter Beta Packaging|beta',
                        **BETA_PACKAGING_BUILDER_ARGS)
common.windows_prod_builder(name='Windows Flutter Beta Packaging|beta',
                            **BETA_PACKAGING_BUILDER_ARGS)

common.linux_prod_builder(name='Linux Flutter Stable Packaging|stbl',
                          **STABLE_PACKAGING_BUILDER_ARGS)
common.mac_prod_builder(name='Mac Flutter Stable Packaging|stbl',
                        **STABLE_PACKAGING_BUILDER_ARGS)
common.windows_prod_builder(name='Windows Flutter Stable Packaging|stbl',
                            **STABLE_PACKAGING_BUILDER_ARGS)


def ios_tools_builder(**kwargs):
    builder = kwargs['name'].split('|')[0]
    repo = 'https://flutter-mirrors.googlesource.com/' + builder
    consoles.console_view(builder, repo)
    luci.gitiles_poller(name='gitiles-trigger-' + builder,
                        bucket='prod',
                        repo=repo,
                        triggers=[builder])
    return common.mac_prod_builder(recipe='ios-usb-dependencies',
                                   properties={
                                       'package_name': builder + '-flutter',
                                   },
                                   console_view_name=builder,
                                   triggering_policy=scheduler.greedy_batching(
                                       max_concurrent_invocations=1,
                                       max_batch_size=6),
                                   **kwargs)


ios_tools_builder(name='ideviceinstaller|idev')
ios_tools_builder(name='libimobiledevice|libi')
ios_tools_builder(name='libplist|plist')
ios_tools_builder(name='usbmuxd|usbmd')
ios_tools_builder(name='openssl|ssl')
ios_tools_builder(name='ios-deploy|deploy')
ios_tools_builder(name='libzip|zip')

common.linux_try_builder(name='fuchsia_ctl|fctl',
                         recipe='fuchsia_ctl',
                         list_view_name='fuchsia_ctl-try',
                         properties={'fuchsia_ctl_version': None})
