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

load("//lib/accounts.star", "accounts")
load("//lib/common.star", "common")
load("//lib/builder_groups.star", "builder_groups")
load("//lib/repos.star", "repos")
load("//lib/recipes.star", "recipes")

COCOON_GIT = 'https://chromium.googlesource.com/external/github.com/flutter/cocoon'
FLUTTER_RECIPES_GIT = 'https://flutter.googlesource.com/recipes'
FLUTTER_GIT = 'https://chromium.googlesource.com/external/github.com/flutter/flutter'
ENGINE_GIT = 'https://chromium.googlesource.com/external/github.com/flutter/engine'
# TODO(fujino): Remove this once 1.12.13 is no longer latest stable
HOTFIX_REFS = 'refs/heads/v.+hotfixes'
STABLE_REFS = r'refs/heads/flutter-1\.12-candidate\.13'
# To be interpolated into recipe names e.g. 'flutter/flutter_' + STABLE_VERSION
STABLE_VERSION = 'v1_12_13'
BETA_REFS = r'refs/heads/flutter-1\.17-candidate\.3'
BETA_VERSION = 'v1_17_0'
FUCHSIA_CTL_VERSION = 'version:0.0.22'

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
        acl.entry(roles=[
            acl.BUILDBUCKET_TRIGGERER,
            acl.SCHEDULER_TRIGGERER,
        ],
                  groups='project-flutter-prod-schedulers'),
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
            roles=[acl.CQ_COMMITTER],
            groups=["project-flutter-try-schedulers"],
        ),
    ],
)

luci.logdog(gs_bucket='chromium-luci-logdog', )

luci.milo(
    logo=
    'https://storage.googleapis.com/chrome-infra-public/logo/flutter-logo.svg',
    favicon='https://storage.googleapis.com/flutter_infra/favicon.ico',
)

luci.bucket(name='prod',
            acls=[
                acl.entry(acl.BUILDBUCKET_TRIGGERER,
                          groups='project-flutter-prod-schedulers'),
                acl.entry(acl.SCHEDULER_TRIGGERER,
                          groups='project-flutter-prod-schedulers'),
            ])

luci.bucket(name='try',
            acls=[
                acl.entry(acl.BUILDBUCKET_TRIGGERER,
                          groups='project-flutter-try-schedulers')
            ])

# Global builder defaults
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

####################### Flutter Builder Definitions ############################

# Common recipe group configurations.
common.cq_group(repos.FLUTTER_RECIPES)

# Builder configuration to validate recipe changes in presubmit.
common.builder(
    name="recipes-unittest-only",
    builder_group=builder_groups.recipes_try,
    # This builder is very quick to run, so we run it on every CQ attempt to
    # minimize the chances of expectation file conflicts between CLs that land
    # around the same time.
    cq_disable_reuse=True,
    executable=recipes.recipe(name="recipes"),
    execution_timeout=10 * time.minute,
    location_regexp_exclude=[
        common.LOCATION_REGEXP_MARKDOWN, common.LOCATION_REGEXP_OWNERS
    ],
    properties={
        "remote": repos.FLUTTER_RECIPES,
        "unittest_only": True,
    },
    service_account=accounts.FLUTTER_TRY,
)

# Autoroller builder. This is used to roll flutter recipes dependencies.
common.builder(
    name="recipe-deps-roller",
    builder_group=builder_groups.recipes_prod,
    executable=luci.recipe(
        name="recipe_autoroller",
        cipd_package=
        "infra/recipe_bundles/chromium.googlesource.com/infra/infra",
        cipd_version="git_revision:647d5e58ec508f13ccd054f1516e78d7ca3bd540"),
    execution_timeout=20 * time.minute,
    properties={
        "db_gcs_bucket": "flutter-recipe-roller-db",
        "projects": {
            "flutter": "https://flutter.googlesource.com/recipes",
        }.items(),
    },
    schedule="with 1h interval",
    console_category='recipes',
    console_short_name='aroll')

###############################################################################

# Gitiles pollers
luci.gitiles_poller(
    name='master-gitiles-trigger-recipes',
    bucket='prod',
    repo=FLUTTER_RECIPES_GIT,
)

luci.gitiles_poller(
    name='master-gitiles-trigger-framework',
    bucket='prod',
    repo=FLUTTER_GIT,
)

luci.gitiles_poller(
    name='hotfix-gitiles-trigger-framework',
    bucket='prod',
    repo=FLUTTER_GIT,
    refs=[HOTFIX_REFS],
)

luci.gitiles_poller(
    name='stable-gitiles-trigger-framework',
    bucket='prod',
    repo=FLUTTER_GIT,
    refs=[STABLE_REFS],
)

