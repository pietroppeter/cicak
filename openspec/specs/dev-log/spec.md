# dev-log Specification

## Purpose
The dev log: dated nimib posts in `docs/blog`, an index page, and the theme they share
(`docs/theme.nim`, the nanuq theme with a green palette). It is published with GitHub
Pages.

## Requirements

### Requirement: Index of posts
The site root SHALL be an index page with a table of every rendered post in `docs/blog`,
newest first, one row per post with its date, title (linking to the post) and one-line summary. Adding a post
SHALL NOT require editing the index.

#### Scenario: New post
- **WHEN** a post `docs/blog/x.nim` writing `2026-11-02-x.html` is added and CI renders the site
- **THEN** the index lists it first, dated 2 November 2026, with its title and summary

#### Scenario: Post without a summary
- **WHEN** a post does not set a summary
- **THEN** the index still lists it, with date and title only

### Requirement: Navigation
Every page SHALL link to the GitHub repository at the top, and every post SHALL link
back to the index.

#### Scenario: Reader on a post
- **WHEN** a reader opens a post from a search result
- **THEN** the top of the page links to the dev log index and to the repository

### Requirement: Dated post files
Each post SHALL render to a file in `docs/blog` named `YYYY-MM-DD-<slug>.html`, and its
URL SHALL stay the same once published.

#### Scenario: Existing links
- **WHEN** a post is edited after publishing
- **THEN** its URL under `blog/` does not change

### Requirement: Results come from running code
A post that reports the behaviour of an experiment SHALL run that experiment when the
post is rendered and show its real output. If an experiment fails, rendering the post
SHALL fail, so a broken experiment never publishes.

#### Scenario: Hot code reloading proof of concept
- **WHEN** `docs/blog/hcr_poc.nim` is rendered
- **THEN** it runs `experiments/hcr-cells/run.nim` and `experiments/ic-chain/run.nim` and shows their output

#### Scenario: Broken experiment
- **WHEN** an experiment exits with an error or its host process hangs
- **THEN** the docs job fails instead of publishing the error as output
