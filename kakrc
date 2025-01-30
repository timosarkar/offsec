#set global disabled_hooks .*-indent

declare-option bool dateutil

hook global BufCreate '.*\.*' %{
  set-option buffer dateutil yes
}

hook global WinSetOption dateutil=true %{
  require-module dateutil

  # add new todo task
  map global insert <c-d> '[ ] '

  # start current task
  map window insert <c-y> '<a-;>: insert-date<ret>'
  # set '[ ] ' to '[>] '

  # finish current task
  # set '[ ] ' or '[>] ' to '[x] ', show current datetime and elapsed time
}

provide-module dateutil %🐈
  define-command insert-date %(execute-keys -draft '!date ''+%F %H:%M:%S'' | tr -d ''\n''<ret>')
🐈

# base configs
add-highlighter global/ number-lines -hlcursor
set-option global tabstop 2
set-option global indentwidth 2


# map tab to accept autocomplete
hook global InsertCompletionShow .* %{
    map window insert <tab> <c-n>
    map window insert <s-tab> <c-p>
}

# once autocomplete menu is hidden, remap tab to default
hook global InsertCompletionHide .* %{
    unmap window insert <tab> <c-n>
    unmap window insert <s-tab> <c-p>
}

# save and quit using <space> in escape mode
define-command -docstring "save and quit" x "write-all; quit"
map global normal <space> ':x<ret>'

# map ctrl+d to insert some text
map global insert <c-d> 'lorem ipsum'

# moving around words and paragraphs using ctrl
map global insert <c-left>    '<a-;>b<a-;>;'
map global insert <c-right>   '<a-;>w<a-;>;'
map global insert <c-up>      '<a-;>[p<a-;>;'
map global insert <c-down>    '<a-;>]p<a-;>;'
map global normal <c-left>    'b;'
map global normal <c-right>   'w;'
map global normal <c-up>      '[p;'
map global normal <c-down>    ']p;'

# Auto-pairing of characters
declare-option -docstring 'list of surrounding pairs' str-list auto_pairs ( ) { } [ ] '"' '"' "'" "'" ` ` “ ” ‘ ’ « » ‹ ›

