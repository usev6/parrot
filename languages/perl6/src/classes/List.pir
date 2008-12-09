## $Id$

=head1 NAME

src/classes/List.pir - Perl 6 List class and related functions

=cut

.namespace []
.sub '' :anon :load :init
    .local pmc p6meta, listproto
    p6meta = get_hll_global ['Perl6Object'], '$!P6META'
    listproto = p6meta.'new_class'('List', 'parent'=>'ResizablePMCArray Any')
    $P0 = get_hll_global 'Positional'
    p6meta.'add_role'($P0, 'to'=>listproto)
    p6meta.'register'('ResizablePMCArray', 'parent'=>listproto, 'protoobject'=>listproto)

    $P0 = get_hll_namespace ['List']
    '!EXPORT'('first grep keys kv map pairs reduce values', $P0)
.end

=head2 Methods

=over

=item item

A List in item context becomes an Array.

=cut

.namespace ['List']
.sub 'item' :method
    .tailcall self.'Array'()
.end

=item list

A List in list context returns itself.

=cut

.namespace ['List']
.sub 'list' :method
    .return (self)
.end

.namespace []
.sub 'list'
    .param pmc values          :slurpy
    .tailcall values.'!flatten'()
.end

=back

=head2 Coercion methods

=over

=item Iterator

=cut

.namespace ['List']
.sub 'Iterator' :method
    self.'!flatten'()
    $P0 = new 'Iterator', self
    .return ($P0)
.end


=item Scalar

A list in Scalar context becomes an Array ObjectRef.

=cut

.sub 'Scalar' :method
    $P0 = self.'Array'()
    $P0 = new 'ObjectRef', $P0
    .return ($P0)
.end

# FIXME:  :vtable('get_string') is wrong here.
.sub 'Str' :method :vtable('get_string')
    self.'!flatten'()
    $S0 = join ' ', self
    .return ($S0)
.end

=item ResizablePMCArray.list

This version of list morphs a ResizablePMCArray into a List.

=cut

.namespace ['ResizablePMCArray']
.sub 'list' :method
    ##  this code morphs a ResizablePMCArray into a List
    ##  without causing a clone of any of the elements
    $P0 = new 'ResizablePMCArray'
    splice $P0, self, 0, 0
    $P1 = new 'List'
    copy self, $P1
    splice self, $P0, 0, 0
    .return (self)
.end


=item hash()

Return the List invocant as a Hash.

=cut

.namespace ['List']
.sub 'hash' :method
    .local pmc result, iter
    result = new 'Perl6Hash'
    iter = self.'iterator'()
  iter_loop:
    unless iter goto iter_end
    .local pmc elem, key, value
    elem = shift iter
    $I0 = does elem, 'hash'
    if $I0 goto iter_hash
    $I0 = isa elem, 'Perl6Pair'
    if $I0 goto iter_pair
    unless iter goto err_odd_list
    value = shift iter
    value = clone value
    result[elem] = value
    goto iter_loop
  iter_hash:
    .local pmc hashiter
    hashiter = elem.'keys'()
  hashiter_loop:
    unless hashiter goto hashiter_end
    $S0 = shift hashiter
    value = elem[$S0]
    result[$S0] = value
    goto hashiter_loop
  hashiter_end:
    goto iter_loop
  iter_pair:
    key = elem.'key'()
    value = elem.'value'()
    result[key] = value
    goto iter_loop
  iter_end:
    .return (result)

  err_odd_list:
    die "Odd number of elements found where hash expected"
.end


=back

=head2 Methods

=over

=item elems()

Return the number of elements in the list.

=cut

.sub 'elems' :method :multi('ResizablePMCArray') :vtable('get_number')
    self.'!flatten'()
    $I0 = elements self
    .return ($I0)
.end

=item perl()

Returns a Perl representation of a List.

=cut

.sub 'perl' :method
    .local string result
    result = '['

    .local pmc iter
    iter = self.'iterator'()
    unless iter goto iter_done
  iter_loop:
    $P1 = shift iter
    $S1 = $P1.'perl'()
    result .= $S1
    unless iter goto iter_done
    result .= ', '
    goto iter_loop
  iter_done:
    result .= ']'
    .return (result)
.end


=back

=head2 Private methods

=over 4

=item !flatten()

Flatten the invocant, as in list context.  This doesn't necessarily
make the list eager, it just brings any nested Lists to the top
layer.  It will likely change substantially when we have lazy lists.

=cut

