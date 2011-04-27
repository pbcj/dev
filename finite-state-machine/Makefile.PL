use ExtUtils::MakeMaker;
use ExtUtils::MakeMaker::Coverage;

    WriteMakefile(
        NAME            => 'FiniteStateMachine',
        VERSION_FROM    => 'lib/FiniteStateMachine.pm'
    );

    testcover();
    
    # if you wish to tweak the testcover target that will be written,
    # alter it's configuration.
    $conf = ExtUtils::MakeMaker::Coverage->config;
