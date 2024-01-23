set --query TLDR_PROGRAM_BLACKLIST_PATH
or set --universal TLDR_PROGRAM_BLACKLIST_PATH $__fish_user_data_dir/tldr-on-error-blacklist.txt

function _tldr-on-error_install --on-event tldr-on-error_install
    # Set universal variables, create bindings, and other initialization logic.
    # fisher install kpbaks/log.fish
    fisher install kpbaks/peopletime.fish
    test -f $TLDR_PROGRAM_BLACKLIST_PATH; or touch $TLDR_PROGRAM_BLACKLIST_PATH
end

function _tldr-on-error_update --on-event tldr-on-error_update
    # Migrate resources, print warnings, and other update logic.
end

function _tldr-on-error_uninstall --on-event tldr-on-error_uninstall
    # Erase "private" functions, variables, bindings, and other uninstall logic.
    test -f $TLDR_PROGRAM_BLACKLIST_PATH; and command rm $TLDR_PROGRAM_BLACKLIST_PATH
    functions --query __tldr_postexec; and functions --erase __tldr_postexec
end

function __tldr-on-error.fish::print::__prefix
    set --local reset (set_color normal)
    printf "[%s%s%s] " (set_color $fish_color_command) tldr-on-error.fish $reset >&2
end

function __tldr-on-error.fish::print::err
    __tldr-on-error.fish::print::__prefix
    set --local red (set_color red)
    set --local reset (set_color normal)
    printf "%serror:%s " $red $reset >&2
    printf $argv >&2
    printf "\n" >&2
end

function __tldr-on-error.fish::print::warn
    __tldr-on-error.fish::print::__prefix
    set --local yellow (set_color yellow)
    set --local reset (set_color normal)
    printf "%swarn:%s " $yellow $reset >&2
    printf $argv >&2
    printf "\n" >&2
end

function __tldr-on-error.fish::print::info
    __tldr-on-error.fish::print::__prefix
    set --local cyan (set_color cyan)
    set --local reset (set_color normal)
    printf "%sinfo:%s " $cyan $reset >&2
    printf $argv >&2
    printf "\n" >&2
end

function __tldr-on-error.fish::print::suggest
    __tldr-on-error.fish::print::__prefix
    set --local blue (set_color blue)
    set --local reset (set_color normal)
    printf "%ssuggestion:%s " $blue $reset >&2
    printf $argv >&2
    printf "\n" >&2
end

status is-interactive; or return

if not command --query tldr
    __tldr-on-error.fish::print::error "Executable 'tldr' was not found in \$PATH, no hooks created"
    set --local install_commands
    if command --query nix
        set --append install_commands "nix profile install nigpkgs#tealdeer"
    else if command --query nix-env
        set --append install_commands "nix-env -iA nixpkgs.tealdeer"
    else if command --query cargo
        set --append install_commands "cargo install tealdeer"
    end

    __tldr-on-error.fish::print::info "For ways to install 'tldr' see https://dbrgn.github.io/tealdeer/installing.html"

    if test (count $install_commands) -gt 0
        __tldr-on-error.fish::print::suggest "Looking at your \$PATH, the following commands should work:"
        for command in $install_commands
            printf " - %s\n" (printf (echo $command | fish_indent --ansi))
        end
    end

    return 0
end

# Setup universal variables
set --query TLDR_PROGRAM_BLACKLIST_TIMEOUT
or set --universal TLDR_PROGRAM_BLACKLIST_TIMEOUT (math "60 * 60 * 24 * 7") # 7 days
set --query TLDR_PROGRAM_BLACKLIST_CREATION_TIMESTAMP
or set --universal TLDR_PROGRAM_BLACKLIST_CREATION_TIMESTAMP (date +%s)

# Clear the blacklist if it has expired
set --local now (date +%s)
set --local dt (math "$now - $TLDR_PROGRAM_BLACKLIST_CREATION_TIMESTAMP")
if test $dt -ge $TLDR_PROGRAM_BLACKLIST_TIMEOUT
    test -f $TLDR_PROGRAM_BLACKLIST_PATH; and command rm $TLDR_PROGRAM_BLACKLIST_PATH
    touch $TLDR_PROGRAM_BLACKLIST_PATH
    set TLDR_PROGRAM_BLACKLIST_CREATION_TIMESTAMP (date +%s)
    __tldr-on-error.fish::print::info "clearing tldr program blacklist"
