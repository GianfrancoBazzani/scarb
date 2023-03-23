# Scarb Maintenance

## Maintainers

All Scarb maintainers are members of the **[@software-mansion/scarb-maintainers]** GitHub team.
Current project leader is **[@mkaput]**.

## Release procedure

Releasing Scarb is a semi-automated process.
It usually takes a couple of hours for me (~Marek), depending on if there are some last-minute patches to be made.
The longest part is writing release notes.

### Cut new version

In a nutshell, this is trivial: create a tag on `main` named `vX.Y.Z`.
There is a tag protection rule set up!
Make sure you create it on a green commit (CI is passing), this is not verified!
A tag should trigger a [Release] workflow which builds binaries, verifies them and drafts a GitHub release.
It usually takes about half an hour.

#### Create release branch

Sometimes `main` could be ahead with some commits that you might not want to include in this release.
It's totally fine to start a release branch in such scenarios.
The branch must be named `release/vX.Y.Z`, there's branch protection rule set up for this.
Then, cherry-pick commits that you might want to include.
After all is done, push the branch and a `vX.Y.Z` tag as usual!

As for website, don't forget to ensure that it should match latest Scarb version,
i.e. almost always be published from tags on `main`.
Release branches are allowed to be sources for website deployments,
and so they will deploy from tags in release branches.
You might need to swiftly pause the [Website Deploy] workflow to prevent publishing old website version.

### Write release notes

Upon completion, the [Release] workflow should draft a release on GitHub.
Now comes the most tedious and time-consuming part that nobody likes: writing release notes!
We take an inspiration from the awesome release notes that [Visual Studio Code][vscode-relnotes] does.

1. Open the draft release.
2. Click `Generate release notes`, we will use this information in next step.
3. Leave release title intact.
4. If this is applicable, _✅ Set as a pre-release_.
5. If this is applicable, _✅ Set as the latest release_.
6. _✅ Create a discussion for this release_.
7. Use the **[template](#template)**.
8. Don't forget to _Save draft_ frequently!

#### Template

```markdown
# Scarb X.Y.Z

Welcome to the release notes for Scarb vX.Y.Z!
This release is all about blahblah

* **Blah blah** - Why this blah is so much blah.
* **Even more blah blah** - Everything is awesome.
    * **Sometimes some sub-blah is cool** - Yeah.

## Highlight point title

Elaborate what this is about, what has changed, etc.
Be as descriptive as you can.

## Cairo version

This version of Scarb comes with Cairo [`vX.Y.Z`](https://github.com/starkware-libs/cairo/releases/tag/vX.Y.Z).

## Pull requests

<!-- Here goes output from `Generate release notes` button, without header. -->

**Full Changelog**: https://github.com/software-mansion/scarb/compare/...
```

#### Banner on Scarb website

If this is a significant release, you might consider showing a banner on the website.
To do this, take a look at the [`theme.config.tsx`](./website/theme.config.tsx) file, do necessary changes,
commit and trigger manually the [Website Deploy] workflow.

### Announce release on social media

#### Twitter

Post an announcement Tweet from your personal account, people tend to favour interacting with real humans accounts,
rather than corporate ones.

Here is example template, it's recommended to slightly change the copy, so that it won't look like robotic action:

```
Happy to announce that Scarb vX.Y.Z is live!

🔥 blahblah
🚀 even more blahblah

Go check it out: https://docs.swmansion.com/scarb/download
Release notes: https://github.com/software-mansion/scarb/releases/tag/vX.Y.Z

@swmansionxyz @StarkWareLtd
```

**Important:** The mentions are super important!
They seem to help generate more traffic.
Also post tweet link to `#crypto-mansion-marketing` and `#starkware-swm` Slack channels,
and do ensure that both Twitter accounts retweet your tweet on the same day.

#### Starknet Telegram

Post an announcement message on the _private Starknet channel where everybody is_ on Telegram.
All maintainers should be members of this group since their start.

Use similar text to one used in a Tweet, just attach Tweet link at the end, and do not mention anybody:

```
Announcing Scarb vX.Y.Z!

🔥 blahblah
🚀 even more blahblah

Download: https://docs.swmansion.com/scarb/download
Release notes: https://github.com/software-mansion/scarb/releases/tag/vX.Y.Z
Tweet: https://twitter.com/...
```

#### Starknet Discord

Post the same message as posted on the Telegram to the `#scarb` channel on Starknet's Discord.

### Close GitHub milestone for this release

1. As title says, go to the [milestone], and hit _Close_ button.
2. The go to the [Scarb project], and _Archive_ all issues assigned to this milestone.
   Currently, this is tedious manual work.

[@software-mansion/scarb-maintainers]: https://github.com/orgs/software-mansion/teams/scarb-maintainers

[@mkaput]: https://github.com/mkaput

[website deploy]: https://github.com/software-mansion/scarb/actions/workflows/website-deploy.yml

[release]: https://github.com/software-mansion/scarb/actions/workflows/release.yml

[vscode-relnotes]: https://code.visualstudio.com/updates

[milestone]: https://github.com/software-mansion/scarb/milestones

[scarb project]: https://github.com/orgs/software-mansion/projects/4