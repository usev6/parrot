=head1 interpret.imc

Given a pre-parsed chunk of Tcl, interpret it.

=cut

.namespace [ "_Tcl" ]

.sub __interpret
  .param pmc commands

  # our running return value, type
  .local int return_type
  return_type = TCL_OK
  .local pmc retval

  # Which command are we processing?
  .local int command_num,num_commands
  command_num = -1
  num_commands = commands
  .local pmc command
  .local string proc,sigil_proc
  .local pmc args,my_cmd,parsed_body,argument_list

end_scope:
  inc command_num
  if command_num == num_commands goto done
  if return_type != TCL_OK goto done
  command = commands[command_num] 

  # this should stringify the tclword object, which performs
  # all necessary substitutions. 
  $P0 = command[0]
  (return_type,retval) = $P0.__get_pmc()

  if return_type != TCL_OK goto done
  proc = retval 
  sigil_proc = "&" . proc

  .local int num_args,arg_num
  num_args = command
  arg_num = 1
  
  # The subs we're calling expect flattened args,
  #  as passed with the ":flag" arg adverb.

  .local string caller_sub_text

  push_eh no_command
    my_cmd = find_global "Tcl", sigil_proc
  clear_eh
  # we can't delete commands, so we store deleted commands
  # as null PMCs
  isnull my_cmd, no_command

got_command:
  .local pmc folded_args
  folded_args = new TclList
  .local pmc current_word

loop:
  if arg_num == num_args goto loop_done
  current_word = command[arg_num]
  (return_type,retval) = current_word.__get_pmc()
  if return_type != TCL_OK goto done

  push folded_args, retval
  inc arg_num
  goto loop

loop_done: 
  (return_type,retval) = my_cmd(folded_args :flat)
  goto end_scope

no_command:
  $P1 = find_global "Tcl", "$tcl_interactive"
  unless $P1 goto no_command_non_interactive

  # XXX Should probably make sure this wasn't redefined on us.
  my_cmd = find_global "Tcl", "&unknown"
  
  # Add the command into the unknown handler, and fix our bookkeeping
  unshift command, proc
  inc num_args

  goto got_command

no_command_non_interactive:
  return_type = TCL_ERROR
  $S0 = "invalid command name \""
  $S0 .= proc
  $S0 .= "\""
  retval = $S0

done:
  .return(return_type,retval)
.end
