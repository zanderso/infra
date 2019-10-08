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

FLUTTER_GIT = 'https://chromium.googlesource.com/external/github.com/flutter/flutter'
ENGINE_GIT = 'https://chromium.googlesource.com/external/github.com/flutter/engine'

lucicfg.config(
  config_dir = '.',
  tracked_files = [
    'cr-buildbucket.cfg',
    'luci-logdog.cfg',
    'luci-milo.cfg',
    'luci-notify.cfg',
    'luci-scheduler.cfg',
    'project.cfg',
  ],
)

luci.project(
  name = 'flutter',

  buildbucket = 'cr-buildbucket.appspot.com',
  logdog = 'luci-logdog.appspot.com',
  milo = 'luci-milo.appspot.com',
  scheduler = 'luci-scheduler.appspot.com',
  swarming = 'chromium-swarm.appspot.com',
  notify = 'luci-notify.appspot.com',

  acls = [
    acl.entry(
      roles = [
        acl.BUILDBUCKET_READER,
        acl.LOGDOG_READER,
        acl.PROJECT_CONFIGS_READER,
        acl.SCHEDULER_READER,
      ],
      groups = 'all',
    ),
    acl.entry(acl.BUILDBUCKET_TRIGGERER, groups = 'project-flutter-prod-schedulers'),
    acl.entry(acl.BUILDBUCKET_TRIGGERER, users = 'luci-scheduler@appspot.gserviceaccount.com'),
    acl.entry(
      roles = [
        acl.BUILDBUCKET_OWNER,
        acl.SCHEDULER_OWNER,
      ],
      groups = 'project-flutter-admins'
    ),
    acl.entry(acl.LOGDOG_WRITER, groups = 'luci-logdog-chromium-writers'),
  ],
)

luci.logdog(
  gs_bucket = 'chromium-luci-logdog',
)

luci.milo(
  logo = 'https://storage.googleapis.com/chrome-infra-public/logo/flutter-logo.svg',
  favicon = 'https://storage.googleapis.com/flutter_infra/favicon.ico',
)

luci.bucket(name = 'prod')
luci.bucket(
  name = 'try',
  acls = [acl.entry(acl.BUILDBUCKET_TRIGGERER, groups = 'project-flutter-try-schedulers')]
)

# Global builder defaults
luci.builder.defaults.properties.set({
  '$kitchen': {'emulate_gce': True},
  '$build/goma': {'use_luci_auth': True},
  '$recipe_engine/isolated': {"server": "https://isolateserver.appspot.com" },
  '$recipe_engine/swarming': {"server": "https://chromium-swarm.appspot.com" },
  'mastername': 'client.flutter',
  'goma_jobs': '200',
  'android_sdk_license': '\n24333f8a63b6825ea9c5514f83c2829b004d1fee',
  'android_sdk_preview_license': '\n84831b9409646a918e30573bab4c9c91346d8abd',
})

# Gitiles pollers

luci.gitiles_poller(
  name = 'master-gitiles-trigger-framework',
  bucket = 'prod',
  repo = FLUTTER_GIT,
)

luci.gitiles_poller(
  name = 'master-gitiles-trigger-engine',
  bucket = 'prod',
  repo = ENGINE_GIT,
)

luci.gitiles_poller(
  name = 'gitiles-trigger-packaging',
  bucket = 'prod',
  repo = FLUTTER_GIT,
  refs = ['refs/heads/dev', 'refs/heads/beta', 'refs/heads/stable'],
)


# Recipe definitions
def recipe(name):
  luci.recipe(
    name = name,
    cipd_package = 'infra/recipe_bundles/chromium.googlesource.com/chromium/tools/build',
    cipd_version = 'refs/heads/master',
  )

recipe('flutter/flutter')
recipe('flutter/engine')
recipe('flutter/engine_builder')
recipe('flutter/ios-usb-dependencies')

# Console definitions
def console_view(name, repo, refs = ['refs/heads/master'], exclude_ref = None):
  luci.console_view(
    name = name,
    repo = repo,
    refs = refs,
    exclude_ref = exclude_ref,
  )

console_view('framework', FLUTTER_GIT)
console_view('engine', ENGINE_GIT)
console_view('packaging', FLUTTER_GIT, refs=['refs/heads/beta', 'refs/heads/dev', 'refs/heads/stable'], exclude_ref='refs/heads/master')

