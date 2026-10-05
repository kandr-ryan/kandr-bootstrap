## [Unreleased]

### Added
- `kandr-dns` skill: Cloudflare is authoritative DNS for `kandr.io` (full setup, Free)
- Initial macOS bootstrap installer (`install.sh`)
- Shareable Cursor skills for workstyle bootstrap, changelog/release, iOS fastlane, architect mode, and ops loop

### Changed
- DNS / new `*.kandr.io` hostnames route to `kandr-dns`; `kandr-aws` keeps AWS CLI / SES / leftover EC2. Hosted zone `Z5Q853FSJIIQT` is retired for writes.
