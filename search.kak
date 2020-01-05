declare-option -docstring "shell command run to search for subtext in a file/directory" \
    str searchcmd 'rg --line-number --color=never --heading -C3'
declare-option -docstring "name of the client in which utilities display information" \
    str toolsclient
declare-option -hidden int search_current_line 0
declare-option -hidden str search_current_pattern ''

declare-option -hidden int search_current_line_number 0
declare-option -hidden str search_current_line_file ''

define-command -params .. -file-completion \
  -docstring %{search [pattern]: file search wrapper
The pattern is forwarded to the grep utility} \
  search %{ evaluate-commands %sh{
     # -- OUTPUT
     output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-search.XXXXXXXX)/fifo
     mkfifo ${output}
     # -- PATTERN
     pattern=""  # EMPTY
     if [ $# -gt 0 ]; then
       pattern="$@"
     else
       pattern="${kak_selection}"
     fi
     # -- EXEC SEARCH
     ( ${kak_opt_searchcmd} "${pattern}" | tr -d '\r' > ${output} 2>&1 & ) > /dev/null 2>&1 < /dev/null
     # -- SETUP *search* BUFFER AND DISPLAY RESULT
     printf %s\\n "evaluate-commands -try-client '$kak_opt_toolsclient' %{
               edit! -fifo ${output} *search*
               set-option buffer filetype search
               set-option buffer search_current_line 0
               set-option buffer search_current_pattern '${pattern}'
               set-register '/' '${pattern}'
               hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -r $(dirname ${output}) } }
               try %{ focus '${kak_opt_toolsclient}' }
           }"
}}

hook -group search-highlight global WinSetOption filetype=search %{
  add-highlighter window/search group
  # -- MATCH FILE NAME
  add-highlighter window/search/ regex "^([^\n\d-][^\n]*)" 1:magenta+b
  # -- MATCH SEPERATOR
  add-highlighter window/search/ regex "^--[^\n]*$" 0:magenta
  # -- MATCH LINE
  add-highlighter window/search/ regex "^(\d+:)([^\n]*)$" 1:green 2:yellow
  # -- MATCH CONTEXT LINE
  add-highlighter window/search/ regex "^(\d+-)([^\n]*)$" 1:green 2:rgb:606060,default
  # -- MATCH PATTERN
  add-highlighter window/search/ dynregex '%opt{search_current_pattern}' 0:red+b
  # -- MATCH CURRENT SEARCH LINE (grey RGB value)
  add-highlighter window/search/ line %{%opt{search_current_line}} default,rgb:808080
  # --
  hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/search }
}

hook global WinSetOption filetype=search %{
  hook buffer -group search-hooks NormalKey <ret> search-jump
  hook -once -always window WinSetOption filetype=.* %{ remove-hooks buffer search-hooks }
}

declare-option -docstring "name of the client in which all source code jumps will be executed" \
    str jumpclient

define-command -hidden search-jump %{
  evaluate-commands %{ # use evaluate-commands to ensure jumps are collapsed
    try %{
      # -- REMEMBER LAST LOCATION
      set-option buffer search_current_line %val{cursor_line}
      # -- EXTRACT LINE NUMBER *and* STORE IT IN %reg{2}
      execute-keys '<a-x>s^(\d+):<ret>'
      set-option buffer search_current_line_number %reg{1}
      # -- EXTRACT FILE NAME *and* STORE IT
      execute-keys '<a-/>^([^\n\d-][^\n]*)<ret>'
      set-option buffer search_current_line_file %reg{1}
      # -- ENSURE TO RETURN TO LAST SEARCH POSITION
      execute-keys "gg %opt{search_current_line}g"
      # -- JUMP TO FILE:LINE
      evaluate-commands -try-client %opt{jumpclient} -verbatim -- edit -existing %opt{search_current_line_file} %opt{search_current_line_number}
      try %{
        # -- FOCUS ON RIGHT CLIENT
        focus %opt{jumpclient}
        # -- SELECT PATTERN
        execute-keys "/%opt{search_current_pattern}<ret>"
      }
    }
  }
}

define-command search-next-match -docstring 'Jump to the next search match' %{
  evaluate-commands -try-client %opt{jumpclient} %{
    buffer '*search*'
    # First jump to end of buffer so that if search_current_line == 0
    # 0g<a-l> will be a no-op and we'll jump to the first result.
    execute-keys "ge %opt{search_current_line}g<a-l> /^\d+:<ret>"
    search-jump
}
  try %{ evaluate-commands -client %opt{toolsclient} %{ execute-keys gg %opt{search_current_line}g } }
}

define-command search-previous-match -docstring 'Jump to the previous search match' %{
  evaluate-commands -try-client %opt{jumpclient} %{
    buffer '*search*'
    # First jump to end of buffer so that if search_current_line == 0
    # 0g<a-l> will be a no-op and we'll jump to the first result.
    execute-keys "ge %opt{search_current_line}g<a-h> <a-/>^\d+:<ret>"
    search-jump
  }
  try %{ evaluate-commands -client %opt{toolsclient} %{ execute-keys gg %opt{search_current_line}g } }
}