luci.gitiles_poller(
    name='beta-gitiles-trigger-framework',
    bucket='prod',
    repo=FLUTTER_GIT,
    refs=[BETA_REFS],
)

luci.gitiles_poller(
    name='master-gitiles-trigger-engine',
    bucket='prod',
    repo=ENGINE_GIT,
)

luci.gitiles_poller(
    name='hotfix-gitiles-trigger-engine',
    bucket='prod',
    repo=ENGINE_GIT,
    refs=[HOTFIX_REFS],
)

luci.gitiles_poller(
    name='stable-gitiles-trigger-engine',
    bucket='prod',
    repo=ENGINE_GIT,
    refs=[STABLE_REFS],
)

luci.gitiles_poller(
    name='beta-gitiles-trigger-engine',
    bucket='prod',
    repo=ENGINE_GIT,
    refs=[BETA_REFS],
)

luci.gitiles_poller(
    name='gitiles-trigger-dev-packaging',
    bucket='prod',
    repo=FLUTTER_GIT,
    refs=['refs/heads/dev'],
)

luci.gitiles_poller(
    name='gitiles-trigger-beta-packaging',
    bucket='prod',
    repo=FLUTTER_GIT,
    refs=['refs/heads/beta'],
)

luci.gitiles_poller(
    name='gitiles-trigger-stable-packaging',
    bucket='prod',
    repo=FLUTTER_GIT,
    refs=['refs/heads/stable'],
)


# Recipe definitions.
def recipe(name):
    luci.recipe(
        name=name,
        cipd_package='flutter/recipe_bundles/flutter.googlesource.com/recipes',
        cipd_version='refs/heads/master',
    )


# Flutter recipe-bundler definition.
luci.recipe(
    name='recipe_bundler',
    cipd_package='infra/recipe_bundles/chromium.googlesource.com/infra/infra',
    cipd_version='git_revision:9c7c5d6669de83823c9a34c7da11c7891d09662d',
)

recipe('cocoon')
recipe('flutter')
recipe('flutter_' + STABLE_VERSION)
recipe('flutter_' + BETA_VERSION)
recipe('engine')
recipe('engine_' + STABLE_VERSION)
recipe('engine_' + BETA_VERSION)
recipe('engine_builder')
# TODO(fujino): uncomment when 1.17.0 is promoted to stable
# recipe('flutter/engine_builder_' + STABLE_VERSION)
recipe('engine_builder_' + BETA_VERSION)
recipe('ios-usb-dependencies')
recipe('web_engine')


# Console definitions
def console_view(name, repo, refs=['refs/heads/master'], exclude_ref=None):
    luci.console_view(
        name=name,
        repo=repo,
        refs=refs,
        exclude_ref=exclude_ref,
    )


console_view('framework', FLUTTER_GIT)
console_view('recipes', FLUTTER_RECIPES_GIT)
# TODO(fujino): Remove this (and all other hotfix references) once 1.12.13 is
# no longer stable
console_view('hotfix-framework', FLUTTER_GIT, [HOTFIX_REFS])
console_view('stable-framework', FLUTTER_GIT, [STABLE_REFS])
console_view('beta-framework', FLUTTER_GIT, [BETA_REFS])
console_view('engine', ENGINE_GIT)
console_view('hotfix-engine', ENGINE_GIT, [HOTFIX_REFS])
console_view('stable-engine', ENGINE_GIT, [STABLE_REFS])
console_view('beta-engine', ENGINE_GIT, [BETA_REFS])
console_view('packaging',
             FLUTTER_GIT,
             refs=['refs/heads/beta', 'refs/heads/dev', 'refs/heads/stable'],
             exclude_ref='refs/heads/master')

luci.list_view(
    name='cocoon-try',
    title='Cocoon try builders',
)
luci.list_view(
    name='framework-try',
    title='Framework try builders',
)
luci.list_view(
    name='engine-try',
    title='Engine try builders',
)
luci.list_view(
    name='web-engine-try',
    title='Web Engine try builders',
)

# Builder-defining functions


# Helpers:
def merge_dicts(a, b):
    """Return the result of merging two dicts.
  If matching values are both dicts or both lists, they will be merged (non-recursively).
  Args:
    a: first dict.
    b: second dict (takes priority).
  Returns:
    Merged dict.
  """
    a = dict(a)
    for k, bv in b.items():
        av = a.get(k)
        if type(av) == "dict" and type(bv) == "dict":
            a[k] = dict(av)
            a[k].update(bv)
        elif type(av) == "list" and type(bv) == "list":
            a[k] = av + bv
        else:
            a[k] = bv
    return a


