package FiniteStateMachine;
our $VERSION = "0.01";
=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2009 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use warnings;
use 5.008008;

use Scalar::Util qw( weaken );
use List::Util qw( reduce );
use List::MoreUtils qw( any );
use Data::Dumper;

use lib '/data/WebGUI/lib';

use Exception::FiniteStateMachine;

=head1 NAME

Package WebGUI::FiniteStateMachine

=head1 DESCRIPTION

This package provides a Finite State Machine with stack functionality.

=head1 SYNOPSIS

 [code snips here]
 use WebGUI::FiniteStateMachine;
 $fsm = WebGUI::FiniteStateMachine->new($session,3);
 
=head1 VARIABLES

    state                           the instance of register and the current finite state
        { door => 'open' }


    states                          finite states available for a given register type
        { door_state = [ 'open', 'closed', 'ajar' ] }

    registers                       keys define valid states, values define register type
        { door => 'door_state' }

    registerType                    a string representing a an entry from states
        'door_state'

    transitions                     (from/to) transition definition
        { 'door opened' => {
            from => { !door => [ 'open', 'ajar' ] },    # list allowed, treated as OR during transition
            to =>   { door => 'open'},
            },
          ...
        }

=head1 STRUCTURES
    
    transitionRegister              the structure of fromState and toState (fromState shown)
        { "door" =>
            # snipped "fromState"
            'isnt' => {
                { 'open' => [ 'door opened', ... ],
                  'ajar' => [ 'door opened', ... ],
              	  ...
                },
            },
            # snipped "toState"
            'is' => {
            	{ 'open' => [ 'door opened', ... ],
             	...
                },
            },
           ...
        )


=head1 METHOD PROTOTYPES

These methods are available from this class:

    new     ( session, states, registers, [transitions] )
    build   ( transitions )
    pop     ( [doNotInvokeTransition] )
    push    ( state, [doNotInvokeTransition] )
    set     ( state )
    state   ( [register ] )

=head1 DEVELOPER NOTES

This is a finite state machine which provides a mechanism to invoke code when the
state machine transitions between states. Also, this class implements the memento
pattern so that states may be pushed and popped.

The current state is defined as a collection of registers, for which each register
may hold one predefined value.  The predefined values are the available states,
and should be thought of as a register type.

State transitions are defined as two parts, the FROM state, and TO state. A single
evaluation is used on the current state in the context of FROM or TO, and this
produces a list of corresponding matched transition states.  A transition is
detected when a transition state is active during both the FROM and TO, and the
corresponding trigger is fired.  The order which the matched transition triggers
are fired is unspecified, so if an order is desired, the transition definition hash
should be tied accordingly prior to instantiating this class.

State transition evaluation works by matching IS and ISNT conditions from the
transition definition against the state's previous value (matched or unmatched).
When a state transition (matched or unmatched) changes, the state transition
counter is incremented or decremented.  When the state transition counter is equal
to the number of state tests defined, that transition's trigger is fired. It is
worth while to note that the matched/unmatched logic treats ISNT blocks as AND
conditions, and IS blocks as OR conditions.  Meaning an ISNT has to match all
registers in order to become matched, but an IS block only need match one state
to consider that register matched.

A single bang "!" is a reserved key, and cannot be used as a transition or register
name.  It may, however, be included within a state definition.

=cut

####################################################################

=head1 CONSTRUCTOR
=cut
#-------------------------------------------------------------------

=head2 new ( session, states, registers, [transitions] )

Returns a new state machine.

=head3 states

A hash reference defining the available states for a given register.

=head3 registers

A hash reference defining the available registers to track.

=head3 transitions

A nested hash reference defining the transition logic and functionality.

=cut
sub new {
    my ( $class, $session, $states, $registers, $transitions ) = @_;
    
    # Declare instance object
    my $instance = bless {
        _session => $session,
        _states => $states || {},
        _registers => $registers || {},
        _transitions => $transitions || {},
        _state => {},
        _stack => [],  # Not Impl
        _fromState => {},
        _toState => {},
        _fromTransitions => {},
        _toTransitions => {},
    }, $class;
    
    # Don't hold onto the session.
    weaken $instance->{ _session };
    
    # If transitions were passed, set them up
    $instance->build if $transitions;
    
    # Return new instance
    return $instance;
}

####################################################################

=head1 PUBLIC METHODS
=cut
#-------------------------------------------------------------------

=head2 build ( transitions )

Generates the underlying structures needed to provide state transition
triggering.

=head3 transitions

A hash reference containing the transitions definition.

