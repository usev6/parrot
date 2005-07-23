###
# [global]

.namespace [ "Tcl" ]

.sub "&global"
  .local pmc argv 
  argv = foldup

  .local int argc 
  argc = argv

  .local pmc retval
  .local int return_type

  retval = new TclString
  retval = ""
  return_type = TCL_OK

  if argc == 0 goto badargs

  .local int call_level
  $P0 = find_global "_Tcl", "call_level"
  call_level = $P0
  
  .local int ii
  ii = 0
  .local string varname
  .local string sigil_varname

loop:
  if ii == argc goto done
  varname = argv[ii]
  sigil_varname = "$" . varname

  push_eh catch
    $P1 = find_global "Tcl", sigil_varname
    store_lex call_level, sigil_varname, $P1
  clear_eh
resume:

  inc ii
  goto loop
  
badargs:
  print "badargs\n"
  return_type = TCL_ERROR
  retval = "wrong # args: should be \"global varName ?varName ...?\""

done:
  .return(return_type,retval)

catch:
  goto resume

.end
