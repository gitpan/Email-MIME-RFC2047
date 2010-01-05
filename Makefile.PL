
use strict;
use warnings;

 BEGIN { require 5.008; } 

use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME  => 'Email-MIME-RFC2047',
  NAME      => 'Email::MIME::RFC2047',
  AUTHOR    => "Nick\ Wellnhofer\ \<wellnhofer\@aevum\.de\>",
  ABSTRACT  => "Correct\ handling\ of\ non\-ASCII\ MIME\ headers",
  VERSION   => '0.90',
  EXE_FILES => [ qw() ],
  (eval { ExtUtils::MakeMaker->VERSION(6.31) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM    => {

  },
  test => {TESTS => 't/*.t'}
);