.sub '!flatten' :method
    .param int size            :optional
    .param int has_size        :opt_flag

    ##  we use the 'elements' opcode here because we want the true length
    .local int len, i
    len = elements self
    i = 0
  flat_loop:
    if i >= len goto flat_end
    unless has_size goto flat_loop_1
    if i >= size goto flat_end
  flat_loop_1:
    .local pmc elem
    elem = self[i]
    $I0 = defined elem
    unless $I0 goto flat_next
    $I0 = isa elem, 'Perl6Scalar'
    unless $I0 goto no_deref
    elem = deref elem
  no_deref:
    $I0 = isa elem, 'ObjectRef'
    if $I0 goto flat_next
    $I0 = isa elem, 'Range'
    unless $I0 goto not_range
    elem = elem.'list'()
  not_range:
    $I0 = does elem, 'array'
    unless $I0 goto flat_next
    splice self, elem, i, 1
    len = elements self
    goto flat_loop
  flat_next:
    inc i
    goto flat_loop
  flat_end:
    $I0 = isa self, 'List'
    if $I0 goto end
    self.'list'()
  end:
    .return (self)
.end



=item first(...)

=cut

.sub 'first' :method :multi('ResizablePMCArray', 'Sub')
    .param pmc test
    .local pmc retv
    .local pmc iter
    .local pmc block_res
    .local pmc block_arg

    iter = self.'iterator'()
  loop:
    unless iter goto nomatch
    block_arg = shift iter
    block_res = test(block_arg)
    if block_res goto matched
    goto loop

  matched:
    retv = block_arg
    goto done

  nomatch:
    retv = '!FAIL'('Undefined value - first list match of no matches')

  done:
    .return(retv)
.end


.sub 'first' :multi('Sub')
    .param pmc test
    .param pmc values :slurpy

    .tailcall values.'first'(test)
.end

=item fmt

 our Str multi List::fmt ( Str $format, $separator = ' ' )

Returns the invocant list formatted by an implicit call to C<sprintf> on each
of the elements, then joined with spaces or an explicitly given separator.

=cut

.sub 'fmt' :method :multi('ResizablePMCArray')
    .param pmc format
    .param string sep          :optional
    .param int has_sep         :opt_flag

    .local pmc res
    .local pmc iter
    .local pmc retv
    .local pmc elem
    .local pmc elemres

    if has_sep goto have_sep
    sep = ' '
  have_sep:
    res = new 'List'
    iter = self.'iterator'()
  elem_loop:
    unless iter goto done

  invoke:
    elem = shift iter
    elemres = 'sprintf'(format, elem)
    push res, elemres
    goto elem_loop

  done:
    retv = 'join'(sep, res)
    .return(retv)
.end

=item grep(...)

=cut

.sub 'grep' :method :multi('ResizablePMCArray', 'Sub')
    .param pmc test
    .local pmc retv
    .local pmc iter
    .local pmc block_res
    .local pmc block_arg

    retv = new 'List'
    iter = self.'iterator'()
  loop:
    unless iter goto done
    block_arg = shift iter
    block_res = test(block_arg)

    unless block_res goto loop
    retv.'push'(block_arg)
    goto loop

  done:
    .return(retv)
.end

.sub 'grep' :multi('Sub')
    .param pmc test
    .param pmc values          :slurpy
    .tailcall values.'grep'(test)
.end


=item iterator()

Returns an iterator for the list.

=cut

.sub 'iterator' :method
    self.'!flatten'()
    $P0 = iter self
    .return ($P0)
.end


=item keys()

Returns a List containing the keys of the invocant.

=cut

.sub 'keys' :method :multi(ResizablePMCArray)
    $I0 = self.'elems'()
    dec $I0
    $P0 = 'infix:..'(0, $I0)
    .tailcall $P0.'list'()
.end

.sub 'keys' :multi()
    .param pmc values          :slurpy
    .tailcall values.'keys'()
.end


=item kv()

Return items in invocant as 2-element (index, value) lists.

=cut

.sub 'kv' :method :multi(ResizablePMCArray)
    .local pmc result, iter
    .local int i

    result = new 'List'
    iter = self.'iterator'()
    i = 0
  iter_loop:
    unless iter goto iter_end
    $P0 = shift iter
    push result, i
    push result, $P0
    inc i
    goto iter_loop
  iter_end:
    .return (result)
.end

.sub 'kv' :multi()
    .param pmc values          :slurpy
    .tailcall values.'kv'()
.end


=item map()

Map.

=cut

