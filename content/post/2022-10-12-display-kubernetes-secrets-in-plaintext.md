---
title: Displaying Kubernetes Secrets in Plain Text
subtitle: Shell script to base64-decode Kubernetes Secrets on the fly.
date: 2022-10-12T12:00:00+02:00
tags:
  - kubernetes
  - scripts
---

Kubernetes Secret values are Base-64 encoded. Looking up a secret value using `kubectl`
is somewhat uncomfortable, because you always need to copy/base64-decode the result.

This small shell script automates this step, and gives you the plain values (in json)
straight away.

<!--more-->

If not yet done, install `jq`, `kubectl` and `base64`.
Then put this in your `.bash_profile`:

```bash
function kubesec() {
  local secretname="${1:-NONE}"
  local secretfield="${2:-NONE}"

  case "$#" in
    0)
      kubectl get secret
      ;;
    1)
      kubectl get secret "${secretname}" -ojson | jq ".data | map_values(@base64d)"
      ;;
    2)
      local value="$(kubectl get secret "${secretname}" -ojson | jq -r ".data.${secretfield}")"
      if [[ "$value" != "null" ]]; then
        value="$(base64 --decode <<< "$value")"
      fi
      echo "$value"
      ;;
    *)
      echo "Usage: kubesec [secretname] [secretfield]"
      ;;
  esac
}
```

and then use it like this:

```bash
$ kubesec
NAME                  TYPE                                  DATA   AGE
default-token-abc12   kubernetes.io/service-account-token   3      22h
foo                   Opaque                                2      44s

# and then instead of this
$ kubectl get secret foo -ojson
{
  "apiVersion": "v1",
  "data": {
    "password": "dmVyeV9zZWNyZXQ=",
    "username": "Zm9v"
  },
  "kind": "Secret",
  "metadata": {
    ...
  },
  "type": "Opaque"
}

# do this
$ kubesec foo
{
  "password": "very_secret",
  "username": "foo"
}

# or this
$ kubesec foo password
very_secret
```
