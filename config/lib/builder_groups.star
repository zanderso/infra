# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Settings for groups of related builders."""

load("accounts.star", "accounts")
load("repos.star", "repos")

def _group(
        account,
        bucket,
        pool,
        poller_suffix = None,
        test_swarming_pool = None,
        triggering_policy = None,
        triggering_refs = (),
        triggering_repos = (),
        priority = None,
        views = ()):
    return struct(
        account = account,
        bucket = bucket,
        pool = pool,
        poller_suffix = poller_suffix,
        priority = priority,
        test_swarming_pool = test_swarming_pool,
        triggering_policy = triggering_policy,
        triggering_refs = triggering_refs,
        triggering_repos = triggering_repos,
        views = views,
    )

builder_groups = struct(
    recipes_try = _group(
        account = accounts.FLUTTER_TRY,
        bucket = "try",
        pool = "luci.flutter.try",
        triggering_repos = (repos.FLUTTER_RECIPES,),
        triggering_refs = ("refs/heads/master",),
        views = (),
    ),
    recipes_prod = _group(
        account = accounts.FLUTTER_PROD,
        bucket = "prod",
        pool = "luci.flutter.prod",
        triggering_repos = (repos.FLUTTER_RECIPES,),
        triggering_refs = ("refs/heads/master",),
        views = ("recipes",),
    ),
)
