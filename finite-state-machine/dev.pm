package FiniteStateMachine;

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

use lib 'lib';
use FiniteStateMachine;
use Exception::FiniteStateMachine;

sub dev {
    local $\ = "\n";
    
    #my @triggers;
    my $trigger = sub {
        my $this = shift;
        my $transition = shift;
        print "Triggered: $transition";
        #print "Reopen...";
        #$this->set( { door => 'opened' } );
        #print "...done";
        #CORE::push @triggers, shift;
    };
    
    my $fsm = FiniteStateMachine->new( );  # { this => "session" }
    
    $fsm->{ _states } = {
        'door_state' => [ 'opened', 'closed', 'ajar' ],
    };
    
    $fsm->{ _registers } = {
        'door' => 'door_state',
        'window' => 'door_state',
    };
        
    $fsm->{ _transitions } = {
        'door initialized' => {
            from => {  'door' => '' },
            to =>   { '!door' => '' },
            trigger => $trigger,
        },
        'door opened' => {
            from => { '!door' => [ 'opened', 'ajar' ] },
            to =>   {  'door' => 'opened'},
            trigger => $trigger,
        },
        'door closed' => {
            from => { '!door' => 'closed' },
            to =>   {  'door' => 'closed' },
            trigger => $trigger,
        },
        'door closed to opened' => {
            from => { 'door' => 'closed' },
            to =>   { 'door' => 'opened'},
            trigger => $trigger,
        },
        'door opened to closed' => {
            from => { 'door' => 'opened' },
            to =>   { 'door' => 'closed'},
            trigger => $trigger,
        },
        'all closed' => {
            # TODO: Test this for no from state => does this re-fire on other state change?
            from => { '!door' => 'closed', '!window' => 'closed' },
            to =>   { 'door' => 'closed', 'window' => 'closed' },
            trigger => $trigger,
        },
        
    };

    $fsm->build();
    
    ##print Dumper( $fsm->{ _fromState }->{ '!' } );
    ##print Dumper( $fsm->{ _matches } );
    
    $fsm->set( { door => 'closed' } );
    
    print 'Door is ' . $fsm->state( 'door' );
    
    print '-' x 100;
    
    $fsm->evaluate( $fsm->{ _fromState } );
    #print Dumper( $fsm->{ _fromState }->{ '!' } );
    #print Dumper( $fsm->{ _matches } );
    
    #print Dumper( $toStates );
    
    $fsm->set( { door => 'opened' } );
    
    print 'Door is ' . $fsm->state( 'door' );
    
    print '-' x 100;
    
    $fsm->set( { window => 'closed' } );
    
    print 'Window is ' . $fsm->state( 'window' );
    
    print '-' x 100;
    
    $fsm->set( { door => 'closed' } );
    
    print 'Door is ' . $fsm->state( 'door' );
    
    print '-' x 100;
    print 'opening things...';
    $fsm->set( { door => 'ajar', window => 'opened' } );
    print '...further...';
    $fsm->set( { door => 'opened' } );
    
    print '...slaming things...';
    $fsm->set( { door => 'closed', window => 'closed' } );
    print '...all closed';
    
    #print Dumper( $fsm->{ _fromState } );
    my $activeTransitions = $fsm->evaluate( {
        door => {
            is => {
                'closed' => [ 'adhoc door is so closed' ],
            },
        },
        window => {
            isnt => {
                'open' => [ 'window is not open', 'but not surely closed' ],
            }
        }
    } );
    print '[', ( join q/ | / => keys %{ $activeTransitions } ), ']';
    
    #print join q/ -- / => @$fsm;
    eval { $fsm->set( { 'bad_register', 1 } ) };
    print 'why: ' . $@;
};

dev;

1;