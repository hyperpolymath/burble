; SPDX-License-Identifier: MPL-2.0
;; guix.scm — GNU Guix package definition for burble
;; Usage: guix shell -f guix.scm

(use-modules (guix packages)
             (guix build-system gnu)
             (guix licenses))

(package
  (name "burble")
  (version "0.1.0")
  (source #f)
  (build-system gnu-build-system)
  (synopsis "burble")
  (description "burble — part of the hyperpolymath ecosystem.")
  (home-page "https://github.com/metadatastician/burble")
  (license mpl2.0))
