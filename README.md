 # tldr-on-error.fish

[tldr](https://github.com/tldr-pages/tldr) is a great community effort to quickly document common use cases for command line tools.
This plugin aims to make it easier to use `tldr` by automatically showing the tldr page for a command when it fails.

To avoid being annoyed by repeated pages, the plugin keeps track of two blacklists:
- A global blacklist, that is populated by failed commands that are not in the tldr database.
  - If `tldr` does not find a page for the failed command, it will try to update its local cache by running `tldr --update`. If the new cache does not contain a page for the failed command, it will be added to the global blacklist.
  - This blacklist clears itself after 7 days.


- A session blacklist, that is populated by previous commands that you have been shown a tldr page for. This blacklist clears itself when you terminate your shell.

The plugin tries to be smart about when to show you a tldr page:

- If the failed command is a `function` or `alias` that you have defined, it will not show you a tldr page. As there is zero chance that tldr has a page for your custom function or alias :wink:.
- Many commands will return a non-zero status code when you call them like `<command> -h|--help | -v|--version`. This is not considered a failure by the plugin, and it will not show you a tldr page.

Some commands like `git` and `docker` have separate tldr pages for each subcommand. The plugin will try to show you specific subcommand pages when possible.

todo: add video demo

## Usage

All you need to do is install the plugin, and it will automatically start showing you tldr pages when commands fail. The plugin also comes with a function called `tldr-on-error` that you can use to manage the plugin. You can use it to enable/disable the plugin, or to clear the blacklists. See `tldr-on-error --help` for more information.


## Installation
```fish
fisher install kpbaks/tldr-on-error.fish
```
## Dependencies

The plugin expects you to use the `tldr` implementation called [tealdeer](https://dbrgn.github.io/tealdeer/). If a `tldr` command is not found in your path, a warning is printed, and the plugin will not be enabled. There exists many implementations of `tldr`, but this plugin has only been tested with `tealdeer`.