luci.list_view(
  name='framework-try',
  title='Framework try builders',
)
luci.list_view(
  name='engine-try',
  title='Engine try builders',
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
def builder(bucket, pool, name, recipe, os, properties={}, cores=None, **kwargs):
  dimensions = {
    'pool': pool,
    'cpu': 'x64',
    'os': os,
  }
  if cores != None:
    dimensions['cores'] = cores
  name_parts = name.split('|')
  luci.builder(
    name = name_parts[0],
    bucket = bucket,
    executable = recipe,
    properties = properties,
    service_account = 'flutter-' + bucket + '-builder@chops-service-accounts.iam.gserviceaccount.com',
    execution_timeout = 3 * time.hour,
    dimensions = dimensions,
    build_numbers = True,
    **kwargs
  )


def try_builder(name, list_view_name, console_view_name=None, category=None, properties={}, **kwargs):
  bucket = 'try'
  pool = 'luci.flutter.try'
  merged_properties = merge_dicts(properties, {'upload_packages': False})
  name_parts = name.split('|')

  luci.list_view_entry(
    builder = bucket + '/' + name_parts[0],
    list_view = list_view_name,
  )

  return builder(bucket, pool, name, properties=merged_properties, **kwargs)

def prod_builder(name, console_view_name, category, no_notify=False, list_view_name=None, properties={}, **kwargs):
  merged_properties = merge_dicts(properties, {'upload_packages': True})
  bucket = 'prod'
  pool = 'luci.flutter.prod'
  name_parts = name.split('|')

  if console_view_name:
    luci.console_view_entry(
      builder = bucket + '/' + name_parts[0],
      console_view = console_view_name,
      category = category,
      short_name = name_parts[1],
    )

  notifies = None if no_notify else [
      luci.notifier(
        name = 'blamelist-on-new-failure',
        on_new_failure = True,
        notify_blamelist = True,
      ),
    ]

  return builder(
    bucket,
    pool,
    name,
    properties=merged_properties,
    notifies = notifies,
    **kwargs)


def common_builder(**common_kwargs):
  def prod_job(*args, **kwargs):
    return prod_builder(*args, **merge_dicts(common_kwargs, kwargs))
  def try_job(*args, **kwargs):
    return try_builder(*args, **merge_dicts(common_kwargs, kwargs))
  return try_job, prod_job

def mac_builder(properties = {}, caches=None, category = 'Mac', **kwargs):
  # see https://chrome-infra-packages.appspot.com/p/infra_internal/ios/xcode/mac/+/
  properties = merge_dicts(
    {
      '$depot_tools/osx_sdk': {
        'sdk_version': '10e125', # 10.2
      },
    },
    properties
  )
  mac_caches = [swarming.cache('osx_sdk')]
  if caches != None:
    mac_caches.extend(caches)
  return common_builder(
    os = 'Mac-10.14',
    properties = properties,
    caches = mac_caches,
    category = category,
    **kwargs
  )


def linux_builder(properties = {}, caches=None, cores='8', category='Linux', os=None, **kwargs):
  linux_caches = [swarming.cache(name = 'flutter_openjdk_install', path = 'java')]
  if caches != None:
    linux_caches.extend(caches)
  return common_builder(
    os = os or 'Linux',
    cores = cores,
    properties = properties,
    caches = linux_caches,
    category = category,
    **kwargs
  )

def windows_builder(properties = {}, caches=None, cores='8', category = 'Windows', **kwargs):
  windows_caches = [swarming.cache(name = 'flutter_openjdk_install', path = 'java')]
  if caches != None:
    windows_caches.extend(caches)
  return common_builder(
    os = 'Windows-10',
    cores = cores,
    properties = properties,
    caches = windows_caches,
    category = category,
    **kwargs
  )

linux_try_builder, linux_prod_builder = linux_builder()
mac_try_builder, mac_prod_builder = mac_builder()
windows_try_builder, windows_prod_builder = windows_builder()

COMMON_FRAMEWORK_BUILDER_ARGS = {
  'recipe': 'flutter/flutter',
  'console_view_name': 'framework',
  'list_view_name': 'framework-try',
}

COMMON_SCHEDULED_FRAMEWORK_BUILDER_ARGS = merge_dicts(COMMON_FRAMEWORK_BUILDER_ARGS, {
  'triggered_by': ['master-gitiles-trigger-framework'],
  'triggering_policy': scheduler.greedy_batching(max_concurrent_invocations=6),
})

FRAMEWORK_MAC_EXTRAS = {
  'properties': {'shard': 'tests', 'cocoapods_version': '1.6.0'},
  'caches': [swarming.cache(name='flutter_cocoapods', path='cocoapods')],
}

COMMON_MAC_FRAMEWORK_BUILDER_ARGS = merge_dicts(COMMON_FRAMEWORK_BUILDER_ARGS, FRAMEWORK_MAC_EXTRAS)

COMMON_SCHEDULED_MAC_FRAMEWORK_BUILDER_ARGS = merge_dicts(COMMON_MAC_FRAMEWORK_BUILDER_ARGS, COMMON_SCHEDULED_FRAMEWORK_BUILDER_ARGS)

linux_prod_builder(name='Linux|frwk', properties={'shard': 'tests'}, **COMMON_SCHEDULED_FRAMEWORK_BUILDER_ARGS)
linux_prod_builder(name='Linux Coverage|lcov', properties={'shard': 'coverage', 'coveralls_lcov_version': '5.1.0',}, **COMMON_SCHEDULED_FRAMEWORK_BUILDER_ARGS)

linux_try_builder(name='Linux|frwk', properties={'shard': 'tests'}, **COMMON_FRAMEWORK_BUILDER_ARGS)

mac_prod_builder(name='Mac|frwk', **COMMON_SCHEDULED_MAC_FRAMEWORK_BUILDER_ARGS)

mac_try_builder(name='Mac|frwk', **COMMON_MAC_FRAMEWORK_BUILDER_ARGS)

windows_prod_builder(name='Windows|frwk', properties={'shard': 'tests'}, **COMMON_SCHEDULED_FRAMEWORK_BUILDER_ARGS)

windows_try_builder(name='Windows|frwk', properties={'shard': 'tests'}, **COMMON_FRAMEWORK_BUILDER_ARGS)

COMMON_ENGINE_BUILDER_ARGS = {
  'recipe': 'flutter/engine',
  'console_view_name': 'engine',
  'list_view_name': 'engine-try',
}

COMMON_SCHEDULED_ENGINE_BUILDER_ARGS = merge_dicts(COMMON_ENGINE_BUILDER_ARGS, {
  'triggered_by': ['master-gitiles-trigger-engine'],
  'triggering_policy': scheduler.greedy_batching(max_batch_size=1, max_concurrent_invocations=3)
})

def engine_properties(build_host=False, build_fuchsia=False, build_android_debug=False, build_android_aot=False, build_android_vulkan=False, build_ios=False, needs_jazzy=False, ios_debug=False, ios_profile=False, ios_release=False, build_android_jit_release=False):
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
  if (needs_jazzy):
    properties['jazzy_version'] = '0.9.5'
  if (build_fuchsia):
    properties['fuchsia_ctl_version'] = 'version:0.0.8'
  return properties

linux_prod_builder(name='Linux Host Engine|host', properties=engine_properties(build_host=True), **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux Fuchsia|fsc', properties=engine_properties(build_fuchsia=True), **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux Android Debug Engine|dbg', properties=engine_properties(build_android_debug=True, build_android_vulkan=True, build_android_jit_release=True), **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux Android AOT Engine|aot', properties=engine_properties(build_android_aot=True), **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
linux_prod_builder(name='Linux Engine Drone|drn', recipe='flutter/engine_builder', console_view_name=None, no_notify=True)

linux_try_builder(name='Linux Host Engine|host', properties=engine_properties(build_host=True), **COMMON_ENGINE_BUILDER_ARGS)
linux_try_builder(name='Linux Fuchsia|fsc', properties=engine_properties(build_fuchsia=True), **COMMON_ENGINE_BUILDER_ARGS)
linux_try_builder(name='Linux Android Debug Engine|dbg', properties=engine_properties(build_android_debug=True, build_android_vulkan=True), **COMMON_ENGINE_BUILDER_ARGS)
linux_try_builder(name='Linux Android AOT Engine|aot', properties=engine_properties(build_android_aot=True), **COMMON_ENGINE_BUILDER_ARGS)
linux_try_builder(name='Linux Engine Drone|drn', recipe='flutter/engine_builder', list_view_name='engine-try')


mac_prod_builder(name='Mac Host Engine|host', properties=engine_properties(build_host=True), **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac Android Debug Engine|dbg', properties=engine_properties(build_android_debug=True, build_android_vulkan=True), **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac Android AOT Engine|aot', properties=engine_properties(build_android_aot=True), **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac iOS Engine|ios', properties=engine_properties(build_ios=True, ios_debug=True, needs_jazzy=True), **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac iOS Engine Profile|ios', properties=engine_properties(build_ios=True, ios_profile=True, needs_jazzy=True), **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac iOS Engine Release|ios', properties=engine_properties(build_ios=True, ios_release=True, needs_jazzy=True), **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
mac_prod_builder(name='Mac Engine Drone|drn', recipe='flutter/engine_builder', console_view_name=None, no_notify=True)

mac_try_builder(name='Mac Host Engine|host', properties=engine_properties(build_host=True), **COMMON_ENGINE_BUILDER_ARGS)
mac_try_builder(name='Mac Android Debug Engine|dbg', properties=engine_properties(build_android_debug=True, build_android_vulkan=True), **COMMON_ENGINE_BUILDER_ARGS)
mac_try_builder(name='Mac Android AOT Engine|aot', properties=engine_properties(build_android_aot=True), **COMMON_ENGINE_BUILDER_ARGS)
mac_try_builder(name='Mac iOS Engine|ios', properties=engine_properties(build_ios=True, ios_debug=True, needs_jazzy=True), **COMMON_ENGINE_BUILDER_ARGS)
mac_try_builder(name='Mac Engine Drone|drn', recipe='flutter/engine_builder', list_view_name='engine-try')

windows_prod_builder(name='Windows Host Engine|host', properties=engine_properties(build_host=True), **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
windows_prod_builder(name='Windows Android AOT Engine|aot', properties=engine_properties(build_android_aot=True), **COMMON_SCHEDULED_ENGINE_BUILDER_ARGS)
windows_prod_builder(name='Windows Engine Drone|drn', recipe='flutter/engine_builder', console_view_name=None, no_notify=True)

windows_try_builder(name='Windows Host Engine|host', properties=engine_properties(build_host=True), **COMMON_ENGINE_BUILDER_ARGS)
windows_try_builder(name='Windows Android AOT Engine|aot', properties=engine_properties(build_android_aot=True), **COMMON_ENGINE_BUILDER_ARGS)
windows_try_builder(name='Windows Engine Drone|drn', recipe='flutter/engine_builder', list_view_name='engine-try')

COMMON_PACKAGING_BUILDER_ARGS = {
  'recipe': 'flutter/flutter',
  'console_view_name': 'packaging',
  'triggered_by': ['gitiles-trigger-packaging'],
}

linux_prod_builder(name='Linux Flutter Packaging|pkg', **COMMON_PACKAGING_BUILDER_ARGS)
mac_prod_builder(name='Mac Flutter Packaging|pkg', **COMMON_PACKAGING_BUILDER_ARGS)
windows_prod_builder(name='Windows Flutter Packaging|pkg', **COMMON_PACKAGING_BUILDER_ARGS)

def ios_tools_builder(**kwargs):
  builder = kwargs['name'].split('|')[0]
  repo = 'https://flutter-mirrors.googlesource.com/' + builder
  console_view(builder, repo)
  luci.gitiles_poller(
    name = 'gitiles-trigger-' + builder,
    bucket = 'prod',
    repo = repo,
    triggers = [builder]
  )
  return mac_prod_builder(
    recipe='flutter/ios-usb-dependencies',
    properties={
      'package_name': builder + '-flutter',
    },
    console_view_name=builder,
    triggering_policy=scheduler.greedy_batching(max_concurrent_invocations=1,max_batch_size=6),
    **kwargs
  )

ios_tools_builder(name='ideviceinstaller|idev')
ios_tools_builder(name='libimobiledevice|libi')
ios_tools_builder(name='libplist|plist')
ios_tools_builder(name='usbmuxd|usbmd')
ios_tools_builder(name='openssl|ssl')
ios_tools_builder(name='ios-deploy|deploy')
