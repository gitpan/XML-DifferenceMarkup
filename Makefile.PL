use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'XML::DifferenceMarkup',
    'VERSION_FROM'	=> 'DifferenceMarkup.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        'XML::LibXML'   => '0', # or a minimum workable version
        'Algorithm::Diff'   => '0', # or a minimum workable version
    },
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'DifferenceMarkup.pm', # retrieve abstract from module
       AUTHOR     => 'A. U. Thor <a.u.thor@a.galaxy.far.far.away>') : ()),
);
