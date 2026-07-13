# Changelog

## [0.2.0](https://github.com/panethjonathan8-ctrl/gitflow-gitops/compare/v0.1.0...v0.2.0) (2026-07-13)


### Features

* initial import of infrastructure, Helm charts, and ArgoCD manifests ([98eee05](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/98eee05027ea92ea235acf238e41e5c0b7feee7d))


### Bug Fixes

* add required_version and rename versions.tf to providers.tf for new modules ([333e9e6](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/333e9e6355f41beb328de4541d9532931991757e))
* restore missing _envcommon/secrets.hcl, mark alb-lookup output sensitive ([00aafee](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/00aafeea084f33202aa3713f3bbe00b98da0f8fa))
* restore missing _envcommon/secrets.hcl, mark alb-lookup output sensitive ([90913c4](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/90913c4e4588371f7a1d03528dda9edfe3233557)), closes [#1](https://github.com/panethjonathan8-ctrl/gitflow-gitops/issues/1)
* satisfy tflint repo-wide (required_version, dead variables, versions.tf -&gt; providers.tf) ([4a10cd2](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/4a10cd20911d5da2024e6d799bca0c55d9ae6ea0)), closes [#5](https://github.com/panethjonathan8-ctrl/gitflow-gitops/issues/5)
