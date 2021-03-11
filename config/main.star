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
load("//lib/repos.star", "repos")
load("//lib/release_branches/release_branches.star", "release_branches")
load("//cocoon_config.star", "cocoon_config")
load("//devicelab_config.star", "devicelab_config")
load("//devicelab_staging_config.star", "devicelab_staging_config")
load("//firebaselab_config.star", "firebaselab_config")
load("//recipes_config.star", "recipes_config")
load("//engine_config.star", "engine_config")
load("//framework_config.star", "framework_config")
load("//iostools_config.star", "iostools_config")
load("//packages_config.star", "packages_config")
load("//packaging_config.star", "packaging_config")
load("//plugins_config.star", "plugins_config")

# Avoid jumping back and forth with configs being updated by lower version
# lucicfg.
lucicfg.check_version("1.17.0")

FUCHSIA_CTL_VERSION = "version:0.0.27"

lucicfg.config(
    config_dir = "generated/flutter",
    tracked_files = ["**/*"],
    fail_on_warnings = True,
    lint_checks = ["default"],
)

luci.project(
    name = "flutter",
    config_dir = "luci",
    buildbucket = "cr-buildbucket.appspot.com",
    logdog = "luci-logdog.appspot.com",
    milo = "luci-milo.appspot.com",
    scheduler = "luci-scheduler.appspot.com",
    swarming = "chromium-swarm.appspot.com",
    notify = "luci-notify.appspot.com",
    acls = [
        acl.entry(
            roles = [
                acl.BUILDBUCKET_READER,
                acl.LOGDOG_READER,
                acl.PROJECT_CONFIGS_READER,
                acl.SCHEDULER_READER,
            ],
            groups = "all",
        ),
        acl.entry(
            roles = [
                acl.BUILDBUCKET_TRIGGERER,
                acl.SCHEDULER_TRIGGERER,
            ],
            groups = "project-flutter-prod-schedulers",
        ),
        acl.entry(
            roles = [
                acl.BUILDBUCKET_OWNER,
                acl.SCHEDULER_OWNER,
            ],
            groups = "project-flutter-admins",
        ),
        acl.entry(
            acl.LOGDOG_WRITER,
            groups = "luci-logdog-chromium-writers",
        ),
        acl.entry(
            roles = [acl.CQ_COMMITTER, acl.CQ_DRY_RUNNER],
            groups = ["project-flutter-try-schedulers"],
        ),
    ],
)

luci.logdog(gs_bucket = "chromium-luci-logdog")

luci.milo(
    logo =
        "https://storage.googleapis.com/chrome-infra-public/logo/flutter-logo.svg",
    favicon = "https://storage.googleapis.com/flutter_infra/favicon.ico",
)

luci.bucket(
    name = "prod",
    acls = [
        acl.entry(
            acl.BUILDBUCKET_TRIGGERER,
            groups = "project-flutter-prod-schedulers",
        ),
        acl.entry(
            acl.SCHEDULER_TRIGGERER,
            groups = "project-flutter-prod-schedulers",
        ),
    ],
)

luci.bucket(
    name = "try",
    acls = [
        acl.entry(
            acl.BUILDBUCKET_TRIGGERER,
            groups = "project-flutter-try-schedulers",
        ),
    ],
)

# CQ group configurations. Only FLUTTER_RECIPES is using
# LUCI CQ but we still need the CQ configurations for all
# the try configurations for led recipe tests.
common.cq_group(repos.COCOON)
common.cq_group(repos.ENGINE)
common.cq_group(repos.FLUTTER)
common.cq_group(repos.FLUTTER_RECIPES)
common.cq_group(repos.PACKAGES)
common.cq_group(repos.PLUGINS)

luci.builder.defaults.properties.set({
    "$kitchen": {
        "emulate_gce": True,
    },
    "$fuchsia/goma": {
        "server": "rbe-prod1.endpoints.fuchsia-infra-goma-prod.cloud.goog",
    },
    "$recipe_engine/isolated": {
        "server": "https://isolateserver.appspot.com",
    },
    "$recipe_engine/swarming": {
        "server": "https://chromium-swarm.appspot.com",
    },
    "mastername": "client.flutter",
    "goma_jobs": "200",
    "upload_packages": False,
    "clobber": False,
})

############################ End Global Defaults ############################
cocoon_config.setup()

devicelab_config.setup(release_branches)

devicelab_staging_config.setup()

firebaselab_config.setup(release_branches)

engine_config.setup(release_branches, FUCHSIA_CTL_VERSION)

framework_config.setup(release_branches)

iostools_config.setup()

packages_config.setup()

packaging_config.setup(release_branches)

recipes_config.setup()

plugins_config.setup(release_branches)
######################### Console Definitions #################################
