# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Utility methods to create builders."""

# Regular expressions for files to skip CQ.
LOCATION_REGEXP_MARKDOWN = r".+/[+]/.*\.md"
LOCATION_REGEXP_OWNERS = r".+/[+].*/OWNERS"


def _repo_url_to_luci_object_name(repo_url):
    """Takes a git repository URL and returns a name for a LUCI object.
    Examples:
        https://foo.googlesource.com/bar/baz -> foo-bar-baz
        https://foo.other-domain.com/bar/baz -> foo.other-domain.com-bar-baz
    """
    domain_and_path = repo_url.split("://")[1].split("/")
    domain = domain_and_path[0]
    path = domain_and_path[1:]
    prefix = domain
    if domain.endswith(".googlesource.com"):
        prefix = domain[:-len(".googlesource.com")] + "-"
    return prefix + "-".join(path)


def _cq_group_name(repo_url):
    """Returns the name to be passed to cq_group for a repo."""
    return _repo_url_to_luci_object_name(repo_url)


def _ref_to_luci_object_name(ref):
    """Takes a git ref and returns a name for a LUCI object.
    Strips out non-alphanumeric parts of the ref and replaces
    slashes with dashes.
    Examples:
        refs/heads/master: refs-heads-master
        refs/heads/sandbox/.+: refs-heads-sandbox
    """
    parts = ref.split("/")
    char_parts = []
    for part in parts:
        if part.isalnum():
            char_parts.append(part)
    return "-".join(char_parts)


def _cq_group(repo, tree_status_host=None):
    luci.cq_group(name=_cq_group_name(repo),
                  cancel_stale_tryjobs=True,
                  retry_config=cq.retry_config(single_quota=1,
                                               global_quota=2,
                                               failure_weight=2,
                                               transient_failure_weight=1,
                                               timeout_weight=1),
                  tree_status_host=tree_status_host,
                  watch=cq.refset(repo, refs=["refs/heads/.+"]))


def _poller_name(repo_url, poller_suffix, ref, path_regexps=None):
    """Returns the name to be passed to gitiles_poller for a repo."""
    gitiles_poller_suffix = "-gitiles-trigger"
    if path_regexps:
        for regexp in path_regexps:
            basename = regexp.split("/")[-1]
            gitiles_poller_suffix = ("-" + basename.replace(".", "-") +
                                     gitiles_poller_suffix)
    if poller_suffix:
        gitiles_poller_suffix = "-" + poller_suffix + gitiles_poller_suffix
    if ref and ref != "refs/heads/master":
        gitiles_poller_suffix += "-" + _ref_to_luci_object_name(ref)
    return _repo_url_to_luci_object_name(repo_url) + gitiles_poller_suffix


def _builder(name,
             builder_group,
             executable,
             execution_timeout,
             properties,
             caches=None,
             console_category=None,
             console_short_name=None,
             cq_disable_reuse=False,
             dimensions=None,
             location_regexp=None,
             location_regexp_exclude=None,
             path_regexps=None,
             notifies=None,
             priority=None,
             schedule=None,
             disabled=False,
             service_account=None,
             swarming_tags=None):
    """Creates a builder, notifier, trigger, view entry.
    Args:
        name: Passed through to luci.builder.
        builder_group: struct from groups_lib.
        executable: Passed through to luci.builder.
        execution_timeout: Passed through to luci.builder.
        properties: Passed through to luci.builder, with some defaults applied.
        caches: Passed through to luci.builder.
            Note: a number of global caches are configured by default:
            https://chrome-internal.googlesource.com/infradata/config/+/master/configs/cr-buildbucket/settings.cfg
        console_category: Passed through as category arg to luci.console_view_entry.
            Must be set if console_short_name is set.
        console_short_name: Passed through as short_name arg to luci.console_view_entry.
            Must be set if console_category is set.
        cq_disable_reuse: Passed through to luci.cq_tryjob_verifer. If true,
            this builder will be triggered by every CQ run even if it already
            passed on a previous recent CQ run on the same patchset.
        dimensions: Passed through to luci.builder, with some defaults applied.
        location_regexp: Passed through to luci.cq_tryjob_verifier.
        location_regexp_exclude: Passed through to luci.cq_tryjob_verifier.
        path_regexps: Passed through to luci.gitiles_poller.
        notifies: Passed through to luci.builder.
        priority: Passed through to luci.builder. Overrides builder_group.priority.
        schedule: Passed through to luci.builder.
        disabled: If True, don't set up a schedule, gitiles_poller, or
            cq_tryjob_verifier, but still create the builder so that it can
            be triggered manually.
        service_account: Passed through to luci.builder.
	swarming_tags: Passed through to luci.builder.
    """
    absolute_name = builder_group.bucket + "/" + name
    is_try = builder_group.bucket.endswith("try")
    final_properties = {}
    # "mastername" is the legacy property used to identify buildbot master,
    # which is conveniently used by Chromium infrastructure products for data
    # post processing such as Sheriff-o-Matic.
    #
    # We want to back-fill this information in order to surface the dashboard
    # view group name (used by Milo) to BuildBucket (http://screen/1VJpRuGSf8D).
    # This way we will be able to re-use Sheriff-o-Matic's build filter logic,
    # that was originally created to filter buildbot.
    if builder_group.views:
        final_properties["mastername"] = ', '.join(builder_group.views)
    final_properties.update(properties)
    final_dimensions = {
        "pool": builder_group.pool,
    }
    if dimensions:
        final_dimensions.update(dimensions)
    luci.builder(name=name,
                 bucket=builder_group.bucket,
                 caches=caches,
                 dimensions=final_dimensions,
                 executable=executable,
                 execution_timeout=execution_timeout,
                 notifies=notifies,
                 priority=priority or builder_group.priority,
                 properties=final_properties,
                 triggering_policy=builder_group.triggering_policy,
                 schedule=None if disabled else schedule,
                 service_account=service_account or builder_group.account,
                 swarming_tags=swarming_tags)
    triggering_repos = builder_group.triggering_repos
    if disabled:
        triggering_repos = []
    for repo in triggering_repos:
        if is_try:
            kwargs = {
                'builder': absolute_name,
                'cq_group': _cq_group_name(repo),
                'disable_reuse': cq_disable_reuse,
            }
            kwargs['location_regexp'] = location_regexp
            kwargs['location_regexp_exclude'] = location_regexp_exclude
            luci.cq_tryjob_verifier(**kwargs)
        else:
            for ref in builder_group.triggering_refs or (
                    "refs/heads/master", ):
                luci.gitiles_poller(name=_poller_name(
                    repo, builder_group.poller_suffix, ref, path_regexps),
                                    bucket=builder_group.bucket,
                                    path_regexps=path_regexps,
                                    refs=[ref],
                                    repo=repo,
                                    triggers=[absolute_name])
    for view in builder_group.views:
        if is_try or builder_group.bucket.endswith(("cron", "roller")):
            luci.list_view_entry(builder=absolute_name, list_view=view)
        elif console_short_name:
            luci.console_view_entry(builder=absolute_name,
                                    category=console_category,
                                    console_view=view,
                                    short_name=console_short_name)


common = struct(
    builder=_builder,
    LOCATION_REGEXP_MARKDOWN=LOCATION_REGEXP_MARKDOWN,
    LOCATION_REGEXP_OWNERS=LOCATION_REGEXP_OWNERS,
    cq_group=_cq_group,
    cq_group_name=_cq_group_name,
    poller_name=_poller_name,
)
