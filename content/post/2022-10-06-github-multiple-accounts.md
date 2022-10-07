---
title: GIT and OpenSSH with multiple identities
subtitle: How to set up GIT and OpenSSH for multiple identities, also with PaaS like GitHub/Gitlab etc.
date: 2022-10-06T20:00:00+02:00
tags:
  - git
  - github
  - ssh
---

If you use your computer in multiple contexts (private, work, multiple client projects), you might
run into issues like having to use different identities for these contexts. For `git` this usually
boils down to SSH keys and names or e-mail addresses for your commits.

This can be a pain to work with -- after trying multiple solutions I found on the web (or puzzle
pieces thereof), I created a combination that works completely automatic once it's set up, and
that might be worth sharing.

<!--more-->

## Detailed problem description

The issue is actually two-fold:

- For every pull/push, ssh needs to determine which SSH key to use. The default behaviour of
  SSH to just try the same key (or list of those) for every connection is problematic with
  git, since a key can be bound to one SSH user only. If you have multiple accounts on GitHub
  you need to use different keys.
- For every commit, git needs an identity to use (user name, e-mail) which is then persited forever
  in the git log. While your name might be identical all the time, using your private address
  in work repositories or vice versa might be not desirable.

### Using different ssh keys depending on context (especially with multiple PaaS Accounts)

GitHub uses a single host name `github.com` for all repositories, and when using GitHub via SSH,
the SSH key identifies the user. The well-known OpenSSH feature of key selection based on
host names does not help, since there is only one host: `github.com`. I guess, (also) because of
this problem, GitHub recommends using only one account per user -- which works until there is
this new customer that requires you to create an extra GitHub account to join the customer's
organization, or uses GitHub enterprise managed users.

The same might apply for other git PaaS platforms using a single host name.

### Use different git author name and e-mail depending on context

Git uses your user name and e-mail in every commit you make and persists it to the log. To keep
things clean, you may not want to use your work email when committing to your private pet
projects, or the other way around: use this embarrasing `l33t-c0der@hotmail.com` e-mail-address
when committing at a project for your employer or for some important, but stiff client.

## Solution

Disclaimer: This solution is a combination of approaches found elsewhere, and tested to be working on MacOS.
It should work similarly on other Linux/Un\*xes and Windows Subsystem for Linux, not so sure about other
Windows setups (input welcome). Please excuse me for not giving credit to all stackoverflow threads,
blog posts and gists that I found along the way. I did not invent most of this, I just combined it.

This solution uses **directories** as primary context containers, automatically switching identities
based on the **current working directory**. So, for each context, you create one directory, and that
directory then hosts subdirectories for all software projects (git repositories) of that context.
Switching contexts is done by just using `cd`.

Typically, unixoid systems have their user homes in `/home`. On MacOS, all user homes are in
`/Users`. Since I am using MacOS, this is what this example uses. Also, while this example is
using only GitHub, it should work for other providers (e.g. Gitlab) as well.

This example creates two contexts -- one for my private stuff, and one for my work
environment. You can have as many contexts as you like -- just do not let these directories
overlap -- do not use context folders that are nested in other context folders. Instead keep
them separate, like this:

```text
/Users/easimon/development/
  \_ hobby/
  \_ work/
```

or flat:

```text
/Users/easimon/development/hobby
/Users/easimon/development/work
```

Effectively you have two "context root" folders. Whenever you `cd` to one of the directories,
you assume a specific ssh *and* git identity. All git clones are can then be subdirectories of
one of these context roots.

The implementation of this is two-fold: Configure OpenSSH to automatically select the correct
SSH key, and configure git to automatically configure real name and e-mail address.

### OpenSSH configuration

Using the `Match` clause you can create working-directory specific settings in OpenSSH.
If necessary, you can reconfigure all options based on current working directory, but
we'll just switch the `IdentityFile`.

#### TL;DR

`ssh_config` allows for directory-specific configuration using the following
`Match` hack.

```ssh_config
Match host github.com exec "pwd | grep -qE '^/some/absolute/path(/.*)?$'"
  IdentityFile ~/.ssh/some-key
```

#### Step by step

You require one ssh key per context, which must / should do not be one of the "default"
`id_rsa` or `id_dsa` etc. keys, since there's some OpenSSH automagic to always include these
keys when authenticating. Also, don't add these "default" keys to your GitHub
account ssh keys, as doing so can interfere with this setup. I also recommend to *not* set a
default catch-all-key for github.com globally. Instead, keep all your git ssh clones in
one of the context root directories you defined.

Create one SSH identity (key file) for each context:

```bash
ssh-keygen -f ~/.ssh/id_hobby
ssh-keygen -f ~/.ssh/id_work
```

Then, to enable automatic identity switching, add the following to `~/.ssh/config`:

```ssh_config
# Global options
Host *
  # Always only use specified identities, do not fall back to
  # everything found in ssh-agent.
  IdentitiesOnly yes

# Repeat following for each context

## When in "hobby" context directory, use "hobby" ssh key for github.com
Match host github.com exec "pwd | grep -qE '^%d/development/hobby(/.*)?$'"
  IdentityFile ~/.ssh/id_hobby

## When in "work" context directory, use "work" ssh key for github.com
Match host github.com exec "pwd | grep -qE '^%d/development/work(/.*)?$'"
  IdentityFile ~/.ssh/id_work

### Of course, other hosts that require this context
### can be added as well, just using the host name
Host bitbucket.work.com
  User git
  IdentityFile ~/.ssh/id_work
```