# Auto-pairing of characters activates only when this expression does not fail.
# By default, it avoids non-nestable pairs (such as quotes), escaped pairs and word characters.
declare-option -docstring 'auto-pairing of characters activates only when this expression does not fail' str auto_close_trigger '<a-h><a-K>(\w["''`]|""|''''|``).\z<ret><a-k>[^\\]?\Q%opt{opening_pair}<a-!>\E\W\z<ret>'

# Internal variables ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈

# Retain inserted pairs
declare-option -hidden str opening_pair
declare-option -hidden int inserted_pairs

# Commands ─────────────────────────────────────────────────────────────────────

define-command -override enable-auto-pairs -docstring 'enable auto-pairs' %{
  remove-hooks global auto-pairs
  evaluate-commands %sh{
    set -- ${kak_opt_auto_pairs}
    while [ "$2" ]
    do
      printf 'auto-close-pair %%<%s> %%<%s>\n' "$1" "$2"
      shift 2
    done
  }
}

define-command -override disable-auto-pairs -docstring 'disable auto-pairs' %{
  remove-hooks global auto-pairs
}

# Internal commands ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈

define-command -override -hidden auto-close-pair -params 2 %{
  hook -group auto-pairs global InsertChar "\Q%arg{1}" "handle-inserted-opening-pair %%<%arg{1}> %%<%arg{2}>"
  hook -group auto-pairs global InsertDelete "\Q%arg{1}" "handle-deleted-opening-pair %%<%arg{1}> %%<%arg{2}>"
}

# Internal hooks ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈

define-command -override -hidden handle-inserted-opening-pair -params 2 %{
  try %{
    # Test whether the commands contained in the option pass.
    # If not, it will throw an exception and execution will jump to
    # the “catch” block below.
    set-option window opening_pair %arg{1}
    execute-keys -draft %opt{auto_close_trigger}

    # Action: Close pair
    execute-keys %arg{2}

    # Keep the track of inserted pairs
    increment-inserted-pairs-count

    # Move back in pair (preserve selected text):
    try %{
      execute-keys -draft '<a-k>..<ret>'
      execute-keys '<a-;>H'
    } catch %{
      execute-keys '<a-;>h'
    }

    # Add insert mappings
    map -docstring 'insert closing pair or move right in pair' window insert %arg{2} "<a-;>:insert-closing-pair-or-move-right-in-pair %%🐈%arg{2}🐈<ret>"
    map -docstring 'insert a new indented line in pair' window insert <ret> '<a-;>:insert-new-line-in-pair<ret>'
    map -docstring 'prompt a count for new indented lines in pair' window insert <c-ret> '<a-;>:prompt-insert-new-line-in-pair<ret>'

    # Enter is only available on next key.
    hook -group auto-pairs -once window InsertChar '.*' %{
      unmap window insert <ret>
      unmap window insert <c-ret>
    }

    # Clean insert mappings and remove hooks
    hook -group auto-pairs -once window WinSetOption 'inserted_pairs=0' "
      unmap window insert %%🐈%arg{2}🐈
      unmap window insert <ret>
      unmap window insert <c-ret>
      remove-hooks window auto-pairs
    "

    # Clean state when moving or leaving insert mode
    hook -group auto-pairs -once window InsertMove '.*' %{
      reset-inserted-pairs-count
    }

    hook -always -once window ModeChange 'pop:insert:normal' %{
      reset-inserted-pairs-count
    }
  }
}

# Backspace ⇒ Erases the whole bracket
define-command -override -hidden handle-deleted-opening-pair -params 2 %{
  try %{
    execute-keys -draft "<space>;<a-k>\Q%arg{2}<ret>"
    execute-keys '<del>'
    decrement-inserted-pairs-count
  }
}

# Internal mappings ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈

# {closing-pair} ⇒ Insert closing pair or move right in pair
define-command -override -hidden insert-closing-pair-or-move-right-in-pair -params 1 %{
  try %{
    execute-keys -draft "<space>;<a-k>\Q%arg{1}<ret>"
    # Move right in pair
    execute-keys '<a-;>l'
    decrement-inserted-pairs-count
  } catch %{
    # Insert character with hooks
    execute-keys -with-hooks %arg{1}
  }
}

# Enter ⇒ Insert a new indented line in pair (only for the next key)
define-command -override -hidden insert-new-line-in-pair %{
  execute-keys '<a-;>;<ret><ret><esc>KK<a-&>j<a-gt>'
  execute-keys -with-hooks A
  reset-inserted-pairs-count
}

# Control+Enter ⇒ Prompt a count for new indented lines in pair (only for the next key)
define-command -override -hidden prompt-insert-new-line-in-pair %{
  prompt count: %{
    execute-keys '<a-;>;<ret><ret><esc>KK<a-&>j<a-gt>'
    execute-keys "xHyx<a-d>%val{text}O<c-r>""<esc>"
    execute-keys -with-hooks A
    reset-inserted-pairs-count
  }
}

# ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈

# Increment and decrement inserted pairs count
define-command -override -hidden increment-inserted-pairs-count %{
  set-option -add window inserted_pairs 1
}

define-command -override -hidden decrement-inserted-pairs-count %{
  set-option -remove window inserted_pairs 1
}

define-command -override -hidden reset-inserted-pairs-count %{
  set-option window inserted_pairs 0
}

enable-auto-pairs





# Indent
# Public commands: ["set-indent", "detect-indent", "enable-detect-indent", "disable-detect-indent", "enable-auto-indent", "disable-auto-indent"]

define-command -override set-indent -params 3 -docstring 'set-indent <scope> <width> <tabs>: set indent in <scope> to <width>, use tabs if <tabs> is true' %{
  set-option %arg{1} tabstop %arg{2}
  evaluate-commands %sh{
    if [ "$3" = "true" ]; then
      echo "set-option %arg{1} indentwidth 0"
    else
      echo "set-option %arg{1} indentwidth %arg{2}"
    fi
  }
}

define-command -override detect-indent -docstring 'detect indent' %{
  try %{
    evaluate-commands -draft %{
      # Search the first indent level
      execute-keys 'gg/^\h+<ret>'

      # Tabs vs. Spaces
      # https://youtu.be/V7PLxL8jIl8
      try %{
        execute-keys '<a-k>\t<ret>'
        # Global scope
        unset-option buffer tabstop
        set-option buffer tabstop %opt{tabstop}
        set-option buffer indentwidth 0
      } catch %{
        set-option buffer tabstop %val{selection_length}
        set-option buffer indentwidth %val{selection_length}
      }
    }
  }
}

define-command -override enable-detect-indent -docstring 'enable detect indent' %{
  remove-hooks global detect-indent
  hook -group detect-indent global BufOpenFile '.*' detect-indent
  hook -group detect-indent global BufWritePost '.*' detect-indent
}

define-command -override disable-detect-indent -docstring 'disable detect indent' %{
  remove-hooks global detect-indent
  evaluate-commands -buffer '*' %{
    unset-option buffer tabstop
    unset-option buffer indentwidth
  }
}

define-command -override enable-auto-indent -docstring 'enable auto-indent' %{
  remove-hooks global auto-indent
  hook -group auto-indent global InsertChar '\n' %{
    evaluate-commands -draft -itersel %{
      # Copy previous line indent
      try %[ execute-keys -draft 'K<a-&>' ]
      # Clean previous line indent
      try %[ execute-keys -draft 'k<a-x>s^\h+$<ret>d' ]
    }
  }

  # Disable other indent hooks:
  # https://github.com/mawww/kakoune/tree/master/rc/filetype
  set-option global disabled_hooks '(?!auto)(?!detect)\K(.+)-(trim-indent|insert|indent)'

  # Mappings
  # Increase and decrease indent with Tab.
  map -docstring 'Increase indent' global insert <tab> '<a-;><a-gt>'
  map -docstring 'Decrease indent' global insert <s-tab> '<a-;><lt>'
}

define-command -override disable-auto-indent -docstring 'disable auto-indent' %{
  remove-hooks global auto-indent
  set-option global disabled_hooks ''
  unmap global insert <tab>
  unmap global insert <s-tab>
}

enable-auto-indent
enable-detect-indent
