set --local c complete tldr-on-error
set --local verbs on off enable disable status clear list blaklist
$c -f # disable file completion

for v in $verbs
    $c -n "not __fish_seen_subcommand_from $verbs" -a $v
end