=cut
sub build {
    my ( $this, $transitions ) = @_;
    
    # Store transition table if passed
    $this->{ _transitions } = $transitions unless !$transitions;
    
    # Shortcuts
    my $fromStates = $this->{ _fromState } = {};
    my $toStates = $this->{ _toState } = {};
    
    # Reset
    $this->{ _stack } = [];
    $this->{ _state } = {};
    $this->{ _fromTransitions } = {};
    $this->{ _toTransitions } = {};
    
    # For each transition
    while( my ( $name, $transition ) = each( %{ $this->{ _transitions } } ) ) {
        
        # Process transitions into each transition table
        do {
            $this->_translate( @{ $_ } );
        } for (
            [ $name, $transition->{ 'from' }, $fromStates ],
            [ $name, $transition->{ 'to' }, $toStates   ]
        );
        
    }
    
    #print Dumper( $fromStates );
    #print Dumper( $toStates );
    #print Dumper( $this->{ _counts } );
    
}

#-------------------------------------------------------------------

=head2 evaluate ( transitionRegisters )

=head3 transitionRegisters

....

=cut
sub evaluate {
    my ( $this, $transitionRegisters ) = @_;
    
    # Get counter slot
    my $counters = $transitionRegisters->{ '!' };
    
    # Evaluate each transition register key 
    for my $registerKey ( keys %{ $this->{ _registers } } ) {
        my $transitionRegister = $transitionRegisters->{ $registerKey };
        #my $register = $this->{ _registers }->{ $registerKey };
        
        # For the two slots per register, "is" and "isnt"
        for ( 'is', 'isnt' ) {
            
            # Lexicalize slot
            my $slot = $transitionRegister->{ $_ };
            
            # If slot doesn't exist, move on 
            next unless $slot;
            
            # Evaluate the logic
            $counters = $this->_evaluateLogic( $counters, $registerKey, $_, $slot );
        }
    }
    
    # Use counters to determine current matches
    my $matches = { };
    for my $transitionKey ( keys %{ $counters } ) {
        
        # Shortcuts for readability
        my $stateExpression = $counters->{ $transitionKey };
        my $matchCount = $stateExpression->{ '!' } + 1;
        my $neededCount = scalar keys %{ $stateExpression };
        
        # If we have an active transition, add it to the matches array
        $matches->{ $transitionKey } = 1 if $matchCount == $neededCount;
    }
    
    # Return reference to results
    return $matches;
}

#-------------------------------------------------------------------

=head2 push ( state, [doNotInvokeTransition] )

Pushes a new state onto the stack, optionally (by default) invoking transitions.

Returns the pushed state.

=head3 state

A hash reference containing the changed states. { register => state, ... }

=cut
sub push {
    my ( $this, $state, $doNotInvokeTransition ) = @_;
    
    # Preserve current state 
    CORE::push @{ $this->{ _stack } }, $this->state;
    
    # Set state and optionally invoke transitions
    $this->_transition( $state, $doNotInvokeTransition );
    
    # Return current (complete) state
    return $this->state;
}

#-------------------------------------------------------------------

=head2 pop ( [doNotInvokeTransition] )

Returns a the popped state, optionally (by default) invoking transitions.

=cut
sub pop {
    my ( $this, $doNotInvokeTransition ) = @_;
    
    # Revert to a previous state, optionally triggering a state transition
    my $state = CORE::pop @{ $this->{ _stack } };
    
    # Set state and optionally invoke transitions
    $this->_transition( $state, $doNotInvokeTransition );
    
    # Return current (complete) state
    return $this->state;
}

#-------------------------------------------------------------------

=head2 set ( state )

Changes the current state, optionally (by default) invoking transitions.

Returns the new state.

Throws FiniteStateMachine::Error::Undefined( register ) if the register is undefined.
Throws FiniteStateMachine::Error::Undefined( register, state ) if the value being placed in the register is undefined.

=head3 state

A hash reference containing the changed states. { register => state, ... }

=cut
sub set {
    my ( $this, $state, $doNotInvokeTransition ) = @_;
    
    # Transition if this state is valid
    $this->_validateStates( $state )->_transition( $state, $doNotInvokeTransition );
    
    # Otherwise denote failure (won't be called, using exceptions)
    return undef;
}

#-------------------------------------------------------------------

=head2 state ( [register] )

Returns the current state object, or the state of a register if specified.


=head3 register

The name of the register from which the state should be returned.

=cut
sub state {
    my ( $this, $register ) = @_;
    
    # Return a copy of the state object if no register was specified
    if( !$register ) {
        my %stateCopy = %{ $this->{ _state } } ;
        return \%stateCopy;
    }
    
    # Return state register
    return $this->{ _state }->{ $register };
}

####################################################################

=head1 PRIVATE METHODS
=cut
#-------------------------------------------------------------------

=head2 _evaluateLogic ( state )

Evaluates a group of transitions for a particular register key.

=head3 state

A hash reference containing the changed states. { register => state }

