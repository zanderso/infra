# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Utility methods to create builders."""

load("//lib/helpers.star", "helpers")

# Regular expressions for files to skip CQ.
LOCATION_REGEXP_MARKDOWN = r".+/[+]/.*\.md"
LOCATION_REGEXP_OWNERS = r".+/[+].*/OWNERS"
FUCHSIA_CTL_VERSION = "version:0.0.23"

def _repo_url_to_luci_object_name(repo_url):
    """Takes a git repository URL and returns a name for a LUCI object.

    Examples:
        https://foo.googlesource.com/bar/baz -> foo-bar-baz
        https://foo.other-domain.com/bar/baz -> foo.other-domain_com-bar-baz

    Args:
      repo_url(str): The repository url to transform.

    Returns:
      A string with the repository name created from the url.
    """
    domain_and_path = repo_url.split("://")[1].split("/")
    domain = domain_and_path[0]
    path = domain_and_path[1:]
    prefix = domain
    if domain.endswith(".googlesource.com"):
        prefix = domain[:-len(".googlesource.com")] + "-"
    return prefix + "-".join(path).replace(".", "_")

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

    Args:
      ref(str): The git ref to transform.

    Returns:
     A string with git ref parts  joined with '-'.
    """
    parts = ref.split("/")
    char_parts = []
    for part in parts:
        if part.isalnum():
            char_parts.append(part)
    return "-".join(char_parts)

def _cq_group(repo, tree_status_host = None):
    luci.cq_group(
        name = _cq_group_name(repo),
        retry_config = cq.retry_config(
            single_quota = 1,
            global_quota = 2,
            failure_weight = 2,
            transient_failure_weight = 1,
            timeout_weight = 1,
        ),
        tree_status_host = tree_status_host,
        watch = cq.refset(repo, refs = ["refs/heads/.+"]),
    )

def _poller_name(repo_url, poller_suffix, ref, path_regexps = None):
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

def _builder(
        name,
        builder_group,
        executable,
        execution_timeout,
        properties,
        caches = None,
        console_category = None,
        console_short_name = None,
        cq_disable_reuse = False,
        dimensions = None,
        experiment_percentage = None,
        location_regexp = None,
        location_regexp_exclude = None,
        path_regexps = None,
        notifies = None,
        priority = None,
        schedule = None,
        disabled = False,
        swarming_tags = None,
        service_account = None):
    """Creates a builder, notifier, trigger, view entry.

    Args:
	swarming_tags: Tags passed to luci build.
        name: Passed through to luci.builder.
        builder_group: struct from groups_lib.
        executable: Passed through to luci builder.
        execution_timeout: Passed through to luci builder.
        properties: Passed through to luci builder, with some defaults applied.
        caches: Passed through to luci builder.
            Note, a number of global caches are configured by default:
            https://chrome-internal.googlesource.com/infradata/config/+/master/configs/cr-buildbucket/settings.cfg
        console_category: Passed through as category arg to luci.console_view_entry.
            Must be set if console_short_name is set.
        console_short_name: Passed through as short_name arg to luci.console_view_entry.
            Must be set if console_category is set.
        cq_disable_reuse: Passed through to luci.cq_tryjob_verifer. If true,
            this builder will be triggered by every CQ run even if it already
            passed on a previous recent CQ run on the same patchset.
        dimensions: Passed through to luci.builder, with some defaults applied.
        experiment_percentage: Passed through to luci.cq_tryjob_verifier.
        location_regexp: Passed through to luci.cq_tryjob_verifier.
        location_regexp_exclude: Passed through to luci.cq_tryjob_verifier.
        path_regexps: Passed through to luci.gitiles_poller.
        notifies: Passed through to luci.builder.
        priority: Passed through to luci.builder, Overrides builder_group.priority.
        schedule: Passed through to luci.builder.
        disabled: If True, don't set up a schedule, gitiles_poller, or
            cq_tryjob_verifier, but still create the builder so that it can
            be triggered manually.
        service_account: Passed through to luci.builder.
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
        final_properties["mastername"] = ", ".join(builder_group.views)
    final_properties.update(properties)
    final_dimensions = {
        "pool": builder_group.pool,
    }
    if dimensions:
        final_dimensions.update(dimensions)
    luci.builder(
        name = name,
        bucket = builder_group.bucket,
        caches = caches,
        dimensions = final_dimensions,
        executable = executable,
        execution_timeout = execution_timeout,
        notifies = notifies,
        priority = priority or builder_group.priority,
        properties = final_properties,
        triggering_policy = builder_group.triggering_policy,
        schedule = None if disabled else schedule,
        task_template_canary_percentage = 0,
        service_account = service_account or builder_group.account,
        swarming_tags = swarming_tags,
    )
    triggering_repos = builder_group.triggering_repos
    if disabled:
        triggering_repos = []
    for repo in triggering_repos:
        if is_try:
            kwargs = {
                "builder": absolute_name,
                "cq_group": _cq_group_name(repo),
                "disable_reuse": cq_disable_reuse,
            }
            if experiment_percentage:
                kwargs["experiment_percentage"] = experiment_percentage
                if location_regexp:
                    fail(
                        "location_regexp cannot be used simultaneously with " +
                        "experiment_percentage",
                    )
                if location_regexp_exclude:
                    fail("location_regexp_exclude cannot be used " +
                         "simultaneously with experiment_percentage")
            else:
                kwargs["location_regexp"] = location_regexp
                kwargs["location_regexp_exclude"] = location_regexp_exclude
            luci.cq_tryjob_verifier(**kwargs)
        else:
            for ref in builder_group.triggering_refs or (
                "refs/heads/master",
            ):
                luci.gitiles_poller(
                    name = _poller_name(
                        repo,
                        builder_group.poller_suffix,
                        ref,
                        path_regexps,
                    ),
                    bucket = builder_group.bucket,
                    path_regexps = path_regexps,
                    refs = [ref],
                    repo = repo,
                    triggers = [absolute_name],
                )
    for view in builder_group.views:
        if is_try or builder_group.bucket.endswith(("cron", "roller")):
            luci.list_view_entry(builder = absolute_name, list_view = view)
        elif console_short_name:
            luci.console_view_entry(
                builder = absolute_name,
                category = console_category,
                console_view = view,
                short_name = console_short_name,
            )

