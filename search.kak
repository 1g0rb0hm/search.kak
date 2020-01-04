declare-option -docstring "shell command run to search for subtext in a file/directory" \
    str searchcmd 'rg -Hn --column -C3'
declare-option -docstring "name of the client in which utilities display information" \
    str toolsclient
declare-option -hidden int search_current_line 0

define-command -params .. -file-completion \
    -docstring %{search [<arguments>]: grep utility wrapper
All the optional arguments are forwarded to the grep utility} \
    search %{ evaluate-commands %sh{
     output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-search.XXXXXXXX)/fifo
     mkfifo ${output}
     if [ $# -gt 0 ]; then
         ( ${kak_opt_searchcmd} "$@" | tr -d '\r' > ${output} 2>&1 & ) > /dev/null 2>&1 < /dev/null
     else
         ( ${kak_opt_searchcmd} "${kak_selection}" | tr -d '\r' > ${output} 2>&1 & ) > /dev/null 2>&1 < /dev/null
     fi

     printf %s\\n "evaluate-commands -try-client '$kak_opt_toolsclient' %{
               edit! -fifo ${output} *search*
               set-option buffer filetype search
               set-option buffer search_current_line 0
               hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -r $(dirname ${output}) } }
           }"
}}

# # Highlight *grep* window 
# hook -group grep-highlight global WinSetOption filetype=grep %{
#   try %{ add-highlighter window/grep group }
#   add-highlighter window/grep/ regex "^--$" 0:yellow+rb
#   add-highlighter window/grep/ regex "^((?:\w:)?[^:\n]+)-(\d+)-([^\n\r]+)?" 1:rgb:606060,default 2:green 3:rgb:606060,default
#   hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/grep }
# }

hook -group search-highlight global WinSetOption filetype=search %{
    add-highlighter window/search group
    add-highlighter window/search/ regex "^((?:\w:)?[^:\n]+):(\d+):(\d+)?" 1:cyan 2:green 3:green
    add-highlighter window/search/ line %{%opt{search_current_line}} default+b
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
            execute-keys '<a-x>s^((?:\w:)?[^:]+):(\d+):(\d+)?<ret>'
            set-option buffer search_current_line %val{cursor_line}
            evaluate-commands -try-client %opt{jumpclient} -verbatim -- edit -existing %reg{1} %reg{2} %reg{3}
            try %{ focus %opt{jumpclient} }
        }
    }
}

define-command search-next-match -docstring 'Jump to the next search match' %{
    evaluate-commands -try-client %opt{jumpclient} %{
        buffer '*search*'
        # First jump to enf of buffer so that if search_current_line == 0
        # 0g<a-l> will be a no-op and we'll jump to the first result.
        # Yeah, thats ugly...
        execute-keys "ge %opt{search_current_line}g<a-l> /^[^:]+:\d+:<ret>"
        search-jump
    }
    try %{ evaluate-commands -client %opt{toolsclient} %{ execute-keys gg %opt{search_current_line}g } }
}

define-command search-previous-match -docstring 'Jump to the previous search match' %{
    evaluate-commands -try-client %opt{jumpclient} %{
        buffer '*search*'
        # See comment in grep-next-match
        execute-keys "ge %opt{search_current_line}g<a-h> <a-/>^[^:]+:\d+:<ret>"
        search-jump
    }
    try %{ evaluate-commands -client %opt{toolsclient} %{ execute-keys gg %opt{search_current_line}g } }
}
