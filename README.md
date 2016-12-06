# NeoTex

This plugin compiles **latex** files **asynchronously** while edditing.
The PDF output gives a **live preview** of your document as you type.
You have the option to **highlight changes** from the previous save using latexdiff.
*This plugin is experimental and not well tested*

### live preview of a latex document
![Demo1 gif](img/demo_1.gif?raw=true)
### live preview with latexdiff
![Demo2 gif](img/demo_2.gif?raw=true)

## Installation
Install using the plugin manager you like.
For example [vim-plug](https://github.com/junegunn/vim-plug):
    ```
        Plug 'donRaphaco/NeoTex', { 'for': 'tex' }
    ```
Do `:UpdateRemotePlugins` after installing or updating!

## Usage
For live previewing your latex file open the created PDF using a PDF viewer which supports auto reloading (I recommend zathura or evince).
The PDF is created in the same folder where your latex file is stored.

## Options

| Option                            | Default   | Description                               |
| --------------------------------- | --------- | ----------------------------------------- |
| `g:neotex_enabled`                | 1         | 0 = always disabled, 1 = default off, 2 = default on |
| `g:neotex_delay`                  | 1000      | Update intervall                          |
| `g:neotex_latexdiff`              | 0         | enable latexdiff                          |
| `g:neotex_latexdiff_options`      | -         | additional options for latexdiff          |
| `g:neotex_pdflatex_add_options`   | -         | additional options for pdflatex (`-jobname=<filname>` and `-interaction=nonstopmode` is always set) |

## Commands
| Command       | Description           |
| ------------- | --------------------- |
| `:NeoTex`     | Compile current buffer (asynchronously and without writing the file) |
| `:NeoTexOn`   | Turn live compilation on (for current buffer) |
| `:NeoTexOff`  | Turn live compilation off (for current bufffer) |
