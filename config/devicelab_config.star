#!/usr/bin/env lucicfg
# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""
Configurations for devicelab tests.

The schedulers pull commits indirectly from GoB repo (https://chromium.googlesource.com/external/github.com/flutter/flutter)
which is mirrored from https://github.com/flutter/flutter.
"""

load("//lib/common.star", "common")
load("//lib/repos.star", "repos")
load("//lib/timeout.star", "timeout")

# Global xcode version for flutter/devicelab tests.
XCODE_VERSION = "12c33"

# Global OS variables
LINUX_OS = "Linux"
WINDOWS_OS = "Windows-Server"
MAC_OS = "Mac-10.15"

# Linux caches
LINUX_DEFAULT_CACHES = [
    # Android SDK
    swarming.cache(name = "android_sdk", path = "android"),
    # Chrome
    swarming.cache(name = "chrome_and_driver", path = "chrome"),
    # OpenJDK
    swarming.cache(name = "openjdk", path = "java"),
    # PubCache
    swarming.cache(name = "pub_cache", path = ".pub-cache"),
    # Flutter SDK code
    swarming.cache(name = "flutter_sdk", path = "flutter sdk"),
]

# Default caches for Mac android builders
MAC_ANDROID_DEFAULT_CACHES = [
    # Android SDK
    swarming.cache(name = "android_sdk", path = "android"),
    # Chrome
    swarming.cache(name = "chrome_and_driver", path = "chrome"),
    # OpenJDK
    swarming.cache(name = "openjdk", path = "java"),
    # PubCache
    swarming.cache(name = "pub_cache", path = ".pub-cache"),
    # Flutter SDK code
    swarming.cache(name = "flutter_sdk", path = "flutter sdk"),
]

# Mac caches
MAC_DEFAULT_CACHES = [
    # Android SDK
    swarming.cache(name = "android_sdk", path = "android"),
    # Chrome
    swarming.cache(name = "chrome_and_driver", path = "chrome"),
    # OpenJDK
    swarming.cache(name = "openjdk", path = "java"),
    # PubCache
    swarming.cache(name = "pub_cache", path = ".pub-cache"),
    # Flutter SDK code
    swarming.cache(name = "flutter_sdk", path = "flutter sdk"),
    # Xcode
    swarming.cache("xcode_binary"),
    swarming.cache("osx_sdk"),
]

# Windows caches
WIN_DEFAULT_CACHES = [
    # Android SDK
    swarming.cache(name = "android_sdk", path = "android"),
    # Chrome
    swarming.cache(name = "chrome_and_driver", path = "chrome"),
    # OpenJDK
    swarming.cache(name = "openjdk", path = "java"),
    # PubCache
    swarming.cache(name = "pub_cache", path = ".pub-cache"),
    # Flutter SDK code
    swarming.cache(name = "flutter_sdk", path = "flutter sdk"),
]

def _setup(branches):
    devicelab_prod_config("stable", branches.stable.version, branches.stable.testing_ref)
    devicelab_prod_config("beta", branches.beta.version, branches.beta.testing_ref)
    devicelab_prod_config("dev", branches.dev.version, branches.dev.testing_ref)
    devicelab_prod_config("master", branches.master.version, branches.master.testing_ref)

    devicelab_try_config()

def devicelab_prod_config(branch, version, ref):
    """Prod configurations for the framework repository.

    Args:
      branch(str): The branch name we are creating configurations for.
      version(str): One of dev|beta|stable.
      ref(str): The git ref we are creating configurations for.
    """

    # Feature toggle for collecting DeviceLab tests on LUCI. This change landed
    # in flutter/flutter#70702 and must roll through before enabling for more
    # branches beyond master (eg dev, beta, stable).
    UPLOAD_METRICS_CHANNELS = ("master")

    branched_builder_prefix = "" if branch == "master" else " " + branch

    # TODO(godofredoc): Merge the recipe names once we remove the old one.
    drone_recipe_name = ("devicelab/devicelab_drone_" + version if version else "devicelab/devicelab_drone")
    luci.recipe(
        name = drone_recipe_name,
        cipd_package = "flutter/recipe_bundles/flutter.googlesource.com/recipes",
        cipd_version = "refs/heads/master",
        use_bbagent = True,
    )

    # Defines console views for prod builders
    console_view_name = ("devicelab" if branch == "master" else "%s_devicelab" % branch)
    luci.console_view(
        name = console_view_name,
        repo = repos.FLUTTER,
        refs = [ref],
    )

    # Defines prod schedulers
    trigger_name = branch + "-gitiles-trigger-devicelab"
    luci.gitiles_poller(
        name = trigger_name,
        bucket = "prod",
        repo = repos.FLUTTER,
        refs = [ref],
    )

    # Defines triggering policy
    if branch == "master":
        triggering_policy = scheduler.greedy_batching(
            max_batch_size = 3,
            max_concurrent_invocations = 1,
        )

        # DeviceLab has limited resources and we want to bundle
        # as much as possible to ensure we are always testing ToT.
        devicelab_triggering_policy = scheduler.greedy_batching(
            max_batch_size = 20,
            max_concurrent_invocations = 1,
        )
        priority = 30
    else:
        triggering_policy = scheduler.greedy_batching(
            max_batch_size = 1,
            max_concurrent_invocations = 3,
        )
        devicelab_triggering_policy = triggering_policy
        priority = 29

    # Defines framework prod builders

    # Linux prod builders.
    common.linux_prod_builder(
        name = "Linux%s build_aar_module_test|arr" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "build_aar_module_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_prod_builder(
        name = "Linux%s gradle_non_android_plugin_test|gnap" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "gradle_non_android_plugin_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_prod_builder(
        name = "Linux%s gradle_desugar_classes_test|gnap" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "gradle_desugar_classes_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_prod_builder(
        name = "Linux%s gradle_plugin_bundle_test|gpb" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "gradle_plugin_bundle_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_prod_builder(
        name = "Linux%s gradle_plugin_fat_apk_test|gpfa" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "gradle_plugin_fat_apk_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_prod_builder(
        name = "Linux%s gradle_plugin_light_apk_test|gpla" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "gradle_plugin_light_apk_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_prod_builder(
        name = "Linux%s module_host_with_custom_build_test|mhwcb" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "module_host_with_custom_build_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_prod_builder(
        name = "Linux%s module_custom_host_app_name_test|mchan" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "module_custom_host_app_name_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_prod_builder(
        name = "Linux%s module_test|mod" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "module_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_prod_builder(
        name = "Linux%s plugin_test|plugin" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "plugin_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )

    # Linux prod builders with a device.
    linux_tasks = [
        "analyzer_benchmark",
        "android_defines_test",
        "android_obfuscate_test",
        "android_stack_size_test",
        "android_view_scroll_perf__timeline_summary",
        "animated_placeholder_perf__e2e_summary",
        "backdrop_filter_perf__e2e_summary",
        "basic_material_app_android__compile",
        "color_filter_and_fade_perf__e2e_summary",
        "complex_layout_android__compile",
        "complex_layout_android__scroll_smoothness",
        "complex_layout_scroll_perf__devtools_memory",
        "complex_layout_semantics_perf",
        "cubic_bezier_perf__e2e_summary",
        "cubic_bezier_perf_sksl_warmup__e2e_summary",
        "cull_opacity_perf__e2e_summary",
        "fast_scroll_heavy_gridview__memory",
        "flutter_engine_group_performance",
        "flutter_gallery__back_button_memory",
        "flutter_gallery__image_cache_memory",
        "flutter_gallery__memory_nav",
        "flutter_gallery__start_up",
        "flutter_gallery__transition_perf_e2e",
        "flutter_gallery__transition_perf_hybrid",
        "flutter_gallery__transition_perf_with_semantics",
        "flutter_gallery__transition_perf",
        "flutter_gallery_android__compile",
        "flutter_gallery_sksl_warmup__transition_perf_e2e",
        "flutter_gallery_sksl_warmup__transition_perf",
        "flutter_gallery_v2_chrome_run_test",
        "flutter_gallery_v2_web_compile_test",
        "flutter_test_performance",
        "frame_policy_delay_test_android",
        "hot_mode_dev_cycle_linux__benchmark",
        "image_list_jit_reported_duration",
        "image_list_reported_duration",
        "large_image_changer_perf_android",
        "linux_chrome_dev_mode",
        "multi_widget_construction_perf__e2e_summary",
        "new_gallery__crane_perf",
        "picture_cache_perf__e2e_summary",
        "platform_views_scroll_perf__timeline_summary",
        "routing_test",
        "textfield_perf__e2e_summary",
        "web_size__compile_test",
    ]

    for task in linux_tasks:
        common.linux_prod_builder(
            name = "Linux%s %s|%s" % (branched_builder_prefix, task, common.short_name(task)),
            recipe = drone_recipe_name,
            console_view_name = console_view_name,
            triggered_by = [trigger_name],
            triggering_policy = devicelab_triggering_policy,
            properties = {
                "dependencies": [
                    {
                        "dependency": "android_sdk",
                    },
                    {
                        "dependency": "chrome_and_driver",
                    },
                    {
                        "dependency": "open_jdk",
                    },
                    {
                        "dependency": "curl",
                    },
                ],
                "task_name": task,
                "upload_metrics": branch in UPLOAD_METRICS_CHANNELS,
                "use_cas": True,
            },
            pool = "luci.flutter.prod",
            os = "Android",
            dimensions = {"device_os": "N"},
            # TODO(keyonghan): adjust the timeout when devicelab linux tasks are stable:
            # https://github.com/flutter/flutter/issues/72383.
            expiration_timeout = timeout.XL,
            execution_timeout = timeout.SHORT,
            caches = LINUX_DEFAULT_CACHES,
            category = "Linux_android",
        )

    # Linux prod builders.
    linux_vm_tasks = [
        "dartdocs",
        "technical_debt__cost",
        "web_benchmarks_canvaskit",
        "web_benchmarks_html",
    ]
    for task in linux_vm_tasks:
        common.linux_prod_builder(
            name = "Linux%s %s|%s" % (branched_builder_prefix, task, common.short_name(task)),
            recipe = drone_recipe_name,
            console_view_name = console_view_name,
            triggered_by = [trigger_name],
            triggering_policy = triggering_policy,
            priority = priority,
            properties = {
                "dependencies": [
                    {
                        "dependency": "android_sdk",
                    },
                    {
                        "dependency": "chrome_and_driver",
                    },
                    {
                        "dependency": "curl",
                    },
                ],
                "task_name": task,
                "upload_metrics": branch in UPLOAD_METRICS_CHANNELS,
                "use_cas": True,
            },
            caches = LINUX_DEFAULT_CACHES,
            os = LINUX_OS,
        )

    # Mac host with android phones
    mac_android_tasks = [
        "android_semantics_integration_test",
        "backdrop_filter_perf__timeline_summary",
        "channels_integration_test",
        "color_filter_and_fade_perf__timeline_summary",
        "complex_layout_scroll_perf__memory",
        "complex_layout_scroll_perf__timeline_summary",
        "complex_layout__start_up",
        "cubic_bezier_perf_sksl_warmup__timeline_summary",
        "cubic_bezier_perf__timeline_summary",
        "cull_opacity_perf__timeline_summary",
        "drive_perf_debug_warning",
        "embedded_android_views_integration_test",
        "external_ui_integration_test",
        "fading_child_animation_perf__timeline_summary",
        "fast_scroll_large_images__memory",
        "flavors_test",
        "flutter_view__start_up",
        "fullscreen_textfield_perf__timeline_summary",
        "hello_world_android__compile",
        "hello_world__memory",
        "home_scroll_perf__timeline_summary",
        "hot_mode_dev_cycle__benchmark",
        "hybrid_android_views_integration_test",
        "imagefiltered_transform_animation_perf__timeline_summary",
        "integration_test_test",
        "integration_ui_driver",
        "integration_ui_keyboard_resize",
        "integration_ui_screenshot",
        "integration_ui_textfield",
        "microbenchmarks",
        "new_gallery__transition_perf",
        "picture_cache_perf__timeline_summary",
        "platform_channel_sample_test",
        "platform_interaction_test",
        "platform_view__start_up",
        "run_release_test",
        "service_extensions_test",
        "smoke_catalina_start_up",
        "textfield_perf__timeline_summary",
        "tiles_scroll_perf__timeline_summary",
    ]

    for task in mac_android_tasks:
        common.mac_prod_builder(
            name = "Mac_android%s %s|%s" % (branched_builder_prefix, task, common.short_name(task)),
            recipe = drone_recipe_name,
            console_view_name = console_view_name,
            triggered_by = [trigger_name],
            triggering_policy = triggering_policy,
            priority = priority,
            properties = {
                "dependencies": [
                    {
                        "dependency": "android_sdk",
                    },
                    {
                        "dependency": "chrome_and_driver",
                    },
                    {
                        "dependency": "open_jdk",
                    },
                ],
                "task_name": task,
                "upload_metrics": branch in UPLOAD_METRICS_CHANNELS,
                "use_cas": True,
            },
            pool = "luci.flutter.prod",
            os = MAC_OS,
            category = "Mac_android",
            dimensions = {"device_os": "N"},
            expiration_timeout = timeout.XL,
            execution_timeout = timeout.SHORT,
            caches = MAC_ANDROID_DEFAULT_CACHES,
        )

    # Mac host with ios phones
    mac_ios_tasks = [
        "backdrop_filter_perf_ios__timeline_summary",
        "basic_material_app_ios__compile",
        "channels_integration_test_ios",
        "complex_layout_ios__compile",
        "complex_layout_ios__start_up",
        "complex_layout_scroll_perf_ios__timeline_summary",
        "external_ui_integration_test_ios",
        "flavors_test_ios",
        "flutter_gallery__transition_perf_e2e_ios",
        "flutter_gallery_ios__compile",
        "flutter_gallery_ios__start_up",
        "flutter_gallery_ios__transition_perf",
        "flutter_view_ios__start_up",
        "hello_world_ios__compile",
        "hot_mode_dev_cycle_macos_target__benchmark",
        "integration_test_test_ios",
        "integration_ui_ios_driver",
        "integration_ui_ios_keyboard_resize",
        "integration_ui_ios_screenshot",
        "integration_ui_ios_textfield",
        "ios_app_with_extensions_test",
        "ios_content_validation_test",
        "ios_defines_test",
        "ios_platform_view_tests",
        "large_image_changer_perf_ios",
        "macos_chrome_dev_mode",
        "microbenchmarks_ios",
        "new_gallery_ios__transition_perf",
        "platform_channel_sample_test_ios",
        "platform_channel_sample_test_swift",
        "platform_interaction_test_ios",
        "platform_view_ios__start_up",
        "platform_views_scroll_perf_ios__timeline_summary",
        "post_backdrop_filter_perf_ios__timeline_summary",
        "simple_animation_perf_ios",
        "smoke_catalina_hot_mode_dev_cycle_ios__benchmark",
        "tiles_scroll_perf_ios__timeline_summary",
    ]

    for task in mac_ios_tasks:
        common.mac_prod_builder(
            name = "Mac_ios%s %s|%s" % (branched_builder_prefix, task, common.short_name(task)),
            recipe = drone_recipe_name,
            console_view_name = console_view_name,
            triggered_by = [trigger_name],
            triggering_policy = triggering_policy,
            properties = {
                "$flutter/devicelab_osx_sdk": {
                    "sdk_version": XCODE_VERSION,
                },
                "dependencies": [
                    {
                        "dependency": "xcode",
                    },
                    {
                        "dependency": "gems",
                    },
                    {
                        "dependency": "ios_signing",
                    },
                ],
                "task_name": task,
                "upload_metrics": branch in UPLOAD_METRICS_CHANNELS,
                "use_cas": True,
            },
            pool = "luci.flutter.prod",
            os = MAC_OS,
            category = "Mac_ios",
            dimensions = {"device_os": "iOS-14.4.2"},
            execution_timeout = timeout.SHORT,
            expiration_timeout = timeout.LONG_EXPIRATION,
            caches = MAC_DEFAULT_CACHES,
        )

    # Mac host with ios32
    mac_ios32_tasks = [
        "native_ui_tests_ios32",
        "flutter_gallery__transition_perf_e2e_ios32",
    ]
    for task in mac_ios32_tasks:
        common.mac_prod_builder(
            name = "Mac_ios%s %s|%s" % (branched_builder_prefix, task, common.short_name(task)),
            recipe = drone_recipe_name,
            console_view_name = console_view_name,
            triggered_by = [trigger_name],
            triggering_policy = triggering_policy,
            properties = {
                "$flutter/devicelab_osx_sdk": {
                    "sdk_version": XCODE_VERSION,
                },
                "dependencies": [
                    {
                        "dependency": "xcode",
                    },
                    {
                        "dependency": "gems",
                    },
                    {
                        "dependency": "ios_signing",
                    },
                ],
                "task_name": task,
                "upload_metrics": branch in UPLOAD_METRICS_CHANNELS,
                "use_cas": True,
            },
            pool = "luci.flutter.prod",
            os = MAC_OS,
            dimensions = {"device_os": "iOS-9.3.6"},
            execution_timeout = timeout.LONG,
            expiration_timeout = timeout.LONG_EXPIRATION,
            caches = MAC_DEFAULT_CACHES,
        )

    # Mac prod builders.
    common.mac_prod_builder(
        name = "Mac%s build_aar_module_test|aarm" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "build_aar_module_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_non_android_plugin_test|gnap" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_non_android_plugin_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_plugin_bundle_test|gpbt" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_plugin_bundle_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_plugin_fat_apk_test|gpfa" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_plugin_fat_apk_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_prod_builder(
        name = "Mac%s gradle_plugin_light_apk_test|gpla" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_plugin_light_apk_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_prod_builder(
        name = "Mac%s module_host_with_custom_build_test|mhwcb" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_host_with_custom_build_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_prod_builder(
        name = "Mac%s module_custom_host_app_name_test|mchan" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_custom_host_app_name_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_prod_builder(
        name = "Mac%s module_test|mod" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_prod_builder(
        name = "Mac%s module_test_ios|mios" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_test_ios",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_prod_builder(
        name = "Mac%s build_ios_framework_module_test|bifm" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "build_ios_framework_module_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )

    common.mac_prod_builder(
        name = "Mac%s plugin_lint_mac|plm" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "plugin_lint_mac",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_prod_builder(
        name = "Mac%s plugin_test|plugin" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "plugin_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_prod_builder(
        name = "Mac%s dart_plugin_registry_test|dart_plugin" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        properties = {
            "dependencies": [
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "dart_plugin_registry_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )

    # Windows prod builders
    common.windows_prod_builder(
        name = "Windows%s build_aar_module_test|aarm" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "build_aar_module_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_non_android_plugin_test|gnap" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_non_android_plugin_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_plugin_bundle_test|gpbt" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_plugin_bundle_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_plugin_fat_apk_test|gpfa" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_plugin_fat_apk_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_prod_builder(
        name = "Windows%s gradle_plugin_light_apk_test|gpla" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_plugin_light_apk_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_prod_builder(
        name = "Windows%s module_host_with_custom_build_test|mhwcb" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "module_host_with_custom_build_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_prod_builder(
        name = "Windows%s module_custom_host_app_name_test|mchan" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "module_custom_host_app_name_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_prod_builder(
        name = "Windows%s module_test|mod" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "module_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_prod_builder(
        name = "Windows%s plugin_test|plugin" % ("" if branch == "master" else " " + branch),
        recipe = drone_recipe_name,
        console_view_name = console_view_name,
        triggered_by = [trigger_name],
        triggering_policy = triggering_policy,
        priority = priority,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "plugin_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )

    # Desktop Windows prod builders
    # Currently Windows is only supported on master and dev.
    if ref in (r"refs/heads/master", r"refs/heads/dev"):
        windows_desktop_tasks = [
            "hot_mode_dev_cycle_win_target__benchmark",
        ]
        for task in windows_desktop_tasks:
            common.windows_prod_builder(
                name = "Windows%s %s|%s" % (branched_builder_prefix, task, common.short_name(task)),
                recipe = drone_recipe_name,
                console_view_name = console_view_name,
                triggered_by = [trigger_name],
                triggering_policy = triggering_policy,
                priority = priority,
                properties = {
                    "task_name": task,
                    "use_cas": True,
                },
                caches = WIN_DEFAULT_CACHES,
                os = WINDOWS_OS,
            )

def devicelab_try_config():
    """Try configurations for the framework repository."""

    drone_recipe_name = "devicelab/devicelab_drone"

    # Defines a list view for try builders
    list_view_name = "devicelab-try"
    luci.list_view(
        name = "devicelab-try",
        title = "devicelab try builders",
    )

    # Defines devicelab try builders

    # Linux try builders.
    common.linux_try_builder(
        name = "Linux build_aar_module_test|aarm",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "build_aar_module_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_try_builder(
        name = "Linux gradle_desugar_classes_test|gjet",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "gradle_desugar_classes_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_try_builder(
        name = "Linux gradle_jetifier_test|gjet",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "gradle_jetifier_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )

    # TODO(fujino): remove once https://github.com/flutter/flutter/pull/80161
    # rolls to stable
    common.linux_try_builder(
        name = "Linux gradle_non_android_plugin_test|gnap",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "gradle_non_android_plugin_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_try_builder(
        name = "Linux gradle_plugin_bundle_test|gpbt",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "gradle_plugin_bundle_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_try_builder(
        name = "Linux gradle_plugin_fat_apk_test|gpfa",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "gradle_plugin_fat_apk_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_try_builder(
        name = "Linux gradle_plugin_light_apk_test|gpla",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "gradle_plugin_light_apk_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_try_builder(
        name = "Linux module_host_with_custom_build_test|mhwcb",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "module_host_with_custom_build_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_try_builder(
        name = "Linux module_custom_host_app_name_test|mchan",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "module_custom_host_app_name_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_try_builder(
        name = "Linux module_test|module",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "module_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_try_builder(
        name = "Linux plugin_test|plugin",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "plugin_test",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )
    common.linux_try_builder(
        name = "Linux web_benchmarks_html|wbh",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "curl"}],
            "task_name": "web_benchmarks_html",
            "use_cas": True,
        },
        caches = LINUX_DEFAULT_CACHES,
        os = LINUX_OS,
    )

    # Desktop Linux try builders
    linux_desktop_tasks = [
        "hot_mode_dev_cycle_linux_target__benchmark",
    ]
    for task in linux_desktop_tasks:
        common.linux_try_builder(
            name = "Linux %s|%s" % (task, common.short_name(task)),
            recipe = drone_recipe_name,
            repo = repos.FLUTTER,
            list_view_name = list_view_name,
            properties = {
                "dependencies": [
                    {
                        "dependency": "clang",
                    },
                    {
                        "dependency": "cmake",
                    },
                    {
                        "dependency": "ninja",
                    },
                    {
                        "dependency": "curl",
                    },
                ],
                "task_name": task,
                "use_cas": True,
            },
            caches = LINUX_DEFAULT_CACHES,
            os = LINUX_OS,
        )

    # Mac try builders.
    common.mac_try_builder(
        name = "Mac build_aar_module_test|aarm",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "build_aar_module_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )

    # TODO(fujino): remove once https://github.com/flutter/flutter/pull/80161
    # rolls to stable
    common.mac_try_builder(
        name = "Mac gradle_non_android_plugin_test|gnap",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_non_android_plugin_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_try_builder(
        name = "Mac gradle_plugin_bundle_test|gpbt",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_plugin_bundle_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_try_builder(
        name = "Mac gradle_plugin_fat_apk_test|gpfa",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_plugin_fat_apk_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_try_builder(
        name = "Mac gradle_plugin_light_apk_test|gpla",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "gradle_plugin_light_apk_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_try_builder(
        name = "Mac module_host_with_custom_build_test|mhwcb",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_host_with_custom_build_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_try_builder(
        name = "Mac module_custom_host_app_name_test|mchan",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_custom_host_app_name_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_try_builder(
        name = "Mac module_test|mod",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_try_builder(
        name = "Mac module_test_ios|mios",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "module_test_ios",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_try_builder(
        name = "Mac build_ios_framework_module_test|bifm",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "build_ios_framework_module_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )

    common.mac_try_builder(
        name = "Mac plugin_lint_mac|plm",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "plugin_lint_mac",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_try_builder(
        name = "Mac plugin_test|plugin",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "android_sdk",
                },
                {
                    "dependency": "open_jdk",
                },
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "plugin_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )
    common.mac_try_builder(
        name = "Mac dart_plugin_registry_test|dart_plugin",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [
                {
                    "dependency": "xcode",
                },
                {
                    "dependency": "gems",
                },
            ],
            "$flutter/osx_sdk": {
                "sdk_version": XCODE_VERSION,
            },
            "task_name": "dart_plugin_registry_test",
            "use_cas": True,
        },
        caches = MAC_DEFAULT_CACHES,
        dimensions = {"device_type": "none"},
        os = MAC_OS,
    )

    # Windows try builders.
    common.windows_try_builder(
        name = "Windows build_aar_module_test|aarm",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        add_cq = True,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "build_aar_module_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = "Windows-Server",
    )

    # TODO(fujino): remove once https://github.com/flutter/flutter/pull/80161
    # rolls to stable
    common.windows_try_builder(
        name = "Windows gradle_non_android_plugin_test|gnap",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_non_android_plugin_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_try_builder(
        name = "Windows gradle_plugin_bundle_test|gpbt",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_plugin_bundle_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_try_builder(
        name = "Windows gradle_plugin_fat_apk_test|gpfa",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_plugin_fat_apk_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_try_builder(
        name = "Windows gradle_plugin_light_apk_test|gpla",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "gradle_plugin_light_apk_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_try_builder(
        name = "Windows module_host_with_custom_build_test|mhwcb",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "module_host_with_custom_build_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_try_builder(
        name = "Windows module_custom_host_app_name_test|mchan",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "module_custom_host_app_name_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_try_builder(
        name = "Windows module_test|mod",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "module_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )
    common.windows_try_builder(
        name = "Windows plugin_test|plugin",
        recipe = drone_recipe_name,
        repo = repos.FLUTTER,
        list_view_name = list_view_name,
        properties = {
            "dependencies": [{"dependency": "android_sdk"}, {"dependency": "chrome_and_driver"}, {"dependency": "open_jdk"}],
            "task_name": "plugin_test",
            "use_cas": True,
        },
        caches = WIN_DEFAULT_CACHES,
        os = WINDOWS_OS,
    )

    # Desktop Windows try builders
    windows_desktop_tasks = [
        "hot_mode_dev_cycle_win_target__benchmark",
    ]
    for task in windows_desktop_tasks:
        common.windows_try_builder(
            name = "Windows %s|%s" % (task, common.short_name(task)),
            recipe = drone_recipe_name,
            repo = repos.FLUTTER,
            list_view_name = list_view_name,
            properties = {
                "task_name": task,
                "use_cas": True,
            },
            caches = WIN_DEFAULT_CACHES,
            os = WINDOWS_OS,
        )

devicelab_config = struct(setup = _setup)
