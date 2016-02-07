#!/bin/zsh

__tags_for_cache() {
    local key

    for key in ${(k)zplugs}
    do
        echo "name:$key, $zplugs[$key]"
    done \
        | awk -f "$ZPLUG_ROOT/src/share/cache.awk"
}

__load_cache() {
    local key

    $ZPLUG_USE_CACHE || return 2
    if [[ -f $_ZPLUG_CACHE_FILE ]]; then
        &>/dev/null diff -b \
            <( \
            awk -f "$ZPLUG_ROOT/src/share/read_cache.awk" \
            "$_ZPLUG_CACHE_FILE" \
            ) \
            <( \
            for key in ${(k)zplugs}; do \
                echo "name:$key, $zplugs[$key]"; \
            done \
            | awk -f "$ZPLUG_ROOT/src/share/cache.awk"
        )

        case $status in
            0)
                # same
                source "$_ZPLUG_CACHE_FILE"
                return $status
                ;;
            1)
                # differ
                ;;
            2)
                # error
                __die "zplug: cache: something wrong\n"
                ;;
        esac
    fi

    # if cache file doesn't find,
    # returns non-zero exit code
    return 1
}

__update_cache() {
    $ZPLUG_USE_CACHE || return 2
    if [[ $funcstack[2] != "__load__" ]]; then
        printf "[zplug] __update_cache: this function must be called by __load__\n" >&2
        return 2
    fi

    if [[ -f $_ZPLUG_CACHE_FILE ]]; then
        chmod a+w "$_ZPLUG_CACHE_FILE"
    fi

    {
        __put '#!/bin/zsh\n\n'
        __put '# This file was generated by zplug\n'
        __put '# *** DO NOT EDIT THIS FILE ***\n\n'
        __put '[[ $- =~ i ]] || exit\n'
        __put 'export PATH="%s:$PATH"\n' "$ZPLUG_HOME/bin"
        __put 'export ZSH=%s\n\n' "$ZPLUG_HOME/repos/$_ZPLUG_OHMYZSH"
        __put 'if $is_verbose; then\n'
        __put '  echo "Static loading..." >&2\n'
        __put 'fi\n'
        if (( $#load_plugins > 0 )); then
            __put 'source %s\n' "${(qqq)load_plugins[@]}"
        fi
        if (( $#load_fpaths > 0 )); then
            __put '\n# fpath\n'
            __put 'fpath=(\n'
            __put '%s\n' ${(u)load_fpaths}
            __put '$fpath\n'
            __put ')\n'
        fi
        __put 'compinit -C -d %s\n' "$ZPLUG_HOME/zcompdump"
        if (( $#nice_plugins > 0 )); then
            __put '\n# Loading after compinit\n'
            __put 'source %s\n' "${(qqq)nice_plugins[@]}"
        fi
        if (( $#lazy_plugins > 0 )); then
            __put '\n# Lazy loading plugins\n'
            __put 'autoload -Uz %s\n' "${(qqq)lazy_plugins[@]:t}"
        fi
        __put '\nreturn 0\n'
        __put '%s\n' "$(__tags_for_cache)"
    } >|"$_ZPLUG_CACHE_FILE"

    if [[ -f $_ZPLUG_CACHE_FILE ]]; then
        chmod a-w "$_ZPLUG_CACHE_FILE"
    fi
}