end

function tldr-on-error
    set --local options (fish_opt --short=h --long=help)
    if not argparse $options -- $argv
        return 1
    end

    set --local reset (set_color normal)
    set --local yellow (set_color yellow)
    set --local green (set_color green)
    set --local blue (set_color blue)

    if set --query _flag_help
        printf "%sManipulate tldr-on-error.fish%s\n" (set_color --bold) $reset
        printf "\n"
        printf "%sUsage:%s %s%s%s [options] [verb]\n" $yellow $reset $blue (status current-command) $reset
        printf "\n"
        printf "%sVerbs:%s\n" $yellow $reset
        printf "\t%son | enable%s\n" $green $reset
        printf "\t%soff | disable%s\n" $green $reset
        printf "\t%sstatus%s\n" $green $reset
        printf "\t%sclear%s\n" $green $reset
        printf "\t%slist | blacklist%s\n" $green $reset
        printf "\n"
        printf "%sOptions:%s\n" $yellow $reset
        printf "\t%s-h%s, %s--help%s Show this help message and exit\n" $green $reset $green $reset

        return 0
    end

    set --local argc (count $argv)
    test $argc -eq 0; and tldr-on-error --help; and return 1

    set --local verb $argv[1]
    # TODO: <kpbaks 2023-09-15 22:31:59> add completions
    switch $verb
        case on enable
            source (status current-filename)
        case off disable
            functions --erase __tldr_postexec
        case status
            set --local state (functions --query __tldr_postexec; and echo enabled; or echo disabled)
            set --local color (test $state = enabled; and echo green; or echo red)
            __tldr-on-error.fish::print::info (printf "tldr-on-error.fish is %s%s%s\n" (set_color $color) $state $reset)
        case clear
            test -f $TLDR_PROGRAM_BLACKLIST_PATH; and command rm $TLDR_PROGRAM_BLACKLIST_PATH
            touch $TLDR_PROGRAM_BLACKLIST_PATH
            set TLDR_PROGRAM_BLACKLIST_CREATION_TIMESTAMP (date +%s)
            __tldr-on-error.fish::print::info "clearing tldr program blacklist"
        case list blacklist
            if test -f $TLDR_PROGRAM_BLACKLIST_PATH
                cat $TLDR_PROGRAM_BLACKLIST_PATH | fish_indent --ansi
            else
                __tldr-on-error.fish::print::info "the tldr blacklist cache is empty"
            end
        case "*"
            set --local valid_verbs on enable off disable clear list blacklist
            __tldr-on-error.fish::print::error "invalid verb: $verb"
            printf "- %s\n" $valid_verbs
            return 1
    end
end