#############################
def _flutter_builder(
        bucket,
        pool,
        name,
        recipe,
        os,
        properties = {},
        cores = None,
        dimensions = None,
        **kwargs):
    if dimensions:
        dimensions = helpers.merge_dicts({
            "pool": pool,
            "cpu": "x64",
            "os": os,
        }, dimensions)
    else:
        dimensions = {
            "pool": pool,
            "cpu": "x64",
            "os": os,
        }
    if cores != None:
        dimensions["cores"] = cores
    name_parts = name.split("|")
    luci.builder(
        name = name_parts[0],
        bucket = bucket,
        executable = recipe,
        properties = properties,
        service_account = "flutter-" + bucket +
                          "-builder@chops-service-accounts.iam.gserviceaccount.com",
        execution_timeout = 3 * time.hour,
        dimensions = dimensions,
        build_numbers = True,
        task_template_canary_percentage = 0,
        **kwargs
    )

def _try_builder(
        name,
        list_view_name,
        console_view_name = None,
        category = None,
        properties = {},
        **kwargs):
    bucket = "try"
    pool = "luci.flutter.try"
    merged_properties = helpers.merge_dicts(properties, {
        "upload_packages": False,
        "gold_tryjob": True,
    })
    name_parts = name.split("|")

    luci.list_view_entry(
        builder = bucket + "/" + name_parts[0],
        list_view = list_view_name,
    )

    return _flutter_builder(
        bucket,
        pool,
        name,
        properties = merged_properties,
        **kwargs
    )