=cut
{   my $eq = sub { ( shift eq shift ) ? 1 : 0 };
    my $ne = sub { ( shift ne shift ) ? 1 : 0 };
    
sub _evaluateLogic {
    my ( $this, $counters, $registerKey, $operation, $transitions ) = @_;
    
    # Lexicalize state;
    my $state = $this->{ _state }->{ $registerKey } || '';
    
    # Gather matches for current context
    my $delegate = $operation eq 'is' ? $eq : $ne;
    
    # Magic. Sets a state tracking entry in the form of { 'transition name' => { 'register is|isnt state' => 1 || 0  } }
    for my $finiteState ( keys %{ $transitions } ) {
        for my $entry ( @{ $transitions->{ $finiteState } } ) {
            
            # Shortcuts for readability
            my $stateKey = "$registerKey $operation $finiteState";
            my $oldMatch = $counters->{ $entry }->{ $stateKey } || 0;
            my $newMatch = $delegate->( $state, $finiteState );
            
            # When the match state (for this transition) has changed
            if( $oldMatch != $newMatch ) {
                
                # Store the new match status ( matched or unmatched )
                $counters->{ $entry }->{ $stateKey } = $newMatch;
                
                # Move the current counter accordingly.  When this value is the same as
                # the number of items in this counter entry (minus one for the count itself)
                # it means this transition was matched.
                $counters->{ $entry }->{ '!' } += $newMatch ? 1 : -1;
            }
        }
    }
    
    # Return counters to allow adhoc evaluation
    return $counters;
}}

#-------------------------------------------------------------------

=head2 _transition ( state, [doNotInvokeTransitions] )

Validates and sets state, optionally (by default) invoking transitions.

=head3 state

A hash reference containing the changed states. { register => state }

=cut
sub _transition {
    my ( $this, $state, $doNotInvokeTransitions ) = @_;
    
    # Evaulate from state
    my %active = %{ $this->{ _fromTransitions } = $this->evaluate( $this->{ _fromState } ) };
    
    # Update the state registers
    for my $register ( keys %{ $state } ) {
        $this->{ _state }->{ $register } = $state->{ $register };
    }
    
    # Evaulate to state
    my $to = $this->{ _toTransitions } = $this->evaluate( $this->{ _toState } );
    
    # Invoke Transition Triggers
    unless( $doNotInvokeTransitions ) {
        for my $transition ( keys %{ $to } ) {
            $this->{ _transitions }->{ $transition }->{ trigger }->( $this, $transition ) if $active{$transition}
        }
    }
}

#-------------------------------------------------------------------

=head2 _translate ( $name, $definition, $table )

Translates a transition definition entry into the super structures used
to efficiently detect state changes.

=cut
sub _translate {
    my ( $this, $name, $definition, $table ) = @_;
    
    # Get counter slot
    $table->{ '!' } = {} if not defined $table->{ '!' };
    my $counters = $table->{ '!' };

    # For each key/state in the transition definition
    while( my ( $registerKey, $states ) = each %{ $definition } ) {
        
        # Convert state to array, if needed
        $states = [ $states ] if ref \$states eq 'SCALAR';
        
        # Fix up register key (remove negating syntax)
        my $isNegateRegister = $registerKey =~ m/^!/;
        $registerKey =~ s/^!(.*)/$1/ if $isNegateRegister;
        
        # Get register
        my $registerType = $this->{ _registers }->{ $registerKey };
        
        # Get transition slot
        my $slotName = $isNegateRegister ? 'isnt' : 'is';
        $table->{ $registerKey }->{ $slotName } = {} if !$table->{ $registerKey }->{ $slotName };
        my $slot = $table->{ $registerKey }->{ $slotName };
        
        # For each state
        for my $state ( @{ $states } ) {
            
            # Validate state
            $this->_validateState( $registerType, $state ) if $state;
            
            # Push into slot
            CORE::push @{ $slot->{ $state } }, $name;
            
            # Create a place to keep counts for this state
            $counters->{ $name }->{ "$registerKey $slotName $state" } = 0;
            $counters->{ $name }->{ "!" } = 0;
        }
        
    } keys %{ $definition };
    
}

#-------------------------------------------------------------------

=head2 _validateState ( registerType, $state )

Validates a state as being acceptable for a given register type.

=cut
sub _validateState {
    my ( $this, $registerType, $state ) = @_;

    # Ensure state is valid for this register type
    return any { $_ eq $state } @{ $this->{ _states }->{ $registerType } };
}

#-------------------------------------------------------------------

=head2 _validateStates ( state )

Validates a hash containing register/state pairs (a state object).

This is separate (not bundled with the transition subs) because we do not want to 
adjust the state if we will run into an error... the state would become invalid.

=head3 state

A hash reference containing the changed states. { register => state, ... }

=cut
sub _validateStates {
    my ( $this, $state ) = @_;
    
    # For each register name passed in
    for my $register ( keys %{ $state } ) {
        
        # Get register type
        my $registerType = $this->{ _registers }->{ $register };
        
        # Ensure the key is a valid register
        FiniteStateMachine::Error::Undefined->throw( register => $register ) if !$registerType;
        
        # Get the state to which we are transitioning
        my $finiteState = $state->{ $register };
        
        # Ensure state is valid for this register type
        if( ! $this->_validateState( $registerType, $finiteState ) ) {
            FiniteStateMachine::Error::Undefined->throw( register => $register, state => $finiteState );
        }
    }
    
    # Promote one-liners
    return $this;    
}

1;