function __tldr_postexec --on-event fish_postexec
    # TODO: <kpbaks 2023-09-16 10:54:14> handle $pipestatus
    contains $status 0 127; and return # 127 is the status code returned by fish when a command is not found

    block --local # tldr --update might fail

    # Some programs will return non-zero status codes even when they are
    # invoked with { -h | --help } or { -v | --version }
    # This does not indicate an errornous use of the program, so we ignore it.
    for arg in $argv
        if contains -- $arg -h --help -v --version
            return
        end
    end

    # NOTE: handle case where the first tokens are temporary environment variables
    # 	 e.g. `FOO=bar tldr foo`
    set --local tokens (string split " " $argv)
    set --local ephemeral_environment_variables
    set --local program
    set --local args
    for token in $tokens
        if string match --quiet --regex "\w+=\w+" -- $token
            set --append ephemeral_environment_variables $token
        else if test -z $program
            set program $token
        else
            set --append args $token
        end
    end

    # echo "program: $program"
    # echo "ephemeral_environment_variables: $ephemeral_environment_variables"
    # echo "tokens: $tokens"
    # echo "args: $args"

    # TODO: <kpbaks 2023-09-16 10:49:02> test if program is a script file with an extension

    # `tldr` will not have pages for fish functions, builtins
    if builtin --query $program; or functions --query $program
        # Some functions are wrappers around a program, .e.g. changing which flags are set as default
        # Think of aliases like `alias ls="ls --color=auto"`
        # If there is a program with the same name as the function, we
        # want to show the tldr page for the program.
        command --query $program; or return
    end

    set --local programs_where_tldr_has_a_dedicated_page_for_some_of_its_subcommands \
        git \
        docker \
        podman \
        cargo

    for p in $programs_where_tldr_has_a_dedicated_page_for_some_of_its_subcommands
        if test $program = $p
            set program "$program $args[1]"
            break
        end
    end

    set --query previous_tldr_checks_in_this_shell_session
    or set --global previous_tldr_checks_in_this_shell_session

    # If the program has been checked before in this shell session, do not show the tldr page
    for p in $previous_tldr_checks_in_this_shell_session
        if test $program = $p
            __tldr-on-error.fish::print::info "already checked $program in this shell session: $fish_pid"
            return
        end
    end

    # If the program is in the blacklist, do not show the tldr page
    # NOTE: Repeated tldrs for the same errornous command is annoying.
    #       We should only show the tldr page once for each errornous command.
    #       We can do this by storing the last errornous command in a variable,
    #       and comparing it to the current command before showing the tldr page.
    contains -- "$program" (cat $TLDR_PROGRAM_BLACKLIST_PATH); and return

    set --local tldr_command (echo "tldr $program" | fish_indent --ansi)
    set --local program_syntax_highlighted (echo $program | fish_indent --ansi)
    __tldr-on-error.fish::print::info "attempting to run $tldr_command..."

    # echo "program: $(string split " " "$program")"
    if not tldr (string split " " "$program") 2>/dev/null
        __tldr-on-error.fish::print::warn "tldr information about $program_syntax_highlighted""was not found"
        __tldr-on-error.fish::print::info "trying to update tldr cache ..."
        tldr --update 2>/dev/null
        __tldr-on-error.fish::print::info "cache update complete"
        __tldr-on-error.fish::print::info "attempting to run $tldr_command""again ..."
        if not tldr (string split " " "$program") 2>/dev/null
            __tldr-on-error.fish::print::warn "tldr information about $program_syntax_highlighted""was not found"
            __tldr-on-error.fish::print::info "updating tldr cache did not help. $program_syntax_highlighted""will be added to the the blacklist"
            echo $program >>$TLDR_PROGRAM_BLACKLIST_PATH
            # __tldr-on-error.fish::print::info "the tldr blacklist cache currently contains $(set_color cyan)$(count < $TLDR_PROGRAM_BLACKLIST_PATH)$(set_color normal) entries:" (cat $TLDR_PROGRAM_BLACKLIST_PATH)
            __tldr-on-error.fish::print::info "the tldr blacklist cache currently contains $(set_color cyan)$(count < $TLDR_PROGRAM_BLACKLIST_PATH)$(set_color normal) entries:"
            set --local idx 1
            cat $TLDR_PROGRAM_BLACKLIST_PATH | while read line
                # printf " - %d) %s%s\n" $idx (printf (echo $line | fish_indent --ansi)) (set_color normal)
                printf " - %s%s\n" (printf (echo $line | fish_indent --ansi)) (set_color normal)
                set idx (math "$idx + 1")
            end
            set --local now (date +%s)
            set --local seconds_remaining_to_blacklist_clear (math "$TLDR_PROGRAM_BLACKLIST_TIMEOUT - ($now - $TLDR_PROGRAM_BLACKLIST_CREATION_TIMESTAMP)")
            set --local t (peopletime (math "$seconds_remaining_to_blacklist_clear * 1000")) # peopletime expects milliseconds
            __tldr-on-error.fish::print::info "the blacklist will be cleared in $(set_color blue)$t$(set_color normal)"
            return
        end
    end

    set --append previous_tldr_checks_in_this_shell_session $program
end
