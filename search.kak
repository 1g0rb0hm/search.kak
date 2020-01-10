declare-option -docstring "number of context lines before and after matching line" \
    int search_context 3
declare-option -docstring "shell command run to search for subtext in a file/directory" \
    str searchcmd 'rg --line-number --color=never --heading'
declare-option -docstring "name of the client in which utilities display information" \
    str toolsclient
declare-option -docstring "name of the client in which all source code jumps will be executed" \
    str jumpclient

# -----------------------------------------------------------------------------

declare-option -hidden int search_current_line 0
declare-option -hidden str search_current_pattern ''

declare-option -hidden int search_current_line_number 0
declare-option -hidden str search_current_line_file ''

# -----------------------------------------------------------------------------

# -- Face used for matched file name
set-face global search_face_match_file_name magenta,default+b
# -- Face used for matched separator
set-face global search_face_match_separator magenta,default+b
# -- Face used for matched context
set-face global search_face_match_context rgb:606060,default
# -- Face used for matched line
set-face global search_face_match_line yellow,default
# -- Face used for matched line number
set-face global search_face_match_line_number green,default
# -- Face used for matched pattern
set-face global search_face_match_pattern red,default+b
# -- Face used for currently active search line
set-face global search_face_match_active_line default,rgb:808080

# -- Highlighters for *search* window
hook -group search-highlight global WinSetOption filetype=search %{
  add-highlighter window/search group
  # -- MATCH FILE NAME
  add-highlighter window/search/ regex "^([^\n\d-][^\n]*)" 1:search_face_match_file_name
  # -- MATCH SEPERATOR
  add-highlighter window/search/ regex "^--[^\n]*$" 0:search_face_match_separator
  # -- MATCH LINE
  add-highlighter window/search/ regex "^(\d+:)([^\n]*)$" 1:search_face_match_line_number 2:search_face_match_line
  # -- MATCH CONTEXT LINE
  add-highlighter window/search/ regex "^(\d+-)([^\n]*)$" 1:search_face_match_line_number 2:search_face_match_context
  # -- MATCH PATTERN
  add-highlighter window/search/ dynregex '%opt{search_current_pattern}' 0:search_face_match_pattern
  # -- MATCH CURRENT SEARCH LINE (grey RGB value)
  add-highlighter window/search/ line %{%opt{search_current_line}} search_face_match_active_line
  # --
  hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/search }
}

# -----------------------------------------------------------------------------

# -- Command: search
define-command -params ..1 \
  -docstring %{search [<pattern>]: recursively search current directory for pattern
If no <pattern> is specified the current selection is used.} \
  search %{ evaluate-commands -try-client %opt{toolsclient} %{
    # -- Search OUTPUT stored in %reg{o}
    set-register o %sh{ 
      output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-search.XXXXXXXX)/fifo
      mkfifo $output
      printf "%s" "$output"
   }
   # -- Search PATTERN stored in %reg{p}
   set-register p %sh{
     if [ $# -gt 0 ]; then
       printf "%s" "$@"
     else
       printf "%s" "${kak_selection}"
     fi
   }
   # -- Execute SEARCH
   nop %sh{
     ( ${kak_opt_searchcmd} -C${kak_opt_search_context} "${kak_reg_p}" | tr -d '\r' > ${kak_reg_o} 2>&1 & ) > /dev/null 2>&1 < /dev/null
   }
   # -- Setup and populate *search* buffer
   edit! -fifo %reg{o} *search*
   set-option buffer filetype search
   set-option buffer search_current_line 0
   set-option buffer search_current_pattern "%reg{p}"
   set-register '/' "%reg{p}"
   hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -r $(dirname ${kak_reg_o}) } }
   try %{ focus %opt{toolsclient} }
}}

hook global WinSetOption filetype=search %{
  hook buffer -group search-hooks NormalKey <ret> search-jump
  hook -once -always window WinSetOption filetype=.* %{ remove-hooks buffer search-hooks }
}

# -- Command: search-jump
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
