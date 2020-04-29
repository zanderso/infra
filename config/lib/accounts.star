# Copyright 2020 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


# Service accounts
def flutter_infra_account(user):
    return user + "@chops-service-accounts.iam.gserviceaccount.com"


accounts = struct(
    FLUTTER_PROD=flutter_infra_account("flutter-prod-builder"),
    FLUTTER_TRY=flutter_infra_account("flutter-try-builder"),
)
