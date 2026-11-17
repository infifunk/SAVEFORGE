# Unsigned IPA build

The `Xcode iOS Build` GitHub Actions workflow generates an unsigned iOS device archive, packages the `.app` into `SAVEFORGE-unsigned.ipa`, and uploads it as the `SAVEFORGE-Unsigned-IPA` workflow artifact. The IPA is not signed and cannot be installed on a standard iOS device until it is signed with a valid Apple provisioning profile and certificate.