# Builders
def builder(bucket,
            pool,
            name,
            recipe,
            os,
            properties={},
            cores=None,
            **kwargs):
    dimensions = {
        'pool': pool,
        'cpu': 'x64',
        'os': os,
    }
    if cores != None:
        dimensions['cores'] = cores
    name_parts = name.split('|')
    luci.builder(name=name_parts[0],
                 bucket=bucket,
                 executable=recipe,
                 properties=properties,
                 service_account='flutter-' + bucket +
                 '-builder@chops-service-accounts.iam.gserviceaccount.com',
                 execution_timeout=3 * time.hour,
                 dimensions=dimensions,
                 build_numbers=True,
                 **kwargs)


def try_builder(name,
                list_view_name,
                console_view_name=None,
                category=None,
                properties={},
                **kwargs):
    bucket = 'try'
    pool = 'luci.flutter.try'
    merged_properties = merge_dicts(properties, {
        'upload_packages': False,
        'gold_tryjob': True
    })
    name_parts = name.split('|')

    luci.list_view_entry(
        builder=bucket + '/' + name_parts[0],
        list_view=list_view_name,
    )

    return builder(bucket, pool, name, properties=merged_properties, **kwargs)


def prod_builder(name,
                 console_view_name,
                 category,
                 no_notify=False,
                 list_view_name=None,
                 properties={},
                 **kwargs):
    merged_properties = merge_dicts(properties, {
        'upload_packages': True,
        'gold_tryjob': False
    })
    bucket = 'prod'
    pool = 'luci.flutter.prod'
    name_parts = name.split('|')

    if console_view_name:
        luci.console_view_entry(
            builder=bucket + '/' + name_parts[0],
            console_view=console_view_name,
            category=category,
            short_name=name_parts[1],
        )

    notifies = None if no_notify else [
        luci.notifier(
            name='blamelist-on-new-failure',
            on_new_failure=True,
            notify_blamelist=True,
        ),
    ]

    return builder(bucket,
                   pool,
                   name,
                   properties=merged_properties,
                   notifies=notifies,
                   **kwargs)


def common_builder(**common_kwargs):
    def prod_job(*args, **kwargs):
        return prod_builder(*args, **merge_dicts(common_kwargs, kwargs))

    def try_job(*args, **kwargs):
        return try_builder(*args, **merge_dicts(common_kwargs, kwargs))

    return try_job, prod_job


def mac_builder(properties={}, caches=None, category='Mac', **kwargs):
    # see https://chrome-infra-packages.appspot.com/p/infra_internal/ios/xcode/mac/+/
    properties = merge_dicts(
        {
            '$depot_tools/osx_sdk': {
                'sdk_version': '11a420a',  # 11.0
            },
        },
        properties)
    mac_caches = [swarming.cache('osx_sdk')]
    if caches != None:
        mac_caches.extend(caches)
    return common_builder(os='Mac-10.14',
                          properties=properties,
                          caches=mac_caches,
                          category=category,
                          **kwargs)


def linux_builder(properties={},
                  caches=None,
                  cores='8',
                  category='Linux',
                  os=None,
                  **kwargs):
    linux_caches = [
        swarming.cache(name='flutter_openjdk_install', path='java')
    ]
    properties['fuchsia_ctl_version'] = FUCHSIA_CTL_VERSION
    if caches != None:
        linux_caches.extend(caches)
    return common_builder(os=os or 'Linux',
                          cores=cores,
                          properties=properties,
                          caches=linux_caches,
                          category=category,
                          **kwargs)


def windows_builder(properties={},
                    caches=None,
                    cores='8',
                    category='Windows',
                    **kwargs):
    windows_caches = [
        swarming.cache(name='flutter_openjdk_install', path='java')
    ]
    if caches != None:
        windows_caches.extend(caches)
    return common_builder(os='Windows-10',
                          cores=cores,
                          properties=properties,
                          caches=windows_caches,
                          category=category,
                          **kwargs)


linux_try_builder, linux_prod_builder = linux_builder()
mac_try_builder, mac_prod_builder = mac_builder()
windows_try_builder, windows_prod_builder = windows_builder()

COMMON_LINUX_COCOON_BUILDER_ARGS = {
    'recipe': 'cocoon',
    'console_view_name': 'cocoon',
    'list_view_name': 'cocoon-try',
    'caches': [swarming.cache(name='dart_pub_cache', path='.pub-cache')],
}

