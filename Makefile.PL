use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'XML::DifferenceMarkup',
    'VERSION_FROM'	=> 'DifferenceMarkup.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        'XML::LibXML'   => '1.58',
        'Algorithm::Diff'   => '1.15',
    },
    ($] >= 5.005 ?    ## keyword supported since 5.005
      ( AUTHOR     => 'Vaclav Barta <vbar@comp.cz>') : ()),
);