def _prod_builder(
        name,
        console_view_name,
        category,
        no_notify = False,
        list_view_name = None,
        properties = {},
        **kwargs):
    merged_properties = helpers.merge_dicts(properties, {
        "upload_packages": True,
        "gold_tryjob": False,
    })
    bucket = "prod"
    pool = "luci.flutter.prod"
    name_parts = name.split("|")

    if console_view_name:
        luci.console_view_entry(
            builder = bucket + "/" + name_parts[0],
            console_view = console_view_name,
            category = category,
            short_name = name_parts[1],
        )

    notifies = None if no_notify else [
        luci.notifier(
            name = "blamelist-on-new-failure",
            on_new_failure = True,
            notify_blamelist = True,
        ),
    ]

    return _flutter_builder(
        bucket,
        pool,
        name,
        properties = merged_properties,
        notifies = notifies,
        **kwargs
    )

def _common_builder(**common_kwargs):
    def prod_job(*args, **kwargs):
        return _prod_builder(
            *args,
            **helpers.merge_dicts(common_kwargs, kwargs)
        )

    def try_job(*args, **kwargs):
        cq_args = {}
        cq_args["builder"] = "try/%s" % kwargs["name"].split("|")[0]
        cq_args["cq_group"] = _cq_group_name(kwargs["repo"])
        if kwargs.get("add_cq"):
            kwargs.pop("add_cq")
            luci.cq_tryjob_verifier(**cq_args)
        return _try_builder(
            *args,
            **helpers.merge_dicts(common_kwargs, kwargs)
        )

    return try_job, prod_job

def _mac_builder(properties = {}, caches = None, category = "Mac", **kwargs):
    # see https://chrome-infra-packages.appspot.com/p/infra_internal/ios/xcode/mac/+/
    properties = helpers.merge_dicts(
        {
            "$depot_tools/osx_sdk": {
                "sdk_version": "11a420a",  # 11.0
            },
        },
        properties,
    )
    mac_caches = [swarming.cache("xcode_binary"), swarming.cache("osx_sdk")]
    if caches != None:
        mac_caches.extend(caches)
    return _common_builder(
        os = "Mac-10.14",
        properties = properties,
        caches = mac_caches,
        category = category,
        **kwargs
    )

def _linux_builder(
        properties = {},
        caches = None,
        cores = "8",
        category = "Linux",
        os = None,
        **kwargs):
    linux_caches = [
        swarming.cache(name = "flutter_openjdk_install", path = "java"),
    ]
    properties["fuchsia_ctl_version"] = FUCHSIA_CTL_VERSION
    if caches != None:
        linux_caches.extend(caches)
    return _common_builder(
        os = os or "Linux",
        cores = cores,
        properties = properties,
        caches = linux_caches,
        category = category,
        **kwargs
    )

def _windows_builder(
        properties = {},
        caches = None,
        cores = "8",
        category = "Windows",
        **kwargs):
    windows_caches = [
        swarming.cache(name = "flutter_openjdk_install", path = "java"),
    ]
    if caches != None:
        windows_caches.extend(caches)
    return _common_builder(
        os = "Windows-10",
        cores = cores,
        properties = properties,
        caches = windows_caches,
        category = category,
        **kwargs
    )

_linux_try_builder, _linux_prod_builder = _linux_builder()
_mac_try_builder, _mac_prod_builder = _mac_builder()
_windows_try_builder, _windows_prod_builder = _windows_builder()

common = struct(
    builder = _builder,
    LOCATION_REGEXP_MARKDOWN = LOCATION_REGEXP_MARKDOWN,
    LOCATION_REGEXP_OWNERS = LOCATION_REGEXP_OWNERS,
    cq_group = _cq_group,
    cq_group_name = _cq_group_name,
    poller_name = _poller_name,
    TARGET_X64 = "x64",
    linux_try_builder = _linux_try_builder,
    linux_prod_builder = _linux_prod_builder,
    mac_try_builder = _mac_try_builder,
    mac_prod_builder = _mac_prod_builder,
    windows_try_builder = _windows_try_builder,
    windows_prod_builder = _windows_prod_builder,
)