COMMON_LINUX_RECIPES_BUILDER_ARGS = {
    'recipe':
    'recipe_bundler',
    'console_view_name':
    'recipes',
    'triggered_by': ['master-gitiles-trigger-recipes'],
    'triggering_policy':
    scheduler.greedy_batching(max_batch_size=1, max_concurrent_invocations=3),
    'properties': {
        'package_name_prefix':
        'flutter/recipe_bundles',
        'package_name_internal_prefix':
        'flutter_internal/recipe_bundles',
        'recipe_bundler_vers':
        'git_revision:2ed88b2c854578b512e1c0486824175fe0d7aab6',
        'repo_specs': [
            'flutter.googlesource.com/recipes=FETCH_HEAD,refs/heads/master',
        ],
    },
}

COMMON_FRAMEWORK_BUILDER_ARGS = {
    'recipe': 'flutter',
    'console_view_name': 'framework',
    'list_view_name': 'framework-try',
}

COMMON_HOTFIX_FRAMEWORK_BUILDER_ARGS = merge_dicts(
    COMMON_FRAMEWORK_BUILDER_ARGS, {
        'console_view_name':
        'hotfix-framework',
        'recipe':
        'flutter_' + STABLE_VERSION,
        'triggered_by': ['hotfix-gitiles-trigger-framework'],
        'triggering_policy':
        scheduler.greedy_batching(max_batch_size=1,
                                  max_concurrent_invocations=3),
    })

COMMON_STABLE_FRAMEWORK_BUILDER_ARGS = merge_dicts(
    COMMON_FRAMEWORK_BUILDER_ARGS, {
        'console_view_name':
        'stable-framework',
        'recipe':
        'flutter_' + STABLE_VERSION,
        'triggered_by': ['stable-gitiles-trigger-framework'],
        'triggering_policy':
        scheduler.greedy_batching(max_batch_size=1,
                                  max_concurrent_invocations=3),
    })

COMMON_BETA_FRAMEWORK_BUILDER_ARGS = merge_dicts(
    COMMON_FRAMEWORK_BUILDER_ARGS, {
        'console_view_name':
        'beta-framework',
        'recipe':
        'flutter_' + BETA_VERSION,
        'triggered_by': ['beta-gitiles-trigger-framework'],
        'triggering_policy':
        scheduler.greedy_batching(max_batch_size=1,
                                  max_concurrent_invocations=3),
    })

COMMON_SCHEDULED_FRAMEWORK_BUILDER_ARGS = merge_dicts(
    COMMON_FRAMEWORK_BUILDER_ARGS, {
        'triggered_by': ['master-gitiles-trigger-framework'],
        'triggering_policy':
        scheduler.greedy_batching(max_concurrent_invocations=6),
    })

FRAMEWORK_MAC_EXTRAS = {
    'properties': {
        'shard': 'framework_tests',
        'cocoapods_version': '1.6.0'
    },
    'caches': [swarming.cache(name='flutter_cocoapods', path='cocoapods')],
}

COMMON_MAC_FRAMEWORK_BUILDER_ARGS = merge_dicts(COMMON_FRAMEWORK_BUILDER_ARGS,
                                                FRAMEWORK_MAC_EXTRAS)

COMMON_SCHEDULED_MAC_FRAMEWORK_BUILDER_ARGS = merge_dicts(
    COMMON_MAC_FRAMEWORK_BUILDER_ARGS, COMMON_SCHEDULED_FRAMEWORK_BUILDER_ARGS)

COMMON_HOTFIX_MAC_FRAMEWORK_BUILDER_ARGS = merge_dicts(
    COMMON_MAC_FRAMEWORK_BUILDER_ARGS, COMMON_HOTFIX_FRAMEWORK_BUILDER_ARGS)

COMMON_STABLE_MAC_FRAMEWORK_BUILDER_ARGS = merge_dicts(
    COMMON_MAC_FRAMEWORK_BUILDER_ARGS, COMMON_STABLE_FRAMEWORK_BUILDER_ARGS)

COMMON_BETA_MAC_FRAMEWORK_BUILDER_ARGS = merge_dicts(
    COMMON_MAC_FRAMEWORK_BUILDER_ARGS, COMMON_BETA_FRAMEWORK_BUILDER_ARGS)

linux_prod_builder(name='Linux|frwk',
                   properties={'shard': 'framework_tests'},
                   **COMMON_SCHEDULED_FRAMEWORK_BUILDER_ARGS)
linux_prod_builder(name='Linux hotfix|frwk',
                   properties={'shard': 'framework_tests'},
                   **COMMON_HOTFIX_FRAMEWORK_BUILDER_ARGS)
linux_prod_builder(name='Linux stable|frwk',
                   properties={'shard': 'framework_tests'},
                   **COMMON_STABLE_FRAMEWORK_BUILDER_ARGS)
linux_prod_builder(name='Linux beta|frwk',
                   properties={'shard': 'framework_tests'},
                   **COMMON_BETA_FRAMEWORK_BUILDER_ARGS)