.sub 'map' :method :multi('ResizablePMCArray', 'Sub')
    .param pmc expression
    .local pmc res, elem, block, mapres, iter, args
    .local int i, arity

    arity = expression.'arity'()
    if arity > 0 goto body
    arity = 1
  body:
    res = new 'List'
    iter = self.'iterator'()
  map_loop:
    unless iter goto done

    # Creates arguments for closure
    args = new 'ResizablePMCArray'

    i = 0
  args_loop:
    if i == arity goto invoke
    unless iter goto elem_undef
    elem = shift iter
    goto push_elem
  elem_undef:
    elem = new 'Failure'
  push_elem:
    push args, elem
    inc i
    goto args_loop

  invoke:
    (mapres :slurpy) = expression(args :flat)
    unless mapres goto map_loop
    mapres.'!flatten'()
    $I0 = elements res
    splice res, mapres, $I0, 0
    goto map_loop

  done:
    .return(res)
.end


.sub 'map' :multi('Sub')
    .param pmc expression
    .param pmc values          :slurpy
    .tailcall values.'map'(expression)
.end


=item pairs()

Return a list of Pair(index, value) elements for the invocant.

=cut

.sub 'pairs' :method :multi(ResizablePMCArray)
    .local pmc result, iter
    .local int i

    result = new 'List'
    iter = self.'iterator'()
    i = 0
  iter_loop:
    unless iter goto iter_end
    $P0 = shift iter
    $P1 = 'infix:=>'(i, $P0)
    push result, $P1
    inc i
    goto iter_loop
  iter_end:
    .return (result)
.end

.sub 'pairs' :multi()
    .param pmc values          :slurpy
    .tailcall values.'pairs'()
.end


=item reduce(...)

=cut

.sub 'reduce' :method :multi('ResizablePMCArray', 'Sub')
    .param pmc expression
    .local pmc retv
    .local pmc iter
    .local pmc elem
    .local pmc args
    .local int i, arity

    arity = expression.'arity'()
    if arity < 2 goto error

    iter = self.'iterator'()
    unless iter goto empty
    retv = shift iter
  loop:
    unless iter goto done

    # Create arguments for closure
    args = new 'ResizablePMCArray'
    # Start with 1. First argument is result of previous call
    i = 1

  args_loop:
    if i == arity goto invoke
    unless iter goto elem_undef
    elem = shift iter
    goto push_elem
  elem_undef:
    elem = new 'Failure'

  push_elem:
    push args, elem
    inc i
    goto args_loop

  invoke:
    retv = expression(retv, args :flat)
    goto loop

  empty:
    retv = new 'Undef'
    goto done

  error:
    'die'('Cannot reduce() using a unary or nullary function.')
    goto done

  done:
    .return(retv)
.end

.sub 'reduce' :multi('Sub')
    .param pmc expression
    .param pmc values          :slurpy
    .tailcall values.'reduce'(expression)
.end


=item uniq(...)

=cut

# TODO Rewrite it. It's too naive.

.namespace ['List']
.sub 'uniq' :method
    .param pmc comparer :optional
    .param int has_comparer :opt_flag

    if has_comparer goto have_comparer
    comparer = get_hll_global 'infix:eq'
  have_comparer:

    .local pmc ulist
    $P0 = get_hll_global 'List'
    ulist = $P0.'new'()

    .local int lelems, uelems, l, u
    lelems = self.'elems'()
    uelems = 0
    l = 0
  outer_loop:
    unless l < lelems goto outer_done
    .local pmc val
    val = self[l]
    u = 0
  inner_loop:
    unless u < uelems goto inner_done
    $P0 = ulist[u]
    $P0 = comparer(val, $P0)
    if $P0 goto outer_next
    inc u
    goto inner_loop
  inner_done:
    ulist.'push'(val)
    inc uelems
  outer_next:
    inc l
    goto outer_loop
  outer_done:
    .return (ulist)
.end


.namespace []
.sub 'uniq' :multi(Sub)
    .param pmc comparer
    .param pmc values :slurpy
    .tailcall values.'uniq'(comparer)
.end

.sub 'uniq' :multi()
    .param pmc values :slurpy
    .tailcall values.'uniq'()
.end


.namespace ['List']

=item values()

Returns a List containing the values of the invocant.

=cut

.sub 'values' :method :multi('ResizablePMCArray')
    self.'!flatten'()
    .return (self)
.end

.sub 'values' :multi()
    .param pmc values          :slurpy
    .tailcall values.'!flatten'()
.end


=back

=head1 Functions

=over 4

=item C<infix:,(...)>

Operator form for building a list from its arguments.

=cut

.namespace []
.sub 'infix:,'
    .param pmc args            :slurpy
    .tailcall args.'list'()
.end


=item C<infix:Z(...)>

The zip operator.

=cut

