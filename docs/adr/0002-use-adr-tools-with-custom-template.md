# 2. Use adr-tools with custom template

Date: 2025-09-11

## Status

Accepted

## Context

It’s handy to use tooling to create ADRs. There are a couple of options available.

## Options

### 1. npryce’s adr-tools

These appear to be the original tools for managing tools. See
[npryce/adr-tools](https://github.com/npryce/adr-tools) on GitHub.

#### Pros

- simple, well understood
- bash scripts
- flexible enough for us (can customise homedir, templates)
- also being used by Apply

#### Cons

- unknown

### 2. Markdown Architectural Decision Records (madr)

These are a branch of npryce’s adr-tools. See
[adr/madr](https://github.com/adr/madr). They seem to have added a whole bunch
of extra stuff that I'm not sure we need, although I do like some of the ideas
in their ADR template which I want to re-use in our own template.

#### Pros

- flexible

#### Cons

- seems quite a bit more complicated (not necessarily in usage, did not get that
  far, just looking at their plethora of repos)
- lots of extra features we may not need
- JavaScript based, so more complicated than just a bunch of bash scripts

## Decision

Use npryce’s adr-tools.

## Consequences

We're more in-line with Apply. Devs will want to install `adr-tools` to be able
to work with ADRs.
