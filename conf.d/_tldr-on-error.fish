set --query TLDR_PROGRAM_BLACKLIST_PATH
or set --universal TLDR_PROGRAM_BLACKLIST_PATH $__fish_user_data_dir/tldr-on-error-blacklist.txt

function _tldr-on-error_install --on-event tldr-on-error_install
    # Set universal variables, create bindings, and other initialization logic.
    fisher install kpbaks/log.fish
    fisher install kpbaks/peopletime.fish
    test -f $TLDR_PROGRAM_BLACKLIST_PATH; or touch $TLDR_PROGRAM_BLACKLIST_PATH
end

function _tldr-on-error_update --on-event tldr-on-error_update
    # Migrate resources, print warnings, and other update logic.
end

function _tldr-on-error_uninstall --on-event tldr-on-error_uninstall
    # Erase "private" functions, variables, bindings, and other uninstall logic.
    test -f $TLDR_PROGRAM_BLACKLIST_PATH; and rm $TLDR_PROGRAM_BLACKLIST_PATH
    functions --query __tldr_postexec; and functions --erase __tldr_postexec
end

function __tldr-on-error.fish::print::__prefix
    set --local reset (set_color normal)
    printf "[%s%s%s] " (set_color $fish_color_command) tldr-on-error $reset >&2
end

function __tldr-on-error.fish::print::err
    __tldr-on-error.fish::print::__prefix
    set --local red (set_color red)
    set --local reset (set_color normal)
    printf "%serror:%s " $red $reset >&2
    printf $argv >&2
end

function __tldr-on-error.fish::print::warn
    __tldr-on-error.fish::print::__prefix
    set --local yellow (set_color yellow)
    set --local reset (set_color normal)
    printf "%swarn:%s  " $yellow $reset >&2
    printf $argv >&2
end

function __tldr-on-error.fish::print::info
    __tldr-on-error.fish::print::__prefix
    set --local cyan (set_color cyan)
    set --local reset (set_color normal)
    printf "%sinfo:%s  " $cyan $reset >&2
    printf $argv >&2
end

function __tldr-on-error.fish::print::suggest
    __tldr-on-error.fish::print::__prefix
    set --local blue (set_color blue)
    set --local reset (set_color normal)
    printf "%ssuggestion:%s " $blue $reset >&2
    printf $argv >&2
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
    test -f $TLDR_PROGRAM_BLACKLIST_PATH; and rm $TLDR_PROGRAM_BLACKLIST_PATH
    touch $TLDR_PROGRAM_BLACKLIST_PATH
    set TLDR_PROGRAM_BLACKLIST_CREATION_TIMESTAMP (date +%s)
    log info "clearing tldr program blacklist"
end

function tldr-on-error
    set --local options (fish_opt --short=h --long=help)
    if not argparse $options -- $argv
        return 1
    end

    if set --query _flag_help
        set --local usage "$(set_color --bold)Manipulate tldr-on-error.fish$(set_color normal)

        $(set_color yellow)Usage:$(set_color normal) $(set_color blue)$(status current-command)$(set_color normal) [options]

        $(set_color yellow)Arguments:$(set_color normal)

        $(set_color yellow)Options:$(set_color normal)
        $(set_color green)-h$(set_color normal), $(set_color green)--help$(set_color normal) Show this help message and exit"

        echo $usage
        return 0
    end

    set --local argc (count $argv)
    test $argc -eq 0; and tldr-on-error --help; and return 1

    set --local verb $argv[1]
    switch $verb
        case on enable
            source (status current-filename)
        case off disable
            functions --erase __tldr_postexec
        case status
            functions --query __tldr_postexec; and echo enabled; or echo disabled
        case clear
            test -f $TLDR_PROGRAM_BLACKLIST_PATH; and rm $TLDR_PROGRAM_BLACKLIST_PATH
            touch $TLDR_PROGRAM_BLACKLIST_PATH
            set TLDR_PROGRAM_BLACKLIST_CREATION_TIMESTAMP (date +%s)
        case list blacklist
            test -f $TLDR_PROGRAM_BLACKLIST_PATH; and cat $TLDR_PROGRAM_BLACKLIST_PATH; or echo "blacklist is empty"
        case "*"
            set --local valid_verbs on enable off disable clear list blacklist
            echo "invalid verb: $verb"
            printf "- %s\n" $valid_verbs
            return 1
    end
end

function __tldr_postexec --on-event fish_postexec
    if contains $status 0 127 # 127 is the status code returned by fish when a command is not found
        return
    end

    block --local # tldr --update might fail

    # Some programs will return non-zero status codes even when they are
    # invoked with { -h | --help } or { -v | --version }
    # This does not indicate an errornous use of the program, so we ignore it.
    for arg in $argv
        if contains -- $arg -h --help -v --version
            return
        end
    end

    set -f program (string split " " $argv)[1]

    # `tldr` will not have pages for fish functions, builtins
    if builtin --query $program; or functions --query $program
        # Some functions are wrappers around a program, .e.g. changing which flags are set as default
        # Think of aliases like `alias ls="ls --color=auto"`
        # If there is a program with the same name as the function, we
        # want to show the tldr page for the program.
        if not command --query $program
            return
        end
    end

    set --local programs_where_tldr_has_a_dedicated_page_for_some_of_its_subcommands \
        git \
        docker \
        podman \
        cargo

    # tldr has pages for { git, docker } subcommands, so if the command is { git, docker } include the subcommand
    # in $program
    for p in $programs_where_tldr_has_a_dedicated_page_for_some_of_its_subcommands
        if test $program = $p
            set program (string split " " $argv)[..2]
            break
        end
    end

    # If the program is in the blacklist, do not show the tldr page
    # NOTE: repeated tldrs for the same errornous command should is annoying
    #       we should only show the tldr page once for each errornous command
    #       we can do this by storing the last errornous command in a variable
    #       and comparing it to the current command before showing the tldr page
    #       this will require some refactoring of the code below
    contains -- "$program" (cat $TLDR_PROGRAM_BLACKLIST_PATH); and return

    set --local cmd (echo "tldr $program" | fish_indent --ansi)
    log info "attempting to run $cmd..."

    # TODO: print a message explaining why tldr is run<01-09-22, kpbs5 kristoffer.pbs@tuta.io>
    if not tldr $program 2>/dev/null
        log warn "tldr information about $program was not found"
        log info "trying to update tldr cache ..."
        tldr --update 2>/dev/null
        log info "cache update complete"
        log info "attempting to run $cmd""again ..."
        if not tldr $program 2>/dev/null
            log warn "tldr information about `$program` was not found"
            log info "updating tldr cache did not help. `$program` will be added to the the blacklist"
            echo $program >>$TLDR_PROGRAM_BLACKLIST_PATH
            log info "the tldr blacklist cache currently contains $(set_color cyan)$(count < $TLDR_PROGRAM_BLACKLIST_PATH)$(set_color normal) entries:" (cat $TLDR_PROGRAM_BLACKLIST_PATH)
            set --local now (date +%s)
            set --local seconds_remaining_to_blacklist_clear (math "$TLDR_PROGRAM_BLACKLIST_TIMEOUT - ($now - $TLDR_PROGRAM_BLACKLIST_CREATION_TIMESTAMP)")
            set --local t (peopletime (math "$seconds_remaining_to_blacklist_clear * 1000"))
            log info "the blacklist will be cleared in $(set_color blue)$t$(set_color normal)"
        end
    end
end
