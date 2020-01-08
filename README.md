# search.kak

User friendly project wide search with context for [Kakoune][1] editor.

![showcase][2]

## Installation

### With [plug.kak](https://github.com/andreyorst/plug.kak) (recommended)

Just add this to your `kakrc`:
```kak
# -- Search: https://github.com/1g0rb0hm/search.kak
plug "1g0rb0hm/search.kak" config %{
  set-option global search_context 5 # number of context lines
}
```
Then reload Kakoune config or restart Kakoune and run `:plug-install`.

## Usage

Simply select the text you would like to search for and run `:search`.

You can then navigate from one match to the next using `n` as the search term is automatically stored in the default `/` search register.

Each match is surrounded by a configurable number of context lines (see `search_context` option).

[1]: https://github.com/mawww/kakoune
[2]: https://raw.githubusercontent.com/1g0rb0hm/search.kak/master/assets/kak-search-demo.gif
