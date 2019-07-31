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
recipe('flutter/ios-usb-dependencies')

# Console definitions
def console_view(name, repo, refs = ['refs/heads/master'], exclude_ref = None):
  luci.console_view(
    name = name,
    repo = repo,
    refs = refs,
    exclude_ref = exclude_ref,
    include_experimental_builds = True,
  )

console_view('framework', FLUTTER_GIT)
console_view('engine', ENGINE_GIT)
console_view('packaging', FLUTTER_GIT, refs=['refs/heads/beta', 'refs/heads/dev', 'refs/heads/stable'], exclude_ref='refs/heads/master')

# Builder-defining functions

DEFAULT_PROPERTIES = {
  'mastername': 'client.flutter',
  'gradle_dist_url': 'https://services.gradle.org/distributions/gradle-4.10.2-all.zip',
  'goma_jobs': '200',
}

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

def prod_builder(name, console_view_name, category, short_name, recipe, os, properties={}, cores=None, **kwargs):
  properties = merge_dicts(DEFAULT_PROPERTIES, properties)
  dimensions = {
    'pool': 'luci.flutter.prod',
    'cpu': 'x86-64',
    'os': os,
  }
  if cores != None:
    dimensions['cores'] = cores

  luci.builder(
    name = name,
    bucket = 'prod',
    executable = recipe,
    properties = properties,
    service_account = 'flutter-prod-builder@chops-service-accounts.iam.gserviceaccount.com',
    execution_timeout = 3 * time.hour,
    dimensions = dimensions,
    build_numbers = True,
    notifies = [
      luci.notifier(
        name = 'blamelist-on-new-failure',
        on_new_failure = True,
        notify_blamelist = True,
      ),
    ],
    **kwargs
  )
  luci.console_view_entry(
    builder = 'prod/' + name,
    console_view = console_view_name,
    category = category,
    short_name = short_name,
  )

def short_name_builder(name, **kwargs):
  parts = name.split('|')
  return prod_builder(
    name = parts[0],
    short_name = parts[1],
    **kwargs
  )

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
  return short_name_builder(
    os = 'Mac-10.14',
    properties = properties,
    caches = mac_caches,
    category = category,
    **kwargs
  )

def linux_builder(properties = {}, caches=None, cores='8', category='Linux', **kwargs):
  linux_caches = [swarming.cache(name = 'flutter_openjdk_install', path = 'java')]
  if caches != None:
    linux_caches.extend(caches)
  return short_name_builder(
    os = 'Ubuntu-16.04',
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
  return short_name_builder(
    os = 'Windows-10',
    cores = cores,
    properties = properties,
    caches = windows_caches,
    category = category,
    **kwargs
  )

COMMON_FRAMEWORK_BUILDER_ARGS = {
  'recipe': 'flutter/flutter',
  'console_view_name': 'framework',
  'triggered_by': ['master-gitiles-trigger-framework'],
  'triggering_policy': scheduler.greedy_batching(max_concurrent_invocations=6)
}

linux_builder(name='Linux|frwk', properties={'shard': 'tests'}, **COMMON_FRAMEWORK_BUILDER_ARGS)
linux_builder(name='Linux Coverage|lcov', properties={'shard': 'coverage', 'coveralls_lcov_version': '5.1.0',}, **COMMON_FRAMEWORK_BUILDER_ARGS)
mac_builder(name='Mac|frwk', properties={'shard': 'tests', 'cocoapods_version': '1.6.0'}, caches=[swarming.cache(name='flutter_cocoapods', path='cocoapods')], **COMMON_FRAMEWORK_BUILDER_ARGS)
windows_builder(name='Windows|frwk', properties={'shard': 'tests'}, **COMMON_FRAMEWORK_BUILDER_ARGS)

COMMON_ENGINE_BUILDER_ARGS = {
  'recipe': 'flutter/engine',
  'console_view_name': 'engine',
  'triggered_by': ['master-gitiles-trigger-engine'],
  'triggering_policy': scheduler.greedy_batching(max_batch_size=1, max_concurrent_invocations=3)
}

def engine_properties(build_host=False, build_android_debug=False, build_android_aot=False, build_android_vulkan=False, build_ios=False, needs_jazzy=False):
  properties = {
    'build_host': build_host,
    'build_android_debug': build_android_debug,
    'build_android_aot': build_android_aot,
    'build_android_vulkan': build_android_vulkan,
    'build_ios': build_ios,
  }
  if (needs_jazzy):
    properties['jazzy_version'] = '0.9.5'
  return properties

linux_builder(name='Linux Host Engine|host', properties=engine_properties(build_host=True), **COMMON_ENGINE_BUILDER_ARGS)
linux_builder(name='Linux Android Debug Engine|dbg', properties=engine_properties(build_android_debug=True, build_android_vulkan=True), **COMMON_ENGINE_BUILDER_ARGS)
linux_builder(name='Linux Android AOT Engine|aot', properties=engine_properties(build_android_aot=True), **COMMON_ENGINE_BUILDER_ARGS)

mac_builder(name='Mac Host Engine|host', properties=engine_properties(build_host=True, needs_jazzy=True), **COMMON_ENGINE_BUILDER_ARGS)
mac_builder(name='Mac Android Debug Engine|dbg', properties=engine_properties(build_android_debug=True, build_android_vulkan=True, needs_jazzy=True), **COMMON_ENGINE_BUILDER_ARGS)
mac_builder(name='Mac Android AOT Engine|aot', properties=engine_properties(build_android_aot=True, needs_jazzy=True), **COMMON_ENGINE_BUILDER_ARGS)
mac_builder(name='Mac iOS Engine|ios', properties=engine_properties(build_ios=True, needs_jazzy=True), **COMMON_ENGINE_BUILDER_ARGS)

windows_builder(name='Windows Host Engine|host', properties=engine_properties(build_host=True), **COMMON_ENGINE_BUILDER_ARGS)
windows_builder(name='Windows Android AOT Engine|aot', properties=engine_properties(build_android_aot=True), **COMMON_ENGINE_BUILDER_ARGS)

COMMON_PACKAGING_BUILDER_ARGS = {
  'recipe': 'flutter/flutter',
  'console_view_name': 'packaging',
  'triggered_by': ['gitiles-trigger-packaging'],
}

linux_builder(name='Linux Flutter Packaging|pkg', **COMMON_PACKAGING_BUILDER_ARGS)
mac_builder(name='Mac Flutter Packaging|pkg', **COMMON_PACKAGING_BUILDER_ARGS)
windows_builder(name='Windows Flutter Packaging|pkg', **COMMON_PACKAGING_BUILDER_ARGS)

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
  return mac_builder(
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