For each directory, make sure you get the grep expression right, for a subfolder `foo/bar`
in your home directory the expression is `^%d/foo/bar(/.*)?$`.

#### How it works

The magic is the `Match` keyword, followed by two match criteria.

- `host github.com`: match only when connecting to github
- `exec "pwd | grep -qE '^%d/development/work(/.*)?$'"` match only when the current working directory
  is in `$HOME/development/work`

Explanation for the syntax of the grep expression:

- `%d` is expanded by ssh, and means "local user's home directory"
- `^...$` makes the expression exhaustive, so it only matches when you're actually in that directory, and not in some other directory that contains this path as a substring
- `(/.*)` is to make sure it matches only in this folder (and subfolders), but not e.g. in
  a folder named `work2`.

#### Testing if SSH key selection is working

After doing so, try the following:

```bash
$ cd ~/development
$ ssh git@github.com
git@github.com: Permission denied (publickey).

$ cd ~/development/private
$ ssh git@github.com
PTY allocation request failed on channel 0
Hi easimon! You've successfully authenticated, but GitHub does not provide shell access.
Connection to github.com closed.

$ cd ~/development/work
$ ssh git@github.com
PTY allocation request failed on channel 0
Hi easimon-work! You've successfully authenticated, but GitHub does not provide shell access.
Connection to github.com closed.
```

When outside any context directory, the ssh connection should fail. If it succeeds, one of your
default ssh keys (e.g. `~/.ssh/id_rsa`) is accepted by GitHub, and this spoils any attempt to switch
the key to something else in "real" context folders.

For each context directory the ssh connection should succeed, identify you by the expected
GitHub handle and then drop the connection. Check if the `Hi your-handle` matches your expectations.

Now, you're all set for cloning all your repositories into subfolder of the corresponding context
folder, e.g.

```bash
cd ~/development/work
git clone git@github.com:some-org/some-repository.git
cd some-repository
```

If it does not work: You can use `ssh -v` to debug key selection, increase the number of `v`
to increase verbosity, e.g. `-vvvvv`.

### Git User Name and E-Mail configuration

Using a similar approach to the OpenSSH config, you can also switch git user name
and e-mail based on current working directory. Like with OpenSSH, you can configure all
other git options this way, but so far I found only username and e-mail useful options
to alter.

#### TL;DR

Git allows directory-specific configuration using the following snippets:

```gitconfig
[includeIf "gitdir:/some/path"]
  path = /some/path/to/another/gitconfig
```

And the file in the `path` can then override git options for that directory.

#### Step by step

For each of the context folders, create a section like the following in
`~/.gitconfig`:

```gitconfig
[includeIf "gitdir:~/development/hobby/"]
  path = ~/development/hobby/.gitconfig
[includeIf "gitdir:~/development/work/"]
  path = ~/development/work/.gitconfig
```

This defines a gitconfig to include when inside a specific folder.
The path must point to a valid git configuration file, but its location
and name does not matter -- I just name these `.gitconfig` and put them
into the context root.

And then for each `path` create a file containing the following

```gitconfig
[user]
  name = My Full Name
  email = my-mail@domain.com
```

Now, test this by committing something (not pushing) to an arbitrary repository in each
context, and then watching `git log`. The log should display the specified name and e-mail.

You're now all set for automatic identity selection based on working directories.

## Conclusion

While this setup is more complex and tricky than I'd prefer, once you have it
running, I think it works like a charm.

## Appendix: Alternatives and their downsides

### SSH key selection using environment variables

You can set an environment variable like this

```bash
GIT_SSH_COMMAND='ssh -i ~/.ssh/work'
```

and make this toggle using [direnv](https://direnv.net/) or similar.
Introduces another new tool, so I skipped diving into this. Also, this does
most probably not work for tools like `terraform` that implement the git protocol
themselves, ignoring `git` cli options.

### SSH key selection using .gitconfig

You can also set the SSH key using path-specific `.gitconfig`s, like this:

```gitconfig
[user]
  name = My Full Name
  email = my-mail@domain.com
[core]
  sshCommand = ssh -i ~/.ssh/work
```

This actuyll works for most tools I encountered, and has been the solution of my choice a long
time. But is not evaluated by e.g. `terraform` when downloading modules, since terraform does not
seem to use the `git` cli to check things out, or at least completly ignores any `git` cli
configuration. So if your terraform modules live in a private repository, `terraform init` in
a root module refering to these private modules will not select the correct SSH key to check
them out (it will also not have a correct git user name and e-mail, but that's irrelevant for
reading repositories).

Using `ssh_config` instead is a level lower -- and more probable to be in effect for
applications using SSH. At least for terraform, it works.

### Create alternative hostnames for GitHub

You can create alternative hostnames for github.com, using CNAMEs or ssh_config:

```ssh_config
Host github.work.com
  User git
  Hostname github.com
  IdentityFile ~/.ssh/work
```

This solves the problem by creating a new one:

- When creating a DNS CNAME, it might be comfortable for most users,
  but it requires to have a domain at hand to add this DNS CNAME entry.
  It's also a bit sneaky to create CNAMEs in your domain pointing to
  hosts not under your control.
- Using the hostname redefinition in `ssh_config` swaps the authentication
  problem for a host name problem. How are others supposed to know that `github.work.com`,
  which does not exist in DNS, must be a pointer to github.com?

Also, for every connection to a previously unknown host, SSH asks for confirmation
on first connect. CICD tools / Docker images that are doing something related to
checking out code from `github.com` often have the `authorized_keys` pre-populated
for `github.com` and other prominent services, but most probably not for your alias.
