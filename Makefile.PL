use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'XML::DifferenceMarkup',
    'VERSION_FROM'	=> 'DifferenceMarkup.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        # 5Sep2002: namespace handling seem to be different between
        # versions, which confuses the tests
        'XML::LibXML'   => '1.52',

        'Algorithm::Diff'   => '0',
    },
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'DifferenceMarkup.pm', # retrieve abstract from module
       AUTHOR     => 'Vaclav Barta <vbar@comp.cz>') : ()),
);
