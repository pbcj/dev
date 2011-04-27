#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2009 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------
# Test WebGUI::FiniteStateMachine

use strict;
use warnings;
use lib '../lib';
#use lib '/data/WebGUI/t/lib';
#use WebGUI::Test;
#use Test::Most 'defer_plan';
use Test::More;
use Test::Deep;

use FiniteStateMachine;

#----------------------------------------------------------------------------
# Init
my $session = { session => undef }; #WebGUI::Test->session;
my $class = 'FiniteStateMachine';
#my @entries;

#----------------------------------------------------------------------------
# Tests
#plan tests => 15;
plan 'no_plan';

#$class->DISABLE_MAIL_QUEUE;
use_ok( 'FiniteStateMachine', 'Use ok' );

{
    local $\ = "\n";

    my @triggers;
    my $trigger = sub {
        #print $_[1];
        shift; push @triggers, shift;
    };
    
    my $states = {
        'door_state' => [ 'opened', 'closed', 'ajar' ],
    };
    
    my $registers = {
        'door' => 'door_state',
        'window' => 'door_state',
    };
        
    my $transitions = {
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
    
    my $fsm = FiniteStateMachine->new( $session, $states, $registers, $transitions );
    
    my $_all_ajar = { door => 'ajar', window => 'ajar' };
    my $_door_ajar = { door => 'ajar' };
    my $_door_close = { door => 'closed' };
    my $_door_open = { door => 'opened' };
    my $_window_close = { window => 'closed' };
    my $_all_close = { door => 'closed', window => 'closed' };
    #my $_window_open = { window => 'opened' };
    
    ############
    # Go
    ############
    {
        $fsm->set( $_door_ajar );
    
        is( pop @triggers, 'door initialized', 'empty => not empty triggered' );
        is( scalar @triggers, 0, 'no other triggers' );
    
        $fsm->set( $_all_ajar );
        is( scalar @triggers, 0, 'triggerless set' );
        
        $fsm->set( $_door_close );
        
        is( pop @triggers, 'door closed', 'trigger from door closed 1/3' );
        is( scalar @triggers, 0, 'no other triggers' );
        
        $fsm->set( $_door_open );

        is( pop @triggers, 'door opened', 'trigger from door opened' );
        is( pop @triggers, 'door closed to opened', 'trigger from door closed to opened' );
        is( scalar @triggers, 0, 'no other triggers' );

        $fsm->set( $_door_close );
        
        is( pop @triggers, 'door closed', 'trigger from door closed 2/3' );
        is( pop @triggers, 'door opened to closed', 'trigger from door opened to closed' );
        is( scalar @triggers, 0, 'no other triggers' );
        
        $fsm->set( $_window_close );
        is( scalar @triggers, 0, 'no triggers from window closed (separation test)' );

        $fsm->set( $_all_close );
        is( scalar @triggers, 0, 'no triggers from window closed (duplication test)' );
        
        $fsm->set( $_all_ajar );
        $fsm->set( $_all_close );
        is( pop @triggers, 'door closed', 'trigger from door closed 3/3' );
        is( pop @triggers, 'all closed', 'trigger from all closed' );
        is( scalar @triggers, 0, 'no other triggers 1/3' );
        
        $fsm->push( $_all_ajar );
        is( scalar @triggers, 0, 'no other triggers 2/3' );
        
        $fsm->push( $_all_close, 1 );
        is( scalar @triggers, 0, 'no other triggers 3/3' );
        
        $fsm->push( $_all_ajar, 1 );
        $fsm->pop( 1 );
        is( scalar @triggers, 0, 'no other triggers from pop 1/3' );
        
        $fsm->push( $_all_ajar, 1 );
        $fsm->pop();
        
        is( pop @triggers, 'door closed', 'trigger from pop: door closed' );
        is( pop @triggers, 'all closed', 'trigger from pop: all closed' );
        is( scalar @triggers, 0, 'no other triggers from pop 2/3' );
        
        
        $fsm->pop();
        $fsm->pop();
        is( pop @triggers, 'door closed', 'trigger from repop: door closed' );
        is( pop @triggers, 'all closed', 'trigger from repop: all closed' );
        is( scalar @triggers, 0, 'no other triggers from pop 3/3' );
        
        #pop through test => adoc { closed }
        my @result = keys %{ $fsm->evaluate( {
            door => {
                is => {
                    'closed' => [ 'adhoc door is so closed' ],
                },
            }
        } ) };
        
        is( pop @result, 'adhoc door is so closed', 'ahdoc trigger' );
        is( scalar @result, 0, 'no other results from adhoc' );
        is( scalar @triggers, 0, 'no triggers from adhoc' );
                       
        # invalid reg / val tests
        #dthrows( $fsm->set( 'bad_register' ), 's' );
        
        # Rebuild test
        $fsm->build( {
            adhoc2 => {
                from => {
                    '!door' => 'closed'
                },
                to => {
                    door => 'closed'
                },
                trigger => $trigger
            }
        } );
        $fsm->set( { door => 'opened' } );
        $fsm->set( { door => 'closed' } );
        
        is( pop @triggers, 'adhoc2', 'trigger after rebuild' );
        is( scalar @triggers, 0, 'no other triggers' );
    }
}

#all_done;

