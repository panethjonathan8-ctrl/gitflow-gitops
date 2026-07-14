# Changelog

## [0.2.2](https://github.com/panethjonathan8-ctrl/gitflow-gitops/compare/v0.2.1...v0.2.2) (2026-07-14)


### Bug Fixes

* sequence ingress-nginx, external-dns, and eso after lb_controller ([1323f92](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/1323f925aefa6a973c58a8ba444dbf4122860bac))
* sequence ingress-nginx, external-dns, and eso after lb_controller ([0914213](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/091421319cf8c60b3b482d6e451235d14d7c3538)), closes [#19](https://github.com/panethjonathan8-ctrl/gitflow-gitops/issues/19)

## [0.2.1](https://github.com/panethjonathan8-ctrl/gitflow-gitops/compare/v0.2.0...v0.2.1) (2026-07-13)


### Bug Fixes

* ExternalSecret/ClusterSecretStore manifests use unserved external-secrets.io/v1beta1 apiVersion ([0098a18](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/0098a18390d1e20ca5467105989151b3093af40c))
* ExternalSecret/ClusterSecretStore manifests use unserved external-secrets.io/v1beta1 apiVersion ([a8b289c](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/a8b289ceb253082a38036b406afbe6439bb42300)), closes [#12](https://github.com/panethjonathan8-ctrl/gitflow-gitops/issues/12)

## [0.2.0](https://github.com/panethjonathan8-ctrl/gitflow-gitops/compare/v0.1.0...v0.2.0) (2026-07-13)


### Features

* initial import of infrastructure, Helm charts, and ArgoCD manifests ([98eee05](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/98eee05027ea92ea235acf238e41e5c0b7feee7d))


### Bug Fixes

* add required_version and rename versions.tf to providers.tf for new modules ([333e9e6](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/333e9e6355f41beb328de4541d9532931991757e))
* restore missing _envcommon/secrets.hcl, mark alb-lookup output sensitive ([00aafee](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/00aafeea084f33202aa3713f3bbe00b98da0f8fa))
* restore missing _envcommon/secrets.hcl, mark alb-lookup output sensitive ([90913c4](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/90913c4e4588371f7a1d03528dda9edfe3233557)), closes [#1](https://github.com/panethjonathan8-ctrl/gitflow-gitops/issues/1)
* satisfy tflint repo-wide (required_version, dead variables, versions.tf -&gt; providers.tf) ([4a10cd2](https://github.com/panethjonathan8-ctrl/gitflow-gitops/commit/4a10cd20911d5da2024e6d799bca0c55d9ae6ea0)), closes [#5](https://github.com/panethjonathan8-ctrl/gitflow-gitops/issues/5)
