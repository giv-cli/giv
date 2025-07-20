#!/bin/sh
# provider_node_pkg.sh: Node.js project metadata provider

# Detect presence (0 = yes, >0 = no)
provider_node_pkg_detect() {
  [ -f "package.json" ]
}

# Collect metadata: output KEY=VALUE per line
provider_node_pkg_collect() {
  title=$(jq -r '.name' package.json 2>/dev/null)
  description=$(jq -r '.description' package.json 2>/dev/null)
  version=$(jq -r '.version' package.json 2>/dev/null)
  repository=$(jq -r '.repository.url' package.json 2>/dev/null)
  author=$(jq -r '.author' package.json 2>/dev/null)

  [ -n "$title" ] && printf 'title="%s"\n' "$title"
  [ -n "$description" ] && printf 'description="%s"\n' "$description"
  [ -n "$version" ] && printf 'latest_version="%s"\n' "$version"
  [ -n "$repository" ] && printf 'repository_url="%s"\n' "$repository"
  [ -n "$author" ] && printf 'author="%s"\n' "$author"
}