linux_prod_builder(name='Recipes|rcps', **COMMON_LINUX_RECIPES_BUILDER_ARGS)

linux_try_builder(name='Cocoon|cocoon', **COMMON_LINUX_COCOON_BUILDER_ARGS)
linux_try_builder(name='Linux|frwk',
                  properties={'shard': 'framework_tests'},
                  **COMMON_FRAMEWORK_BUILDER_ARGS)

mac_prod_builder(name='Mac|frwk',
                 **COMMON_SCHEDULED_MAC_FRAMEWORK_BUILDER_ARGS)
mac_prod_builder(name='Mac hotfix|frwk',
                 **COMMON_HOTFIX_MAC_FRAMEWORK_BUILDER_ARGS)
mac_prod_builder(name='Mac stable|frwk',
                 **COMMON_STABLE_MAC_FRAMEWORK_BUILDER_ARGS)
mac_prod_builder(name='Mac beta|frwk',
                 **COMMON_BETA_MAC_FRAMEWORK_BUILDER_ARGS)

mac_try_builder(name='Mac|frwk', **COMMON_MAC_FRAMEWORK_BUILDER_ARGS)

windows_prod_builder(name='Windows|frwk',
                     properties={'shard': 'framework_tests'},
                     **COMMON_SCHEDULED_FRAMEWORK_BUILDER_ARGS)
windows_prod_builder(name='Windows hotfix|frwk',
                     properties={'shard': 'framework_tests'},
                     **COMMON_HOTFIX_FRAMEWORK_BUILDER_ARGS)
windows_prod_builder(name='Windows stable|frwk',
                     properties={'shard': 'framework_tests'},
                     **COMMON_STABLE_FRAMEWORK_BUILDER_ARGS)
windows_prod_builder(name='Windows beta|frwk',
                     properties={'shard': 'framework_tests'},
                     **COMMON_BETA_FRAMEWORK_BUILDER_ARGS)

windows_try_builder(name='Windows|frwk',
                    properties={'shard': 'framework_tests'},
                    **COMMON_FRAMEWORK_BUILDER_ARGS)

COMMON_ENGINE_BUILDER_ARGS = {
    'recipe': 'engine',
    'console_view_name': 'engine',
    'list_view_name': 'engine-try',
}

COMMON_SCHEDULED_ENGINE_BUILDER_ARGS = merge_dicts(
    COMMON_ENGINE_BUILDER_ARGS, {
        'triggered_by': ['master-gitiles-trigger-engine'],
        'triggering_policy':
        scheduler.greedy_batching(max_batch_size=1,
                                  max_concurrent_invocations=3)
    })

COMMON_HOTFIX_ENGINE_BUILDER_ARGS = merge_dicts(
    COMMON_ENGINE_BUILDER_ARGS, {
        'console_view_name':
        'hotfix-engine',
        'recipe':
        'engine_' + STABLE_VERSION,
        'triggered_by': ['hotfix-gitiles-trigger-engine'],
        'triggering_policy':
        scheduler.greedy_batching(max_batch_size=1,
                                  max_concurrent_invocations=3)
    })

COMMON_STABLE_ENGINE_BUILDER_ARGS = merge_dicts(
    COMMON_ENGINE_BUILDER_ARGS, {
        'console_view_name':
        'stable-engine',
        'recipe':
        'engine_' + STABLE_VERSION,
        'triggered_by': ['stable-gitiles-trigger-engine'],
        'triggering_policy':
        scheduler.greedy_batching(max_batch_size=1,
                                  max_concurrent_invocations=3)
    })