.sub 'infix:Z'
    .param pmc arglist :slurpy
    .local pmc result

    # create a list to hold the results
    result = new 'List'

    unless arglist goto result_done

    # create a set of iterators, one per argument
    .local pmc iterlist, arglist_it
    iterlist = new 'ResizablePMCArray'
    arglist_it = iter arglist
  arglist_loop:
    unless arglist_it goto arglist_done
    .local pmc arg, arg_it
    arg = shift arglist_it
    arg_it = iter arg
    push iterlist, arg_it
    goto arglist_loop
  arglist_done:

    # repeatedly loop through the argument iterators in parallel,
    # building result elements as we go.  When we reach
    # an argument iterator with no more elements, we're done.

  outer_loop:
    .local pmc iterlist_it, reselem
    iterlist_it = iter iterlist
    reselem = new 'List'
  iterlist_loop:
    unless iterlist_it goto iterlist_done
    arg_it = shift iterlist_it
    unless arg_it goto result_done
    $P0 = shift arg_it
    reselem.'push'($P0)
    goto iterlist_loop
  iterlist_done:
    result.'push'(reselem)
    goto outer_loop

  result_done:
    .return (result)
.end


=item C<infix:X(...)>

The non-hyper cross operator.

=cut

.sub 'infix:X'
    .param pmc args            :slurpy
    .local pmc res
    res = new 'List'

    # Algorithm: we'll maintain a list of counters for each list, incrementing
    # the counter for the right-most list and, when it we reach its final
    # element, roll over the counter to the next list to the left as we go.
    .local pmc counters
    .local pmc list_elements
    .local int num_args
    counters = new 'FixedIntegerArray'
    list_elements = new 'FixedIntegerArray'
    num_args = elements args
    counters = num_args
    list_elements = num_args

    # Get element count for each list.
    .local int i
    .local pmc cur_list
    i = 0
elem_get_loop:
    if i >= num_args goto elem_get_loop_end
    cur_list = args[i]
    $I0 = elements cur_list
    list_elements[i] = $I0
    inc i
    goto elem_get_loop
elem_get_loop_end:

    # Now we'll start to produce them.
    .local int res_count
    res_count = 0
produce_next:

    # Start out by building list at current counters.
    .local pmc new_list
    new_list = new 'List'
    i = 0
cur_perm_loop:
    if i >= num_args goto cur_perm_loop_end
    $I0 = counters[i]
    $P0 = args[i]
    $P1 = $P0[$I0]
    new_list[i] = $P1
    inc i
    goto cur_perm_loop
cur_perm_loop_end:
    res[res_count] = new_list
    inc res_count

    # Now increment counters.
    i = num_args - 1
inc_counter_loop:
    $I0 = counters[i]
    $I1 = list_elements[i]
    inc $I0
    counters[i] = $I0

    # In simple case, we just increment this and we're done.
    if $I0 < $I1 goto inc_counter_loop_end

    # Otherwise we have to carry.
    counters[i] = 0

    # If we're on the first element, all done.
    if i == 0 goto all_done

    # Otherwise, loop.
    dec i
    goto inc_counter_loop
inc_counter_loop_end:
    goto produce_next

all_done:
    .return(res)
.end


=item C<infix:min(...)>

The min operator.

=cut

.sub 'infix:min'
    .param pmc args :slurpy

    # If we have no arguments, undefined.
    .local int elems
    elems = elements args
    if elems > 0 goto have_args
    $P0 = new 'Undef'
    .return($P0)
have_args:

    # Find minimum.
    .local pmc cur_min
    .local int i
    cur_min = args[0]
    i = 1
find_min_loop:
    if i >= elems goto find_min_loop_end
    $P0 = args[i]
    $I0 = 'infix:cmp'($P0, cur_min)
    if $I0 != -1 goto not_min
    set cur_min, $P0
not_min:
    inc i
    goto find_min_loop
find_min_loop_end:

    .return(cur_min)
.end


=item C<infix:max(...)>

The max operator.

=cut

.sub 'infix:max'
    .param pmc args :slurpy

    # If we have no arguments, undefined.
    .local int elems
    elems = elements args
    if elems > 0 goto have_args
    $P0 = new 'Undef'
    .return($P0)
have_args:

    # Find maximum.
    .local pmc cur_max
    .local int i
    cur_max = args[0]
    i = 1
find_max_loop:
    if i >= elems goto find_max_loop_end
    $P0 = args[i]
    $I0 = 'infix:cmp'($P0, cur_max)
    if $I0 != 1 goto not_max
    set cur_max, $P0
not_max:
    inc i
    goto find_max_loop
find_max_loop_end:

    .return(cur_max)
.end

## TODO: zip

=back

=cut

# Local Variables:
#   mode: pir
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4 ft=pir:
