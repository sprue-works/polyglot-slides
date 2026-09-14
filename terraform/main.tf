# Cloudflare configuration for polyglot.sprue.works: the hostname's DNS record
# and the Workers route that sends it to the docs-site Worker.
#
# Why Terraform owns the hostname rather than a `custom_domain` route in
# wrangler.jsonc: a non-interactive `wrangler deploy` (what Workers Builds
# runs) attaches a Custom Domain by replacing whatever DNS record exists on
# the hostname without asking, which would take DNS-as-code out of this
# repo's hands. A Workers *route* over a proxied DNS record keeps the record
# here (the intent of #23), and wrangler.jsonc declares no route at all
# (tools/check-listing.sh enforces that). See marketplace/RUNBOOK.md §1 and
# CLAUDE.md "The docs site is a Worker".
#
# State lives in the GCS bucket that sprue-works/infrastructure provisions for
# this repository (backend.tf). Pushes to main that touch terraform/ (or the
# workflow) plan and apply through .github/workflows/terraform.yml -- push
# only, no manual dispatch -- with CLOUDFLARE_API_TOKEN (Zone:Read,
# Zone:DNS:Edit, Zone:Workers Routes:Edit on sprue.works) from the repository
# secret of that name. Nothing here is applied by hand.

terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {}

variable "zone_id" {
  description = "Cloudflare zone ID for sprue.works"
  type        = string
  default     = "0a2832ed293070b06bd75cb7fc8db4d7"
}

variable "hostname" {
  description = "Hostname the docs site is served on (pinned by the OAuth consent screen and the Marketplace listing)"
  type        = string
  default     = "polyglot.sprue.works"
}

variable "worker_name" {
  description = "Name of the Worker in wrangler.jsonc that serves docs/"
  type        = string
  default     = "polyglot-slides"
}

# The record was created through the Cloudflare API by the retired
# tools/reconcile-pages-dns.sh as a DNS-only CNAME to GitHub Pages. This
# import block adopts it into state on the first apply from main, which also
# flips it to proxied and adds the route below: the expected first plan is
# "1 to import, 1 to add, 1 to change, 0 to destroy". Once it is in state the
# block is a no-op and stays as a record of where the resource came from.
import {
  to = cloudflare_dns_record.docs_site
  id = "0a2832ed293070b06bd75cb7fc8db4d7/828fa1c4c5c6e6afef6cab8eaf099f6e"
}

# Every record on the hostname, read fresh at each plan. The retired shell
# reconciler refused to act when an A/AAAA or a second CNAME sat next to the
# record; the precondition below keeps that guarantee, since an import
# adopts one record ID and would not notice siblings on its own.
data "cloudflare_dns_records" "docs_site" {
  zone_id = var.zone_id
  name = {
    exact = var.hostname
  }
}

# Proxied so the route below receives the traffic. The CNAME target is the
# old GitHub Pages origin and is never reached once the route is in front;
# it stays because changing the record type would be a replacement, which
# prevent_destroy refuses -- the hostname must never be unresolvable.
resource "cloudflare_dns_record" "docs_site" {
  zone_id = var.zone_id
  name    = var.hostname
  type    = "CNAME"
  content = "sprue-works.github.io"
  ttl     = 1
  proxied = true

  lifecycle {
    prevent_destroy = true

    precondition {
      condition = (
        length(data.cloudflare_dns_records.docs_site.result) == 1 &&
        data.cloudflare_dns_records.docs_site.result[0].type == "CNAME"
      )
      error_message = "${var.hostname} must carry exactly one record, a CNAME, before Terraform manages or proxies it; found ${length(data.cloudflare_dns_records.docs_site.result)} record(s). Resolve the extra records by hand after identifying their owner (they were never this stack's)."
    }
  }
}

# The route takes precedence over the record's origin, so from the first
# apply the Worker serves the hostname. A route needs a proxied record on the
# hostname to receive traffic, hence the dependency.
resource "cloudflare_workers_route" "docs_site" {
  zone_id = var.zone_id
  pattern = "${var.hostname}/*"
  script  = var.worker_name

  depends_on = [cloudflare_dns_record.docs_site]
}