COMMON_BETA_ENGINE_BUILDER_ARGS = merge_dicts(
    COMMON_ENGINE_BUILDER_ARGS, {
        'console_view_name':
        'beta-engine',
        'recipe':
        'engine_' + BETA_VERSION,
        'triggered_by': ['beta-gitiles-trigger-engine'],
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


linux_prod_builder(name='Linux Host Engine|host',
                   properties=engine_properties(build_host=True),
                   **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux Fuchsia|fsc',
                   properties=engine_properties(build_fuchsia=True),
                   **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux Android Debug Engine|dbg',
                   properties=engine_properties(
                       build_android_debug=True,
                       build_android_vulkan=True,
                       build_android_jit_release=True),
                   **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux Android AOT Engine|aot',
                   properties=engine_properties(build_android_aot=True),
                   **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux Engine Drone|drn',
                   recipe='engine_builder',
                   console_view_name=None,
                   no_notify=True)

linux_prod_builder(name='Linux hotfix Host Engine|host',
                   properties=engine_properties(build_host=True),
                   **COMMON_HOTFIX_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux hotfix Fuchsia|fsc',
                   properties=engine_properties(build_fuchsia=True),
                   **COMMON_HOTFIX_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux hotfix Android Debug Engine|dbg',
                   properties=engine_properties(
                       build_android_debug=True,
                       build_android_vulkan=True,
                       build_android_jit_release=True),
                   **COMMON_HOTFIX_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux hotfix Android AOT Engine|aot',
                   properties=engine_properties(build_android_aot=True),
                   **COMMON_HOTFIX_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux hotfix Engine Drone|drn',
                   recipe='engine_builder',
                   console_view_name=None,
                   no_notify=True)

linux_prod_builder(name='Linux stable Host Engine|host',
                   properties=engine_properties(build_host=True),
                   **COMMON_STABLE_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux stable Fuchsia|fsc',
                   properties=engine_properties(build_fuchsia=True),
                   **COMMON_STABLE_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux stable Android Debug Engine|dbg',
                   properties=engine_properties(
                       build_android_debug=True,
                       build_android_vulkan=True,
                       build_android_jit_release=True),
                   **COMMON_STABLE_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux stable Android AOT Engine|aot',
                   properties=engine_properties(build_android_aot=True),
                   **COMMON_STABLE_ENGINE_BUILDER_ARGS)
# TODO(fujino): uncomment once 1.17.0 lands in stable
#linux_prod_builder(
#    name='Linux stable Engine Drone|drn',
#    recipe='flutter/engine_builder_' + STABLE_VERSION,
#    console_view_name=None,
#    no_notify=True)

linux_prod_builder(name='Linux beta Host Engine|host',
                   properties=engine_properties(build_host=True),
                   **COMMON_BETA_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux beta Fuchsia|fsc',
                   properties=engine_properties(build_fuchsia=True),
                   **COMMON_BETA_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux beta Android Debug Engine|dbg',
                   properties=engine_properties(
                       build_android_debug=True,
                       build_android_vulkan=True,
                       build_android_jit_release=True),
                   **COMMON_BETA_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux beta Android AOT Engine|aot',
                   properties=engine_properties(build_android_aot=True),
                   **COMMON_BETA_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux beta Engine Drone|drn',
                   recipe='engine_builder_' + BETA_VERSION,
                   console_view_name=None,
                   no_notify=True)

linux_try_builder(name='Linux Host Engine|host',
                  properties=engine_properties(build_host=True),
                  **COMMON_ENGINE_BUILDER_ARGS)
linux_try_builder(name='Linux Fuchsia|fsc',
                  properties=engine_properties(build_fuchsia=True),
                  **COMMON_ENGINE_BUILDER_ARGS)
linux_try_builder(name='Linux Android Debug Engine|dbg',
                  properties=engine_properties(build_android_debug=True,
                                               build_android_vulkan=True),
                  **COMMON_ENGINE_BUILDER_ARGS)
linux_try_builder(name='Linux Android AOT Engine|aot',
                  properties=engine_properties(build_android_aot=True),
                  **COMMON_ENGINE_BUILDER_ARGS)
linux_try_builder(name='Linux Engine Drone|drn',
                  recipe='engine_builder',
                  list_view_name='engine-try')

mac_prod_builder(name='Mac Host Engine|host',
                 properties=engine_properties(build_host=True),
                 **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac Android Debug Engine|dbg',
                 properties=engine_properties(build_android_debug=True,
                                              build_android_vulkan=True),
                 **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac Android AOT Engine|aot',
                 properties=engine_properties(build_android_aot=True),
                 **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac iOS Engine|ios',
                 properties=engine_properties(build_ios=True,
                                              ios_debug=True,
                                              needs_jazzy=True),
                 **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac iOS Engine Profile|ios',
                 properties=engine_properties(build_ios=True,
                                              ios_profile=True,
                                              needs_jazzy=True),
                 **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac iOS Engine Release|ios',
                 properties=engine_properties(build_ios=True,
                                              ios_release=True,
                                              needs_jazzy=True),
                 **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac Engine Drone|drn',
                 recipe='engine_builder',
                 console_view_name=None,
                 no_notify=True)

# Mac Engine Stable Builders
mac_prod_builder(name='Mac stable Host Engine|host',
                 properties=engine_properties(build_host=True),
                 **COMMON_STABLE_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac stable Android Debug Engine|dbg',
                 properties=engine_properties(build_android_debug=True,
                                              build_android_vulkan=True),
                 **COMMON_STABLE_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac stable Android AOT Engine|aot',
                 properties=engine_properties(build_android_aot=True),
                 **COMMON_STABLE_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac stable iOS Engine|ios',
                 properties=engine_properties(build_ios=True,
                                              ios_debug=True,
                                              needs_jazzy=True),
                 **COMMON_STABLE_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac stable iOS Engine Profile|ios',
                 properties=engine_properties(build_ios=True,
                                              ios_profile=True,
                                              needs_jazzy=True),
                 **COMMON_STABLE_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac stable iOS Engine Release|ios',
                 properties=engine_properties(build_ios=True,
                                              ios_release=True,
                                              needs_jazzy=True),
                 **COMMON_STABLE_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac stable Engine Drone|drn',
                 recipe='engine_builder',
                 console_view_name=None,
                 no_notify=True)

# Mac Engine Beta Builders
mac_prod_builder(name='Mac beta Host Engine|host',
                 properties=engine_properties(build_host=True),
                 **COMMON_BETA_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac beta Android Debug Engine|dbg',
                 properties=engine_properties(build_android_debug=True,
                                              build_android_vulkan=True),
                 **COMMON_BETA_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac beta Android AOT Engine|aot',
                 properties=engine_properties(build_android_aot=True),
                 **COMMON_BETA_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac beta iOS Engine|ios',
                 properties=engine_properties(build_ios=True,
                                              ios_debug=True,
                                              needs_jazzy=True),
                 **COMMON_BETA_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac beta iOS Engine Profile|ios',
                 properties=engine_properties(build_ios=True,
                                              ios_profile=True,
                                              needs_jazzy=True),
                 **COMMON_BETA_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac beta iOS Engine Release|ios',
                 properties=engine_properties(build_ios=True,
                                              ios_release=True,
                                              needs_jazzy=True),
                 **COMMON_BETA_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac beta Engine Drone|drn',
                 recipe='engine_builder',
                 console_view_name=None,
                 no_notify=True)

mac_prod_builder(name='Mac hotfix Host Engine|host',
                 properties=engine_properties(build_host=True),
                 **COMMON_HOTFIX_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac hotfix Android Debug Engine|dbg',
                 properties=engine_properties(build_android_debug=True,
                                              build_android_vulkan=True),
                 **COMMON_HOTFIX_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac hotfix Android AOT Engine|aot',
                 properties=engine_properties(build_android_aot=True),
                 **COMMON_HOTFIX_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac hotfix iOS Engine|ios',
                 properties=engine_properties(build_ios=True,
                                              ios_debug=True,
                                              needs_jazzy=True),
                 **COMMON_HOTFIX_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac hotfix iOS Engine Profile|ios',
                 properties=engine_properties(build_ios=True,
                                              ios_profile=True,
                                              needs_jazzy=True),
                 **COMMON_HOTFIX_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac hotfix iOS Engine Release|ios',
                 properties=engine_properties(build_ios=True,
                                              ios_release=True,
                                              needs_jazzy=True),
                 **COMMON_HOTFIX_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac hotfix Engine Drone|drn',
                 recipe='engine_builder',
                 console_view_name=None,
                 no_notify=True)

mac_try_builder(name='Mac Host Engine|host',
                properties=engine_properties(build_host=True),
                **COMMON_ENGINE_BUILDER_ARGS)
mac_try_builder(name='Mac Android Debug Engine|dbg',
                properties=engine_properties(build_android_debug=True,
                                             build_android_vulkan=True),
                **COMMON_ENGINE_BUILDER_ARGS)
mac_try_builder(name='Mac Android AOT Engine|aot',
                properties=engine_properties(build_android_aot=True),
                **COMMON_ENGINE_BUILDER_ARGS)
mac_try_builder(name='Mac iOS Engine|ios',
                properties=engine_properties(build_ios=True,
                                             ios_debug=True,
                                             needs_jazzy=True,
                                             no_bitcode=True),
                **COMMON_ENGINE_BUILDER_ARGS)
mac_try_builder(name='Mac Engine Drone|drn',
                recipe='engine_builder',
                list_view_name='engine-try')

windows_prod_builder(name='Windows Host Engine|host',
                     properties=engine_properties(build_host=True),
                     **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
windows_prod_builder(name='Windows Android AOT Engine|aot',
                     properties=engine_properties(build_android_aot=True),
                     **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
windows_prod_builder(name='Windows Engine Drone|drn',
                     recipe='engine_builder',
                     console_view_name=None,
                     no_notify=True)

windows_prod_builder(name='Windows stable Host Engine|host',
                     properties=engine_properties(build_host=True),
                     **COMMON_STABLE_ENGINE_BUILDER_ARGS)
windows_prod_builder(name='Windows stable Android AOT Engine|aot',
                     properties=engine_properties(build_android_aot=True),
                     **COMMON_STABLE_ENGINE_BUILDER_ARGS)
windows_prod_builder(name='Windows stable Engine Drone|drn',
                     recipe='engine_builder',
                     console_view_name=None,
                     no_notify=True)

windows_prod_builder(name='Windows beta Host Engine|host',
                     properties=engine_properties(build_host=True),
                     **COMMON_BETA_ENGINE_BUILDER_ARGS)
windows_prod_builder(name='Windows beta Android AOT Engine|aot',
                     properties=engine_properties(build_android_aot=True),
                     **COMMON_BETA_ENGINE_BUILDER_ARGS)
windows_prod_builder(name='Windows beta Engine Drone|drn',
                     recipe='engine_builder',
                     console_view_name=None,
                     no_notify=True)

windows_prod_builder(name='Windows hotfix Host Engine|host',
                     properties=engine_properties(build_host=True),
                     **COMMON_HOTFIX_ENGINE_BUILDER_ARGS)
windows_prod_builder(name='Windows hotfix Android AOT Engine|aot',
                     properties=engine_properties(build_android_aot=True),
                     **COMMON_HOTFIX_ENGINE_BUILDER_ARGS)
windows_prod_builder(name='Windows hotfix Engine Drone|drn',
                     recipe='engine_builder',
                     console_view_name=None,
                     no_notify=True)

windows_try_builder(name='Windows Host Engine|host',
                    properties=engine_properties(build_host=True),
                    **COMMON_ENGINE_BUILDER_ARGS)
windows_try_builder(name='Windows Android AOT Engine|aot',
                    properties=engine_properties(build_android_aot=True),
                    **COMMON_ENGINE_BUILDER_ARGS)
windows_try_builder(name='Windows Engine Drone|drn',
                    recipe='engine_builder',
                    list_view_name='engine-try')

COMMON_WEB_ENGINE_BUILDER_ARGS = {
    'recipe': 'web_engine',
    'console_view_name': 'web-engine',
    'list_view_name': 'web-engine-try',
}

linux_try_builder(name='Linux Web Engine|lwe',
                  **COMMON_WEB_ENGINE_BUILDER_ARGS)
mac_try_builder(name='Mac Web Engine|mwe', **COMMON_WEB_ENGINE_BUILDER_ARGS)
windows_try_builder(name='Windows Web Engine|wwe',
                    **COMMON_WEB_ENGINE_BUILDER_ARGS)

DEV_PACKAGING_BUILDER_ARGS = {
    'recipe': 'flutter',
    'console_view_name': 'packaging',
    'triggered_by': ['gitiles-trigger-dev-packaging'],
}

BETA_PACKAGING_BUILDER_ARGS = {
    'recipe': 'flutter_' + BETA_VERSION,
    'console_view_name': 'packaging',
    'triggered_by': ['gitiles-trigger-beta-packaging'],
}

STABLE_PACKAGING_BUILDER_ARGS = {
    'recipe': 'flutter_' + STABLE_VERSION,
    'console_view_name': 'packaging',
    'triggered_by': ['gitiles-trigger-stable-packaging'],
}

linux_prod_builder(name='Linux Flutter Dev Packaging|dev',
                   **DEV_PACKAGING_BUILDER_ARGS)
mac_prod_builder(name='Mac Flutter Dev Packaging|dev',
                 **DEV_PACKAGING_BUILDER_ARGS)
windows_prod_builder(name='Windows Flutter Dev Packaging|dev',
                     **DEV_PACKAGING_BUILDER_ARGS)

linux_prod_builder(name='Linux Flutter Beta Packaging|beta',
                   **BETA_PACKAGING_BUILDER_ARGS)
mac_prod_builder(name='Mac Flutter Beta Packaging|beta',
                 **BETA_PACKAGING_BUILDER_ARGS)
windows_prod_builder(name='Windows Flutter Beta Packaging|beta',
                     **BETA_PACKAGING_BUILDER_ARGS)

linux_prod_builder(name='Linux Flutter Stable Packaging|stbl',
                   **STABLE_PACKAGING_BUILDER_ARGS)
mac_prod_builder(name='Mac Flutter Stable Packaging|stbl',
                 **STABLE_PACKAGING_BUILDER_ARGS)
windows_prod_builder(name='Windows Flutter Stable Packaging|stbl',
                     **STABLE_PACKAGING_BUILDER_ARGS)


def ios_tools_builder(**kwargs):
    builder = kwargs['name'].split('|')[0]
    repo = 'https://flutter-mirrors.googlesource.com/' + builder
    console_view(builder, repo)
    luci.gitiles_poller(name='gitiles-trigger-' + builder,
                        bucket='prod',
                        repo=repo,
                        triggers=[builder])
    return mac_prod_builder(recipe='ios-usb-dependencies',
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
