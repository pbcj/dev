package Exception::FiniteStateMachine;

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
use Exception::Class (

    'FiniteStateMachine::Error' => {
        description     => "A general error occured.",
        },
    'FiniteStateMachine::Error::Undefined' => {
        isa             => 'FiniteStateMachine::Error',
        description     => 'Undefined',
        fields          => [ qw{ register state } ],
        },
);

sub FiniteStateMachine::Error::full_message {
    my $self = shift;
## TODO: uncomment when base error is used, or other errors are added
#    my $message = $self->message ? $self->message : $self->description;
    my $message = $self->message;
#    my @fields = map { defined $self->$_ ? ($_ . ': ' . $self->$_) : () } $self->Fields;
    my @fields = map { $_ . ': ' . $self->$_ } $self->Fields;
#    if (@fields) {
        $message .= ' (' . join( q{, }, @fields ) . ')';
#    }
    return $message;
}

=head1 NAME

Package WebGUI::Exception;

=head1 DESCRIPTION

A base class for all exception handling. It creates a few base exception objects.

=head1 SYNOPSIS

 use WebGUI::Exception;

 # throw
 WebGUI::Error->throw(error=>"Something bad happened.");
 WebGUI::Error::ObjectNotFound->throw(error=>"Couldn't instanciate object.", id=>$id);

 # try
 eval { someFunction() };
 eval { my $obj = SomeClass->new($id) };

 # catch
 if (my $e = WebGUI::Error->caught("WebGUI::Error::ObjectNotFound")) {
    my $errorMessage = $e->error;
    my $objectId = $e->id;
    # do something
 }

B<NOTE>: Though the package name is WebGUI::Exception, the handler objects that are created are WebGUI::Error.

=head1 EXCEPTION TYPES

These exception classes are defined in this class:


=head2 WebGUI::Error

A basic do nothing exception. ISA Exception::Class.

=head3 error

The error message

 WebGUI::Error->throw(error => "Something bad happened");

 $message = $e->error;

=head3 file

A read only exception method that returns the file name of the file where the exception was thrown.

 $filename = $e->file;

=head3 line

A read only exception method that returns the line number where the exception was thrown.

 $lineNumber = $e->line;

=head3 package

A read only exception method that returns the package name where the exception was thrown.

=head2 WebGUI::Error::InvalidObject

Used when looking to make sure objects are passed in that you expect. ISA WebGUI::Error::InvalidParam.

=head3 expected

The type of object expected ("HASH", "ARRAY", "WebGUI::User", etc).

=head3 got

The object type we got.

=cut


1;

