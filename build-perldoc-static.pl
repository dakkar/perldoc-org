#! /usr/bin/perl

use strict;
use warnings;
use File::Basename;
use File::Find;
use File::Spec::Functions qw/catfile/;
use FindBin qw/$Bin/;
use Getopt::Long;
use Shell qw/cp/;
use Template;
use Text::Template qw/fill_in_string/;

use lib "$Bin/lib";
use Perldoc::Config;


#--Set options for Template::Toolkit---------------------------------------

use constant TT_INCLUDE_PATH => "$Bin/templates";


#--Set config options-----------------------------------------------------

my %specifiers = ( 'output-path' => '=s' );                  
my %options;
GetOptions( \%options, optionspec(%specifiers) );


#--Check mandatory options have been given--------------------------------

my @mandatory_options = qw/ output-path /;

foreach (@mandatory_options) {
  (my $option = $_) =~ tr/-/_/;
  unless ($options{$option}) {
    die "Option '$_' must be specified!\n";
  }
}


#--Check the output path exists-------------------------------------------

unless (-d $options{output_path}) {
  die "Output path '$options{output_path}' does not exist!\n";
}

$Perldoc::Config::option{output_path}  = $options{output_path};


#--Set update timestamp---------------------------------------------------

my $date         = sprintf("%02d",(localtime(time))[3]);
my $month        = qw/ January
                       February
                       March
                       April
                       May
                       June
                       July
                       August
                       September
                       October
                       November
                       December /[(localtime(time))[4]];
my $year         = (localtime(time))[5] + 1900;

$Perldoc::Config::option{last_update} = "$date $month $year";


#--Copy static files------------------------------------------------------

cp('-r', "$Bin/static/*",     $Perldoc::Config::option{output_path});
cp('-r', "$Bin/javascript/*", $Perldoc::Config::option{output_path});


#--Process static html files with template--------------------------------

#my $templatefile = "$Bin/templates/html.template";

my $process = create_template_function(
  #templatefile => $templatefile,
  variables    => { %Perldoc::Config::option },
);

#die("Cannot chdir to static-html directory: $!\n") unless (chdir "$Bin/static-html");
find( {wanted=>$process, no_chdir=>1}, "$Bin/static-html" );

#-------------------------------------------------------------------------

sub create_template_function {
  my %args = @_;
  return sub {
    return unless (/(\w+)\.html$/);
    my $page = $1;
    local $/ = undef;
    #if (open FILE,'<',$_) {
      #my $content  = (<FILE>);
      #my $template = Text::Template->new(source => $args{templatefile});
      my $template = Template->new(INCLUDE_PATH => TT_INCLUDE_PATH,
                                   ABSOLUTE     => 1);
      my $depth    = () = m/\//g;
      
      my %titles = (
        index  => "Perl version $Perldoc::Config::option{perl_version} documentation",
        search => 'Search results',
      );
      
      my %breadcrumbs = (
        index  => 'Home',
        search => '<a href="index.html">Home</a> &gt; Search results',
      );
      
      my %variables;
      $variables{path}       = '../' x ($depth - 1);
      $variables{pagename}   = $titles{$page} || $page;
      $variables{breadcrumb} = $breadcrumbs{$page} || $page;
      $variables{content_tt} = $File::Find::name;
      #$variables{content}  = fill_in_string($content,hash => {%Perldoc::Config::option, %variables});
      
      #my $html = $template->fill_in(hash => {%Perldoc::Config::option, %variables});
      
      my $output_filename = catfile($Perldoc::Config::option{output_path},$_);
      #if (open OUT,'>',$output_filename) {
      #  print OUT $html;
      #}
      $template->process('default.tt',{%Perldoc::Config::option, %variables},$output_filename) || die "Failed processing $page\n".$template->error;
    #}   
  }
}

sub optionspec {
  my %option_specs = @_;
  my @getopt_list;
  while (my ($option_name,$spec) = each %option_specs) {
    (my $variable_name = $option_name) =~ tr/-/_/;
    (my $nospace_name  = $option_name) =~ s/-//g;
    my $getopt_name = ($variable_name ne $option_name) ? "$variable_name|$option_name|$nospace_name" : $option_name;
    push @getopt_list,"$getopt_name$spec";
  }
  return @getopt_list;
}
