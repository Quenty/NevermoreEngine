## Nevermore-CLI

Command line interface that helps you get started with Nevermore.

## Usage

In the command line or terminal:

```bash
npm install -g @quenty/nevermore-cli
nevermore-init
```

### Testing a published version from a linked repo

`npx @quenty/nevermore-cli@<version>` **ignores the version** inside a repo that
pnpm-links the CLI: npx finds the linked copy on the path first and runs the
working tree, whatever the spec said. Nothing reports the substitution, so a
measurement taken that way is of your local build.

To test a real published version, run it somewhere with no link — a scratch
directory, or `npx --ignore-existing`.

## Design goals

1. Can initialize a new Nevermore package easily

## Build instructions

1. Build the two other helpers next to here
2. Run `npm install -g .` to install locally
