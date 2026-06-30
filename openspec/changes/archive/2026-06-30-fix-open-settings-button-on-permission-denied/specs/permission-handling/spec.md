# Permission Handling (Delta)

No requirements are added, modified, or removed. This is a bug fix: the existing requirement "Handle permanently denied permissions" already specifies the system SHALL open system settings via `openAppSettings()` from `permission_handler`. The implementation simply wasn't calling it correctly due to a recursive name collision.
